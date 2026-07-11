import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Compresses uploaded photos to at most [maxBytes] (default 250 KB) as JPEG.
class ImageCompressor {
  ImageCompressor._();

  static const int maxBytes = 250 * 1024;
  static const int maxBytes1Mb = 1024 * 1024;

  static Future<Uint8List> compressTo250Kb(Uint8List input) =>
      compressImage(input, maxTargetBytes: maxBytes);

  static Future<Uint8List> compressTo1Mb(Uint8List input) =>
      compressImage(input, maxTargetBytes: maxBytes1Mb);

  static Future<Uint8List> compressImage(
    Uint8List input, {
    int maxTargetBytes = maxBytes,
  }) async {
    final decoded = img.decodeImage(input);
    if (decoded == null) {
      throw Exception('Could not read image. Use JPG or PNG.');
    }

    var image = decoded;
    const maxDim = 1920;
    if (image.width > maxDim || image.height > maxDim) {
      image = image.width >= image.height
          ? img.copyResize(image, width: maxDim)
          : img.copyResize(image, height: maxDim);
    }

    Uint8List? best;
    var scale = 1.0;

    while (scale >= 0.35) {
      final working = scale < 1.0
          ? img.copyResize(
              image,
              width: (image.width * scale).round().clamp(320, image.width),
              height: (image.height * scale).round().clamp(240, image.height),
            )
          : image;

      for (var quality = 85; quality >= 25; quality -= 5) {
        final out = Uint8List.fromList(img.encodeJpg(working, quality: quality));
        best = out;
        if (out.length <= maxTargetBytes) return out;
      }
      scale -= 0.15;
    }

    return best ?? Uint8List.fromList(img.encodeJpg(image, quality: 25));
  }

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
