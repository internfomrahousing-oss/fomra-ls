// Generates the square application icon from the Fomra wordmark logo.
//
// The brand asset (assets/images/fomra_logo.png) is a wide wordmark, which
// would be distorted/letterboxed if fed straight to flutter_launcher_icons.
// This composites it centred on a square white canvas (with safe padding so
// Android's circular/adaptive masking never clips the mark) and writes:
//   assets/images/app_icon.png           – full-bleed square icon
//   assets/images/app_icon_foreground.png – padded foreground for adaptive icons
//
// Run:  dart run tool/generate_app_icon.dart
import 'dart:io';

import 'package:image/image.dart' as img;

const _source = 'assets/images/fomra_logo.png';
const _iconOut = 'assets/images/app_icon.png';
const _foregroundOut = 'assets/images/app_icon_foreground.png';
const _size = 1024;

img.Image _compose(img.Image logo, {required double scale, bool white = true}) {
  final canvas = img.Image(width: _size, height: _size, numChannels: 4);
  if (white) {
    img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));
  } else {
    img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));
  }

  // Fit the wordmark inside `scale` of the canvas, preserving aspect ratio.
  final maxW = (_size * scale).round();
  final ratio = logo.height / logo.width;
  var w = maxW;
  var h = (maxW * ratio).round();
  if (h > _size * scale) {
    h = (_size * scale).round();
    w = (h / ratio).round();
  }

  final resized = img.copyResize(
    logo,
    width: w,
    height: h,
    interpolation: img.Interpolation.cubic,
  );

  img.compositeImage(
    canvas,
    resized,
    dstX: ((_size - w) / 2).round(),
    dstY: ((_size - h) / 2).round(),
  );
  return canvas;
}

void main() {
  final file = File(_source);
  if (!file.existsSync()) {
    stderr.writeln('Source logo not found: $_source');
    exitCode = 1;
    return;
  }
  final logo = img.decodePng(file.readAsBytesSync());
  if (logo == null) {
    stderr.writeln('Could not decode $_source');
    exitCode = 1;
    return;
  }

  // Full icon: wordmark at 72% of the canvas on white.
  File(_iconOut).writeAsBytesSync(
    img.encodePng(_compose(logo, scale: 0.72)),
  );

  // Adaptive foreground: Android masks ~66% of the canvas, so keep the mark
  // well inside the safe zone on a transparent background.
  File(_foregroundOut).writeAsBytesSync(
    img.encodePng(_compose(logo, scale: 0.52, white: false)),
  );

  stdout.writeln('Wrote $_iconOut and $_foregroundOut (${_size}x$_size)');
}
