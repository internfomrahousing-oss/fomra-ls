/**
 * Vercel build step: installs the Flutter SDK and compiles the actual web
 * app from source, instead of relying on a manually pre-built `build/web`
 * that someone has to remember to regenerate and commit locally.
 *
 * Vercel's build machines have full internet access (unlike some sandboxed
 * dev environments), so downloading the Flutter SDK/engine here works fine.
 *
 * The SDK must come from the official prebuilt archive so Flutter has valid
 * release metadata during dependency resolution. A bare git clone can report
 * `0.0.0-unknown`, which breaks pub solves for packages that declare a minimum
 * Flutter SDK version.
 */
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const repoRoot = path.join(__dirname, '..');
const flutterDir = path.join(repoRoot, '.flutter-sdk');
const flutterBin = path.join(flutterDir, 'bin');
const flutterArchiveVersion = '3.35.5';
const flutterPlatform = process.platform;
const flutterArch = process.arch;

function flutterArchiveInfo() {
  if (flutterPlatform === 'linux' && flutterArch === 'x64') {
    return {
      url: `https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${flutterArchiveVersion}-stable.tar.xz`,
      extractFolder: 'flutter',
    };
  }

  if (flutterPlatform === 'linux' && flutterArch === 'arm64') {
    return {
      url: `https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_arm64_${flutterArchiveVersion}-stable.tar.xz`,
      extractFolder: 'flutter',
    };
  }

  if (flutterPlatform === 'darwin' && flutterArch === 'arm64') {
    return {
      url: `https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_${flutterArchiveVersion}-stable.zip`,
      extractFolder: 'flutter',
    };
  }

  if (flutterPlatform === 'darwin' && flutterArch === 'x64') {
    return {
      url: `https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_${flutterArchiveVersion}-stable.zip`,
      extractFolder: 'flutter',
    };
  }

  throw new Error(`Unsupported Flutter build host: ${flutterPlatform}/${flutterArch}`);
}

function run(cmd, opts = {}) {
  console.log(`$ ${cmd}`);
  execSync(cmd, { stdio: 'inherit', cwd: repoRoot, timeout: 8 * 60 * 1000, ...opts });
}

function extractArchive(archivePath, extractDir, archiveUrl) {
  if (archiveUrl.endsWith('.zip')) {
    run(`unzip -q "${archivePath}" -d "${extractDir}"`);
  } else {
    run(`tar -xf "${archivePath}" -C "${extractDir}"`);
  }
}

function installFlutter() {
  if (fs.existsSync(path.join(flutterBin, 'flutter'))) {
    console.log('Using cached Flutter SDK at', flutterDir);
    return;
  }

  const archiveInfo = flutterArchiveInfo();
  console.log(`Installing Flutter SDK ${flutterArchiveVersion} from the official release archive...`);
  fs.rmSync(flutterDir, { recursive: true, force: true });
  fs.mkdirSync(flutterDir, { recursive: true });

  const archivePath = path.join(repoRoot, 'flutter_linux.tar.xz');
  const extractDir = path.join(repoRoot, '.flutter-sdk-extract');
  fs.rmSync(archivePath, { force: true });
  fs.rmSync(extractDir, { recursive: true, force: true });
  fs.mkdirSync(extractDir, { recursive: true });
  run(`curl -L --retry 3 --fail "${archiveInfo.url}" -o "${archivePath}"`);
  extractArchive(archivePath, extractDir, archiveInfo.url);

  const extractedFlutterDir = path.join(extractDir, archiveInfo.extractFolder);
  if (!fs.existsSync(extractedFlutterDir)) {
    throw new Error(`Flutter release archive did not contain expected folder: ${extractedFlutterDir}`);
  }

  fs.renameSync(extractedFlutterDir, flutterDir);
  fs.rmSync(archivePath, { force: true });
  fs.rmSync(extractDir, { recursive: true, force: true });

  if (!fs.existsSync(path.join(flutterBin, 'flutter'))) {
    throw new Error('Flutter release archive did not produce a usable SDK at .flutter-sdk');
  }
}

installFlutter();

// Make the freshly-installed Flutter SDK available to every command below.
process.env.PATH = `${flutterBin}${path.delimiter}${process.env.PATH}`;
process.env.CI = 'true';
process.env.FLUTTER_SUPPRESS_ANALYTICS = 'true';

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
