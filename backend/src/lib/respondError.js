// Logs the real error server-side and returns a generic message to the client,
// so internal details (DB schema, driver errors, stack traces) are never leaked.
module.exports = function respondError(res, err, where, status = 500) {
  // eslint-disable-next-line no-console
  console.error(`[${where}]`, err && err.stack ? err.stack : err);
  return res.status(status).json({ error: 'Internal server error' });
};
