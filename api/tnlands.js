const { createApiApp } = require('./_expressApp');
const router = require('../backend/src/routes/tnlands');

module.exports = createApiApp('/api/tnlands', router);
