const express = require('express');
const cors = require('cors');

/**
 * Vercel may pass either the full path (/api/foo/bar) or a stripped path (/bar).
 * Mount the router at both the API prefix and / so nested routes resolve.
 */
function createApiApp(mountPath, router, { json = false } = {}) {
  const app = express();
  app.use(cors());
  if (json) app.use(express.json({ limit: '2mb' }));
  app.use(mountPath, router);
  app.use('/', router);
  return app;
}

module.exports = { createApiApp };
