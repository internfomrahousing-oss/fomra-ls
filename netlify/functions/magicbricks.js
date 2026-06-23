const serverless = require('serverless-http');
const express    = require('express');
const cors       = require('cors');
const router     = require('../../backend/src/routes/magicbricks');

const app = express();
app.use(cors());
app.use('/.netlify/functions/magicbricks', router);

module.exports.handler = serverless(app);
