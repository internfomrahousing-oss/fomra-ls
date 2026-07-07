// Fallback used only when neither dart:html nor dart:io is available.
import 'dart:typed_data';

Future<void> savePdf(Uint8List bytes, String filename) async {
  throw UnsupportedError('Saving a PDF is not supported on this platform.');
}
