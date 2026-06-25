const express = require('express');
const cors    = require('cors');
const router  = require('../../backend/src/routes/tnlands');

const app = express();
app.use(cors());
app.use('/api/tnlands', router);
module.exports = app;
