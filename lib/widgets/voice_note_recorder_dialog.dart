import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../services/voice_note_service.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';
import '../utils/voice_note_bytes.dart';

/// Record + playback dialog. Stores audio only — no speech-to-text.
Future<bool?> showVoiceNoteRecorderDialog(
  BuildContext context, {
  required String leadId,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _VoiceNoteRecorderDialog(leadId: leadId),
  );
}

class _VoiceNoteRecorderDialog extends StatefulWidget {
  final String leadId;
  const _VoiceNoteRecorderDialog({required this.leadId});

  @override
  State<_VoiceNoteRecorderDialog> createState() =>
      _VoiceNoteRecorderDialogState();
}

class _VoiceNoteRecorderDialogState extends State<_VoiceNoteRecorderDialog> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  bool _recording = false;
  bool _saving = false;
  String? _error;
  String? _filePath;
  Uint8List? _bytes;
  Duration _elapsed = Duration.zero;
  Timer? _tick;
  DateTime? _startedAt;

  @override
  void dispose() {
    _tick?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _bytes = null;
      _filePath = null;
      _elapsed = Duration.zero;
    });
    try {
      if (!await _recorder.hasPermission()) {
        setState(() => _error = 'Microphone permission denied.');
        return;
      }
      final path = await voiceNoteTempPath();
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      _startedAt = DateTime.now();
      _tick?.cancel();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_startedAt == null || !mounted) return;
        setState(() => _elapsed = DateTime.now().difference(_startedAt!));
      });
      setState(() {
        _recording = true;
        _filePath = path;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _stop() async {
    try {
      final path = await _recorder.stop();
      _tick?.cancel();
      final resolved = path ?? _filePath;
      Uint8List? bytes;
      if (resolved != null) {
        bytes = await voiceNoteReadBytes(resolved);
      }
      setState(() {
        _recording = false;
        _filePath = resolved;
        _bytes = bytes;
      });
    } catch (e) {
      setState(() {
        _recording = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _play() async {
    try {
      if (_bytes != null && _bytes!.isNotEmpty) {
        await _player.play(BytesSource(_bytes!));
      } else if (_filePath != null) {
        await _player.play(DeviceFileSource(_filePath!));
      }
    } catch (e) {
      setState(() => _error = 'Playback failed: $e');
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    var bytes = _bytes;
    if ((bytes == null || bytes.isEmpty) && _filePath != null) {
      bytes = await voiceNoteReadBytes(_filePath!);
    }
    if (bytes == null || bytes.isEmpty) {
      setState(() => _error = 'No recording to save.');
      return;
    }
    setState(() => _saving = true);
    try {
      await VoiceNoteService.saveOfflineOrUpload(
        leadId: widget.leadId,
        bytes: bytes,
        durationMs: _elapsed.inMilliseconds.clamp(500, 3600000),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final hasTake = (_bytes != null && _bytes!.isNotEmpty) ||
        (_filePath != null && !_recording);
    return AlertDialog(
      title: const Text('Voice note'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Record and store audio. Speech is not converted to text.',
            style: TextStyle(fontSize: 12, color: context.fomraTextSecondary),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _fmt(_elapsed),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: _recording ? AppColors.error : context.fomraTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12)),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_recording)
                FilledButton.icon(
                  onPressed: _saving ? null : _start,
                  icon: const Icon(Icons.mic),
                  label: const Text('Record'),
                )
              else
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                  ),
                  onPressed: _stop,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
              if (hasTake && !_recording) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _play,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play'),
                ),
              ],
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_saving || _recording || !hasTake) ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
