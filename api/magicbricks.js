const express = require('express');
const cors    = require('cors');
const router  = require('../backend/src/routes/magicbricks');

const app = express();
app.use(cors());
app.use('/api/magicbricks', router);
module.exports = app;
