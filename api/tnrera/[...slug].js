const { createApiApp } = require('../_expressApp');
const router = require('../../backend/src/routes/tnrera');

module.exports = createApiApp('/api/tnrera', router);
