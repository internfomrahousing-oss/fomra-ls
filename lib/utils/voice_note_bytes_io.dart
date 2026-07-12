import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<Uint8List> readBytes(String path) async {
  final file = File(path);
  if (!await file.exists()) return Uint8List(0);
  return file.readAsBytes();
}

Future<String> tempRecordPath() async {
  final dir = await getTemporaryDirectory();
  return '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
}
