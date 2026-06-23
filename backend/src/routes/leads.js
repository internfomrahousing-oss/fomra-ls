const express = require('express');
const pool = require('../db');
const auth = require('../middleware/auth');

const router = express.Router();
router.use(auth);

// GET /api/leads — list (with optional status/source filter)
router.get('/', async (req, res) => {
  const { status, source, assigned_to, search } = req.query;
  const conditions = [];
  const params = [];

  if (status)      { params.push(status);      conditions.push(`l.status = $${params.length}`); }
  if (source)      { params.push(source);      conditions.push(`l.source = $${params.length}`); }
  if (assigned_to) { params.push(assigned_to); conditions.push(`l.assigned_to = $${params.length}`); }
  if (search) {
    params.push(`%${search}%`);
    conditions.push(`(l.name ILIKE $${params.length} OR l.phone ILIKE $${params.length} OR l.email ILIKE $${params.length})`);
  }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  try {
    const { rows } = await pool.query(
      `SELECT l.*,
              u.full_name AS assigned_to_name,
              c.full_name AS created_by_name
       FROM leads l
       LEFT JOIN users u ON u.id = l.assigned_to
       LEFT JOIN users c ON c.id = l.created_by
       ${where}
       ORDER BY l.created_at DESC`,
      params
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/leads/:id
router.get('/:id', async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT l.*,
              u.full_name AS assigned_to_name,
              c.full_name AS created_by_name
       FROM leads l
       LEFT JOIN users u ON u.id = l.assigned_to
       LEFT JOIN users c ON c.id = l.created_by
       WHERE l.id = $1`,
      [req.params.id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Lead not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/leads
router.post('/', async (req, res) => {
  const {
    name, phone, email, source, status, property_type,
    budget_min, budget_max, location_preference, notes, assigned_to,
  } = req.body;
  if (!name) return res.status(400).json({ error: 'name is required' });
  try {
    const { rows } = await pool.query(
      `INSERT INTO leads
         (name, phone, email, source, status, property_type,
          budget_min, budget_max, location_preference, notes, assigned_to, created_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
       RETURNING *`,
      [name, phone, email, source, status || 'new', property_type,
       budget_min, budget_max, location_preference, notes, assigned_to, req.user.id]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/leads/:id
router.put('/:id', async (req, res) => {
  const {
    name, phone, email, source, status, property_type,
    budget_min, budget_max, location_preference, notes, assigned_to,
  } = req.body;
  try {
    const { rows } = await pool.query(
      `UPDATE leads SET
         name=$1, phone=$2, email=$3, source=$4, status=$5, property_type=$6,
         budget_min=$7, budget_max=$8, location_preference=$9, notes=$10, assigned_to=$11
       WHERE id=$12 RETURNING *`,
      [name, phone, email, source, status, property_type,
       budget_min, budget_max, location_preference, notes, assigned_to, req.params.id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Lead not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/leads/:id
router.delete('/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM leads WHERE id = $1', [req.params.id]);
    res.json({ message: 'Lead deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
