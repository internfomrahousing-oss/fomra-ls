import 'dart:typed_data';

import 'offline_blob_store_stub.dart'
    if (dart.library.html) 'offline_blob_store_web.dart'
    if (dart.library.io) 'offline_blob_store_io.dart' as impl;

abstract final class OfflineBlobStore {
  static Future<String> put(Uint8List bytes, {String ext = 'bin'}) =>
      impl.putBlob(bytes, ext: ext);

  static Future<Uint8List?> get(String id) => impl.getBlob(id);

  static Future<void> delete(String id) => impl.deleteBlob(id);
}
