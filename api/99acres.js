const { createApiApp } = require('./_expressApp');
const router = require('../backend/src/routes/ninetyninacres');

module.exports = createApiApp('/api/99acres', router);
