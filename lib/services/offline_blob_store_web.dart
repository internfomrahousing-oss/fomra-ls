import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

const _prefix = 'fomra_blob_v1_';

Future<String> putBlob(Uint8List bytes, {String ext = 'bin'}) async {
  final id = 'b_${DateTime.now().microsecondsSinceEpoch}.$ext';
  final prefs = await SharedPreferences.getInstance();
  // Web: store as base64 in prefs (voice notes / compressed photos are small).
  await prefs.setString('$_prefix$id', base64Encode(bytes));
  return id;
}

Future<Uint8List?> getBlob(String id) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('$_prefix$id');
  if (raw == null) return null;
  return Uint8List.fromList(base64Decode(raw));
}

Future<void> deleteBlob(String id) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('$_prefix$id');
}
