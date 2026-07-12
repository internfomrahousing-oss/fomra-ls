import 'package:flutter/material.dart';

import '../services/offline_sync_service.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';

/// Compact banner showing offline / pending-sync status.
class OfflineStatusBanner extends StatelessWidget {
  const OfflineStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: OfflineSyncService.instance,
      builder: (context, _) {
        final sync = OfflineSyncService.instance;
        if (sync.isOnline && sync.pendingCount == 0 && !sync.isSyncing) {
          return const SizedBox.shrink();
        }

        final offline = !sync.isOnline;
        final color = offline
            ? AppColors.warning
            : (sync.isSyncing ? AppColors.info : AppColors.primary);
        final text = offline
            ? 'Offline · ${sync.pendingCount} change(s) queued'
            : sync.isSyncing
                ? 'Syncing queued field data…'
                : '${sync.pendingCount} change(s) waiting to sync';

        return Material(
          color: color.withValues(alpha: 0.12),
          child: InkWell(
            onTap: sync.isOnline && !sync.isSyncing
                ? () => sync.syncNow()
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    offline
                        ? Icons.cloud_off_rounded
                        : Icons.cloud_sync_rounded,
                    size: 18,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.fomraTextPrimary,
                      ),
                    ),
                  ),
                  if (sync.isOnline &&
                      sync.pendingCount > 0 &&
                      !sync.isSyncing)
                    Text(
                      'Tap to sync',
                      style: TextStyle(fontSize: 11, color: color),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
