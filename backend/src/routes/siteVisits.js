const express = require('express');
const pool = require('../db');
const auth = require('../middleware/auth');

const router = express.Router();
router.use(auth);

// GET /api/site-visits
router.get('/', async (req, res) => {
  const { status, lead_id, agent_id } = req.query;
  const conditions = [];
  const params = [];

  if (status)   { params.push(status);   conditions.push(`sv.status = $${params.length}`); }
  if (lead_id)  { params.push(lead_id);  conditions.push(`sv.lead_id = $${params.length}`); }
  if (agent_id) { params.push(agent_id); conditions.push(`sv.agent_id = $${params.length}`); }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  try {
    const { rows } = await pool.query(
      `SELECT sv.*,
              l.name      AS lead_name,
              l.phone     AS lead_phone,
              u.full_name AS agent_name
       FROM site_visits sv
       LEFT JOIN leads l ON l.id = sv.lead_id
       LEFT JOIN users u ON u.id = sv.agent_id
       ${where}
       ORDER BY sv.scheduled_at DESC`,
      params
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/site-visits/:id
router.get('/:id', async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT sv.*, l.name AS lead_name, u.full_name AS agent_name
       FROM site_visits sv
       LEFT JOIN leads l ON l.id = sv.lead_id
       LEFT JOIN users u ON u.id = sv.agent_id
       WHERE sv.id = $1`,
      [req.params.id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Site visit not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/site-visits
router.post('/', async (req, res) => {
  const { lead_id, scheduled_at, address, latitude, longitude, notes, agent_id } = req.body;
  if (!lead_id || !scheduled_at) {
    return res.status(400).json({ error: 'lead_id and scheduled_at are required' });
  }
  try {
    const { rows } = await pool.query(
      `INSERT INTO site_visits (lead_id, scheduled_at, address, latitude, longitude, notes, agent_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [lead_id, scheduled_at, address, latitude || null, longitude || null,
       notes, agent_id || req.user.id]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/site-visits/:id
router.put('/:id', async (req, res) => {
  const { scheduled_at, actual_at, address, latitude, longitude, status, notes, feedback, agent_id } = req.body;
  try {
    const { rows } = await pool.query(
      `UPDATE site_visits SET
         scheduled_at=$1, actual_at=$2, address=$3, latitude=$4, longitude=$5,
         status=$6, notes=$7, feedback=$8, agent_id=$9
       WHERE id=$10 RETURNING *`,
      [scheduled_at, actual_at || null, address, latitude || null, longitude || null,
       status, notes, feedback, agent_id, req.params.id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Site visit not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/site-visits/:id
router.delete('/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM site_visits WHERE id = $1', [req.params.id]);
    res.json({ message: 'Site visit deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
