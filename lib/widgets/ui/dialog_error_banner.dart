import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Inline validation/error banner for dialogs — shown inside the dialog window
/// instead of a page-level toast that can appear behind the dialog.
///
/// Renders nothing when [message] is null/empty, so it can be dropped into a
/// column unconditionally.
class DialogErrorBanner extends StatelessWidget {
  final String? message;

  const DialogErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final msg = message?.trim() ?? '';
    if (msg.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
