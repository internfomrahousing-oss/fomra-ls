/**
 * Vercel build step: installs the Flutter SDK (pinned to the revision this
 * project was created with, from .metadata) and compiles the actual web app
 * from source, instead of relying on a manually pre-built `build/web` that
 * someone has to remember to regenerate and commit locally.
 *
 * Vercel's build machines have full internet access (unlike some sandboxed
 * dev environments), so downloading the Flutter SDK/engine here works fine.
 */
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const repoRoot = path.join(__dirname, '..');
const flutterDir = path.join(repoRoot, '.flutter-sdk');
const flutterBin = path.join(flutterDir, 'bin');

// Pinned Flutter revision this project was created with (see .metadata).
// Falls back to the stable channel if .metadata is missing/unreadable so a
// future upgrade of that file doesn't require touching this script too.
function pinnedRevision() {
  try {
    const metadata = fs.readFileSync(path.join(repoRoot, '.metadata'), 'utf8');
    const match = metadata.match(/revision:\s*"([0-9a-f]{7,40})"/);
    return match ? match[1] : null;
  } catch (_) {
    return null;
  }
}

function run(cmd, opts = {}) {
  console.log(`$ ${cmd}`);
  execSync(cmd, { stdio: 'inherit', cwd: repoRoot, ...opts });
}

function installFlutter() {
  if (fs.existsSync(path.join(flutterBin, 'flutter'))) {
    console.log('Using cached Flutter SDK at', flutterDir);
    return;
  }

  console.log('Installing Flutter SDK...');
  const revision = pinnedRevision();
  if (revision) {
    console.log(`Pinning to revision ${revision} (from .metadata)`);
    run(`git clone --filter=blob:none https://github.com/flutter/flutter.git "${flutterDir}"`);
    run(`git checkout ${revision}`, { cwd: flutterDir });
  } else {
    console.log('No pinned revision found — using the stable channel.');
    run(`git clone --filter=blob:none -b stable https://github.com/flutter/flutter.git "${flutterDir}"`);
  }
}

installFlutter();

// Make the freshly-installed Flutter SDK available to every command below.
process.env.PATH = `${flutterBin}${path.delimiter}${process.env.PATH}`;
process.env.CI = 'true';

run('flutter config --no-analytics --enable-web');
run('flutter --version');
run('flutter pub get');
run('flutter build web --release');

const index = path.join(repoRoot, 'build', 'web', 'index.html');
if (!fs.existsSync(index)) {
  console.error('Flutter web build did not produce build/web/index.html — failing the deploy.');
  process.exit(1);
}

const versionInfo = JSON.parse(
  fs.readFileSync(path.join(repoRoot, 'build', 'web', 'version.json'), 'utf8'),
);
console.log(
  `Flutter web build complete — version ${versionInfo.version}, build ${versionInfo.build_number}.`,
);
