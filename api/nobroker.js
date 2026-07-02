const { createApiApp } = require('./_expressApp');
const router = require('../backend/src/routes/nobroker');

module.exports = createApiApp('/api/nobroker', router);
