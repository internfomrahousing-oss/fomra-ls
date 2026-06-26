const { createApiApp } = require('./_expressApp');
const router = require('../backend/src/routes/competitors');

module.exports = createApiApp('/api/competitors', router);
