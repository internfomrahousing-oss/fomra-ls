import 'dart:typed_data';

import 'voice_note_bytes_stub.dart'
    if (dart.library.html) 'voice_note_bytes_web.dart'
    if (dart.library.io) 'voice_note_bytes_io.dart' as impl;

Future<Uint8List> voiceNoteReadBytes(String path) => impl.readBytes(path);

Future<String> voiceNoteTempPath() => impl.tempRecordPath();
