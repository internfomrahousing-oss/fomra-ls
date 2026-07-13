/**
 * Vercel build step: installs the Flutter SDK and compiles the actual web
 * app from source, instead of relying on a manually pre-built `build/web`
 * that someone has to remember to regenerate and commit locally.
 *
 * Vercel's build machines have full internet access (unlike some sandboxed
 * dev environments), so downloading the Flutter SDK/engine here works fine.
 *
 * Speed matters here (Vercel build minutes are limited, especially on the
 * Hobby plan), so this does a SHALLOW, single-commit fetch — not a full
 * clone of flutter/flutter's entire multi-year history.
 */
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const repoRoot = path.join(__dirname, '..');
const flutterDir = path.join(repoRoot, '.flutter-sdk');
const flutterBin = path.join(flutterDir, 'bin');

// Pinned Flutter revision this project was created with (see .metadata).
// Used only as a best-effort pin; if the shallow fetch of that exact commit
// fails for any reason we fall back to the stable channel tip so the build
// never gets stuck on this.
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
  execSync(cmd, { stdio: 'inherit', cwd: repoRoot, timeout: 8 * 60 * 1000, ...opts });
}

function tryRun(cmd, opts = {}) {
  try {
    run(cmd, opts);
    return true;
  } catch (err) {
    console.warn(`Command failed, continuing with fallback: ${cmd}`);
    return false;
  }
}

function installFlutter() {
  if (fs.existsSync(path.join(flutterBin, 'flutter'))) {
    console.log('Using cached Flutter SDK at', flutterDir);
    return;
  }

  console.log('Installing Flutter SDK (shallow, single commit)...');
  fs.rmSync(flutterDir, { recursive: true, force: true });
  fs.mkdirSync(flutterDir, { recursive: true });

  const revision = pinnedRevision();
  let ok = false;
  if (revision) {
    console.log(`Trying pinned revision ${revision} (from .metadata)...`);
    ok =
      tryRun('git init -q .', { cwd: flutterDir }) &&
      tryRun('git remote add origin https://github.com/flutter/flutter.git', { cwd: flutterDir }) &&
      tryRun(`git fetch --depth 1 origin ${revision}`, { cwd: flutterDir }) &&
      tryRun('git checkout -q FETCH_HEAD', { cwd: flutterDir });
  }

  if (!ok) {
    console.log('Falling back to a shallow clone of the stable channel tip...');
    fs.rmSync(flutterDir, { recursive: true, force: true });
    run(
      `git clone --depth 1 --no-tags --single-branch -b stable https://github.com/flutter/flutter.git "${flutterDir}"`,
    );
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
