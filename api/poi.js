const { createApiApp } = require('./_expressApp');
const router = require('../backend/src/routes/poi');

module.exports = createApiApp('/api/poi', router, { json: true });
