const express = require('express');
const cors    = require('cors');
const router  = require('../backend/src/routes/ninetyninacres');

const app = express();
app.use(cors());
app.use('/api/99acres', router);
module.exports = app;
