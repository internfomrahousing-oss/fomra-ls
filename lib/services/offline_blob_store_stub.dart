import 'dart:typed_data';

Future<String> putBlob(Uint8List bytes, {String ext = 'bin'}) async {
  throw UnsupportedError('Offline blob store unavailable on this platform');
}

Future<Uint8List?> getBlob(String id) async => null;

Future<void> deleteBlob(String id) async {}
