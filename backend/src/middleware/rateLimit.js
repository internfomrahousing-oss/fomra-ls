// Minimal in-memory fixed-window rate limiter (no external dependency).
//
// Intended for the self-hosted single-process Express backend. On serverless
// platforms (where memory isn't shared across invocations) rely on the
// provider / upstream auth (e.g. Supabase Auth) rate limits instead.
//
// Usage: router.post('/login', rateLimit({ windowMs, max }), handler)

function rateLimit({ windowMs = 15 * 60 * 1000, max = 10 } = {}) {
  const hits = new Map(); // key -> { count, resetAt }

  // Opportunistic cleanup so the map doesn't grow unbounded.
  setInterval(() => {
    const now = Date.now();
    for (const [key, v] of hits) {
      if (v.resetAt <= now) hits.delete(key);
    }
  }, windowMs).unref?.();

  return (req, res, next) => {
    const now = Date.now();
    const key =
      (req.headers['x-forwarded-for'] || '').split(',')[0].trim() ||
      req.ip ||
      req.socket?.remoteAddress ||
      'unknown';

    let entry = hits.get(key);
    if (!entry || entry.resetAt <= now) {
      entry = { count: 0, resetAt: now + windowMs };
      hits.set(key, entry);
    }
    entry.count += 1;

    if (entry.count > max) {
      const retryAfter = Math.ceil((entry.resetAt - now) / 1000);
      res.setHeader('Retry-After', String(retryAfter));
      return res
        .status(429)
        .json({ error: 'Too many attempts. Please try again later.' });
    }
    next();
  };
}

module.exports = rateLimit;
