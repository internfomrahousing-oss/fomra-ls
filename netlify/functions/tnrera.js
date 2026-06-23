const router = require('../../backend/src/routes/tnrera');

const CORS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type',
};

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') return { statusCode: 204, headers: CORS, body: '' };

  // Strip function prefix so Express router sees /projects or /:year/:type
  const subPath = event.path.replace(/^\/.netlify\/functions\/tnrera/, '') || '/';

  return new Promise((resolve) => {
    const req = {
      method:  event.httpMethod || 'GET',
      url:     subPath || '/',
      query:   event.queryStringParameters || {},
      params:  {},
      headers: event.headers || {},
    };
    let statusCode = 200;
    const res = {
      status(c) { statusCode = c; return this; },
      setHeader() { return this; },
      json(data) { resolve({ statusCode, headers: CORS, body: JSON.stringify(data) }); },
    };
    router.handle(req, res, (err) => {
      resolve({
        statusCode: err ? 500 : 404,
        headers: CORS,
        body: JSON.stringify({ error: err ? err.message : 'Not found' }),
      });
    });
  });
};
