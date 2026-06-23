const express = require('express');
const pool = require('../db');
const auth = require('../middleware/auth');

const router = express.Router();
router.use(auth);

// GET /api/tasks
router.get('/', async (req, res) => {
  const { status, priority, lead_id, assigned_to } = req.query;
  const conditions = [];
  const params = [];

  if (status)      { params.push(status);      conditions.push(`t.status = $${params.length}`); }
  if (priority)    { params.push(priority);    conditions.push(`t.priority = $${params.length}`); }
  if (lead_id)     { params.push(lead_id);     conditions.push(`t.lead_id = $${params.length}`); }
  if (assigned_to) { params.push(assigned_to); conditions.push(`t.assigned_to = $${params.length}`); }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  try {
    const { rows } = await pool.query(
      `SELECT t.*,
              u.full_name  AS assigned_to_name,
              c.full_name  AS created_by_name,
              l.name       AS lead_name
       FROM tasks t
       LEFT JOIN users u ON u.id = t.assigned_to
       LEFT JOIN users c ON c.id = t.created_by
       LEFT JOIN leads l ON l.id = t.lead_id
       ${where}
       ORDER BY t.due_date ASC NULLS LAST, t.created_at DESC`,
      params
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/tasks/:id
router.get('/:id', async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT t.*, u.full_name AS assigned_to_name, l.name AS lead_name
       FROM tasks t
       LEFT JOIN users u ON u.id = t.assigned_to
       LEFT JOIN leads l ON l.id = t.lead_id
       WHERE t.id = $1`,
      [req.params.id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Task not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/tasks
router.post('/', async (req, res) => {
  const { title, description, status, priority, due_date, lead_id, assigned_to } = req.body;
  if (!title) return res.status(400).json({ error: 'title is required' });
  try {
    const { rows } = await pool.query(
      `INSERT INTO tasks (title, description, status, priority, due_date, lead_id, assigned_to, created_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
      [title, description, status || 'pending', priority || 'medium',
       due_date || null, lead_id || null, assigned_to || null, req.user.id]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/tasks/:id
router.put('/:id', async (req, res) => {
  const { title, description, status, priority, due_date, lead_id, assigned_to } = req.body;
  try {
    const { rows } = await pool.query(
      `UPDATE tasks SET
         title=$1, description=$2, status=$3, priority=$4,
         due_date=$5, lead_id=$6, assigned_to=$7
       WHERE id=$8 RETURNING *`,
      [title, description, status, priority, due_date || null,
       lead_id || null, assigned_to || null, req.params.id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Task not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/tasks/:id
router.delete('/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM tasks WHERE id = $1', [req.params.id]);
    res.json({ message: 'Task deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
