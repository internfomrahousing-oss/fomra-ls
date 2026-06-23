require('dotenv').config();
const express = require('express');
const cors    = require('cors');
const path    = require('path');

const authRoutes       = require('./routes/auth');
const leadsRoutes      = require('./routes/leads');
const tasksRoutes      = require('./routes/tasks');
const siteVisitRoutes  = require('./routes/siteVisits');
const tnreraRoutes     = require('./routes/tnrera');
const magicbricksRoutes = require('./routes/magicbricks');
const tnlandsRoutes    = require('./routes/tnlands');
const poiRoutes        = require('./routes/poi');

const app = express();

app.use(cors());
app.use(express.json());

app.get('/health', (_, res) => res.json({ status: 'ok' }));

app.use('/api/auth',        authRoutes);
app.use('/api/leads',       leadsRoutes);
app.use('/api/tasks',       tasksRoutes);
app.use('/api/site-visits', siteVisitRoutes);
app.use('/api/tnrera',      tnreraRoutes);
app.use('/api/magicbricks', magicbricksRoutes);
app.use('/api/tnlands',     tnlandsRoutes);
app.use('/api/poi',         poiRoutes);

// Local dev: serve the compiled Flutter web build from the same server.
// On Vercel, static files are served by the CDN (vercel.json outputDirectory).
if (!process.env.VERCEL) {
  const webRoot = path.join(__dirname, '../../build/web');
  app.use(express.static(webRoot));
  app.get(/^(?!\/api\b)(?!\/health\b).*/, (req, res) => {
    res.sendFile(path.join(webRoot, 'index.html'));
  });
}

// 404 for unmatched /api/* routes
app.use((req, res) => res.status(404).json({ error: 'Route not found' }));

// Error handler
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

if (require.main === module) {
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => console.log(`FomraLS API running on port ${PORT}`));
}

module.exports = app;
