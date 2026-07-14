import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

    await ProfilePhotoService.instance.uploadForCurrentUser(bytes);
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
