import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<Directory> _dir() async {
  final root = await getApplicationDocumentsDirectory();
  final d = Directory('${root.path}/offline_blobs');
  if (!await d.exists()) await d.create(recursive: true);
  return d;
}

Future<String> putBlob(Uint8List bytes, {String ext = 'bin'}) async {
  final id = 'b_${DateTime.now().microsecondsSinceEpoch}.$ext';
  final dir = await _dir();
  final file = File('${dir.path}/$id');
  await file.writeAsBytes(bytes, flush: true);
  return id;
}

Future<Uint8List?> getBlob(String id) async {
  final dir = await _dir();
  final file = File('${dir.path}/$id');
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

Future<void> deleteBlob(String id) async {
  final dir = await _dir();
  final file = File('${dir.path}/$id');
  if (await file.exists()) await file.delete();
}
