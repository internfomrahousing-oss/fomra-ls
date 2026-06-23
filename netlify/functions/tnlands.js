const serverless = require('serverless-http');
const express    = require('express');
const cors       = require('cors');
const router     = require('../../backend/src/routes/tnlands');

const app = express();
app.use(cors());
app.use('/.netlify/functions/tnlands', router);

module.exports.handler = serverless(app);
