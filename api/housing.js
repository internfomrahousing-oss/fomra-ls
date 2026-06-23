const express = require('express');
const cors    = require('cors');
const router  = require('../backend/src/routes/housing');

const app = express();
app.use(cors());
app.use('/api/housing', router);
module.exports = app;
