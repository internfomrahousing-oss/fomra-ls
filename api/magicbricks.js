const { createApiApp } = require('./_expressApp');
const router = require('../backend/src/routes/magicbricks');

module.exports = createApiApp('/api/magicbricks', router);
