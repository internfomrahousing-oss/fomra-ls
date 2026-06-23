const serverless = require('serverless-http');
const express    = require('express');
const cors       = require('cors');
const router     = require('../../backend/src/routes/tnrera');

const app = express();
app.use(cors());
app.use('/.netlify/functions/tnrera', router);

module.exports.handler = serverless(app);
