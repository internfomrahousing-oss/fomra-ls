import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/profile_photo_service.dart';
import '../../theme/fomra_theme_context.dart';
import 'app_feedback.dart';

/// Circular avatar that shows the account's uploaded profile photo (per email),
/// falling back to the name's initial when there is no photo. Rebuilds when the
/// photo changes via [ProfilePhotoService].
class ProfileAvatar extends StatelessWidget {
  final String? email;
  final String name;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const ProfileAvatar({
    super.key,
    required this.email,
    required this.name,
    this.radius = 15,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;
    final initial =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    Widget fallback() => Container(
          width: diameter,
          height: diameter,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor ?? context.fomraSurfaceVar,
            shape: BoxShape.circle,
          ),
          child: Text(
            initial,
            style: TextStyle(
              color: foregroundColor ?? context.fomraTextPrimary,
              fontWeight: FontWeight.w800,
              fontSize: radius * 0.85,
            ),
          ),
        );

    return AnimatedBuilder(
      animation: ProfilePhotoService.instance,
      builder: (context, _) {
        final url = ProfilePhotoService.instance.urlFor(email);
        if (url == null) return fallback();
        return ClipOval(
          child: Image.network(
            url,
            width: diameter,
            height: diameter,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => fallback(),
          ),
        );
      },
    );
  }
}

/// Shared "upload profile photo" flow: mobile offers camera/gallery via the
/// native picker, desktop/web use the file picker. Compression happens inside
/// [ProfilePhotoService]. Shows success/error feedback.
Future<void> uploadProfilePhotoFlow(BuildContext context) async {
  final mobileNative = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Uint8List? bytes;
  try {
    if (mobileNative) {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: context.fomraSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      if (source == null) return;
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 90,
      );
      if (picked == null) return;
      bytes = await picked.readAsBytes();
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      bytes = result.files.first.bytes;
    }

    if (bytes == null) {
      if (context.mounted) {
        AppFeedback.error(context, 'Could not read the selected image.');
      }
      return;
    }

    // Circular crop / reposition before upload.
    if (!context.mounted) return;
    final cropped = await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CircleCropperDialog(bytes: bytes!),
    );
    if (cropped == null) return; // cancelled

    // Existing flow: compresses then uploads to the same storage path and
    // notifies every avatar immediately.
    await ProfilePhotoService.instance.uploadForCurrentUser(cropped);
    if (context.mounted) {
      AppFeedback.success(context, 'Profile photo updated');
    }
  } catch (e) {
    if (context.mounted) {
      AppFeedback.error(
          context, e.toString().replaceFirst('Exception: ', ''));
    }
  }
}

/// Circular cropper: drag to reposition and pinch/scroll to zoom inside a
/// circular guide. Returns the square PNG crop (avatars mask it to a circle),
/// which the existing upload flow then compresses and stores.
class _CircleCropperDialog extends StatefulWidget {
  final Uint8List bytes;

  const _CircleCropperDialog({required this.bytes});

  @override
  State<_CircleCropperDialog> createState() => _CircleCropperDialogState();
}

class _CircleCropperDialogState extends State<_CircleCropperDialog> {
  static const _cropSize = 280.0;

  final _boundaryKey = GlobalKey();
  final _controller = TransformationController();
  ui.Image? _decoded;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _decoded?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    try {
      final image = await decodeImageFromList(widget.bytes);
      if (!mounted) return;
      setState(() => _decoded = image);
      // Centre the cover-fitted image inside the square viewport.
      final size = _childSize(image);
      _controller.value = Matrix4.identity()
        ..translateByDouble(
          -(size.width - _cropSize) / 2,
          -(size.height - _cropSize) / 2,
          0,
          1,
        );
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not read the selected image.');
    }
  }

  /// Cover-fit the image to the square viewport (short side == _cropSize) so
  /// the crop area is always filled and the long axis can be repositioned.
  Size _childSize(ui.Image image) {
    final iw = image.width.toDouble();
    final ih = image.height.toDouble();
    if (iw <= 0 || ih <= 0) return const Size(_cropSize, _cropSize);
    final scale = math.max(_cropSize / iw, _cropSize / ih);
    return Size(iw * scale, ih * scale);
  }

  Future<void> _confirm() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      // 3x keeps the stored crop sharp; the upload flow compresses afterwards.
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw Exception('Could not render the crop.');
      if (!mounted) return;
      Navigator.pop(context, data.buffer.asUint8List());
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.error(
          context, 'Crop failed: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final decoded = _decoded;
    final childSize = decoded == null ? null : _childSize(decoded);

    return Dialog(
      backgroundColor: context.fomraSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Adjust photo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.fomraTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Drag to reposition · pinch or scroll to zoom',
                style:
                    TextStyle(fontSize: 12, color: context.fomraTextSecondary),
              ),
              const SizedBox(height: 14),
              Center(
                child: SizedBox(
                  width: _cropSize,
                  height: _cropSize,
                  child: _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: context.fomraTextSecondary),
                          ),
                        )
                      : decoded == null
                          ? const Center(child: CircularProgressIndicator())
                          : Stack(
                              children: [
                                // Only this subtree is captured as the crop.
                                RepaintBoundary(
                                  key: _boundaryKey,
                                  child: SizedBox(
                                    width: _cropSize,
                                    height: _cropSize,
                                    child: InteractiveViewer(
                                      transformationController: _controller,
                                      constrained: false,
                                      clipBehavior: Clip.hardEdge,
                                      minScale: 1,
                                      maxScale: 5,
                                      boundaryMargin: EdgeInsets.zero,
                                      child: SizedBox(
                                        width: childSize!.width,
                                        height: childSize.height,
                                        child: Image.memory(
                                          widget.bytes,
                                          fit: BoxFit.fill,
                                          filterQuality: FilterQuality.high,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Circular guide drawn on top, outside the
                                // boundary so it is never part of the crop.
                                const Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: _CircleGuidePainter(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed:
                        (_saving || decoded == null) ? null : _confirm,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Use photo'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dims everything outside the circular crop area and draws the guide ring.
class _CircleGuidePainter extends CustomPainter {
  const _CircleGuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = math.min(size.width, size.height) / 2;
    final center = rect.center;

    final overlay = Path.combine(
      PathOperation.difference,
      Path()..addRect(rect),
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawPath(
      overlay,
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
