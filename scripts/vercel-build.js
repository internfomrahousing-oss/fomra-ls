const fs = require('fs');
const path = require('path');

const index = path.join(__dirname, '..', 'build', 'web', 'index.html');
if (!fs.existsSync(index)) {
  console.error(
    'Missing build/web/index.html — run "flutter build web" locally, commit build/web, then redeploy.',
  );
  process.exit(1);
}
console.log('Using committed Flutter web build from build/web');
