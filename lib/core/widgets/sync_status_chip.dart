/// A tiny status chip that shows the current [models.SyncStatus].
///
/// IMPORTANT: This widget does not define its own enum. It imports the one
/// from core/models/sync_status.dart to avoid type conflicts in tests and
/// call sites.
library sync_status_chip;

import 'package:flutter/material.dart';
import 'package:sierra_painting/core/models/sync_status.dart' as models;

class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({
    super.key,
    required this.status,
  });

  final models.SyncStatus status;

  Color _bg(BuildContext context) {
    switch (status) {
      case models.SyncStatus.synced:
        return Colors.green.shade100;
      case models.SyncStatus.pending:
        return Colors.amber.shade100;
      case models.SyncStatus.failed:
        return Colors.red.shade100;
    }
  }

  Color _fg(BuildContext context) {
    switch (status) {
      case models.SyncStatus.synced:
        return Colors.green.shade900;
      case models.SyncStatus.pending:
        return Colors.amber.shade900;
      case models.SyncStatus.failed:
        return Colors.red.shade900;
    }
  }

  IconData _icon() {
    switch (status) {
      case models.SyncStatus.synced:
        return Icons.check_circle_rounded;
      case models.SyncStatus.pending:
        return Icons.sync_rounded;
      case models.SyncStatus.failed:
        return Icons.error_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'sync-status-${status.name}',
      child: Chip(
        backgroundColor: _bg(context),
        avatar: Icon(_icon(), size: 18, color: _fg(context)),
        label: Text(
          status.label,
          style: TextStyle(
            color: _fg(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
    );
  }
}


/// Global sync status indicator for app bar
///
/// Shows aggregate status of all pending sync operations:
/// - Number of pending items
/// - Sync in progress indicator
/// - Tap to view sync queue
class GlobalSyncIndicator extends StatelessWidget {
  final int pendingCount;
  final bool isSyncing;
  final VoidCallback? onTap;

  const GlobalSyncIndicator({
    super.key,
    required this.pendingCount,
    this.isSyncing = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (pendingCount == 0 && !isSyncing) {
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: Badge(
        label: Text('$pendingCount'),
        isLabelVisible: pendingCount > 0,
        child: isSyncing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.cloud_upload),
      ),
      onPressed: onTap,
      tooltip: pendingCount > 0
          ? '$pendingCount item${pendingCount == 1 ? '' : 's'} pending sync'
          : 'Syncing...',
    );
  }
}
