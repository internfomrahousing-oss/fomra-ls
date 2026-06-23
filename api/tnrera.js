const express = require('express');
const cors    = require('cors');
const router  = require('../backend/src/routes/tnrera');

const app = express();
app.use(cors());
app.use('/api/tnrera', router);
module.exports = app;
