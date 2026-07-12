import 'dart:typed_data';

Future<Uint8List> readBytes(String path) async => Uint8List(0);

Future<String> tempRecordPath() async =>
    'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
