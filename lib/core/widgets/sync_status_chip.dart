import 'package:flutter/material.dart';

/// Status of a sync operation
enum SyncStatus { pending, synced, error }

/// Sync status chip to show sync state of offline operations
///
/// Color-coded:
/// - Yellow: pending sync (waiting for network)
/// - Green: synced successfully
/// - Red: sync error (tap to retry)
///
/// Used in:
/// - Time clock entries
/// - Invoice list items
/// - Estimate list items
/// - Any offline-queueable operation
class SyncStatusChip extends StatelessWidget {
  final SyncStatus status;
  final VoidCallback? onRetry;
  final String? errorMessage;

  const SyncStatusChip({
    Key? key,
    required this.status,
    this.onRetry,
    this.errorMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color backgroundColor;
    Color foregroundColor;
    IconData icon;
    String label;

    switch (status) {
      case SyncStatus.pending:
        backgroundColor = Colors.amber.shade100;
        foregroundColor = Colors.amber.shade900;
        icon = Icons.sync;
        label = 'Syncing...';
        break;
      case SyncStatus.synced:
        backgroundColor = Colors.green.shade100;
        foregroundColor = Colors.green.shade900;
        icon = Icons.check_circle;
        label = 'Synced';
        break;
      case SyncStatus.error:
        backgroundColor = Colors.red.shade100;
        foregroundColor = Colors.red.shade900;
        icon = Icons.error;
        label = 'Error';
        break;
    }

    final chip = Chip(
      avatar: Icon(icon, size: 16, color: foregroundColor),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: foregroundColor,
        ),
      ),
      backgroundColor: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      visualDensity: VisualDensity.compact,
    );

    // For error status, wrap in InkWell for retry
    if (status == SyncStatus.error && onRetry != null) {
      return Tooltip(
        message: errorMessage ?? 'Tap to retry',
        child: InkWell(
          onTap: onRetry,
          borderRadius: BorderRadius.circular(16),
          child: chip,
        ),
      );
    }

    return chip;
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
    Key? key,
    required this.pendingCount,
    this.isSyncing = false,
    this.onTap,
  }) : super(key: key);

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
