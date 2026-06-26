const { createApiApp } = require('./_expressApp');
const router = require('../backend/src/routes/housing');

module.exports = createApiApp('/api/housing', router);
