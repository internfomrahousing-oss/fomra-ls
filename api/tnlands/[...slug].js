const express = require('express');
const cors    = require('cors');
const router  = require('../../backend/src/routes/tnlands');

const app = express();
app.use(cors());
// Mount at both full and stripped paths — Vercel may or may not strip the
// function's own path segment from req.url before calling the handler.
app.use('/api/tnlands', router);
app.use('/', router);
module.exports = app;
