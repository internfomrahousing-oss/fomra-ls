import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<void> saveCsv(Uint8List bytes, String filename) async {
  await FilePicker.platform.saveFile(
    fileName: filename,
    bytes: bytes,
    type: FileType.custom,
    allowedExtensions: const ['csv'],
  );
}
