const serverless = require('serverless-http');
const express    = require('express');
const cors       = require('cors');
const router     = require('../../backend/src/routes/poi');

const app = express();
app.use(cors());
app.use(express.json());
app.use('/.netlify/functions/poi', router);

module.exports.handler = serverless(app);
