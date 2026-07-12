import 'dart:html' as html;
import 'dart:typed_data';

Future<Uint8List> readBytes(String path) async {
  // On web, record often returns a blob: URL.
  if (path.startsWith('blob:')) {
    final request = await html.HttpRequest.request(
      path,
      responseType: 'arraybuffer',
    );
    final buffer = request.response as ByteBuffer?;
    if (buffer == null) return Uint8List(0);
    return buffer.asUint8List();
  }
  return Uint8List(0);
}

Future<String> tempRecordPath() async =>
    'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
