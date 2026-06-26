const express = require('express');
const cors    = require('cors');
const router  = require('../backend/src/routes/competitors');

const app = express();
app.use(cors());
app.use('/api/competitors', router);
module.exports = app;
