const express = require('express');
const cors    = require('cors');
const router  = require('../backend/src/routes/poi');

const app = express();
app.use(cors());
app.use(express.json());
app.use('/api/poi', router);
module.exports = app;
