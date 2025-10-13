/// Pending Sync Chip
///
/// PURPOSE:
/// Visual indicator showing offline operations pending sync.
/// Helps user understand app state when network unavailable.
///
/// STATES:
/// - Syncing: animated spinner, "Syncing..."
/// - Pending: warning icon, "N pending"
/// - Error: error icon, "Sync failed. Tap to retry"
///
/// INTERACTION:
/// - Tap to show detail dialog with list of pending operations
/// - Retry button for failed syncs
library;

import 'package:flutter/material.dart';

/// Sync status for display
enum SyncStatus { synced, syncing, pending, error }

/// Pending sync chip widget
///
/// USAGE:
/// ```dart
/// if (hasPendingSync)
///   PendingSyncChip(
///     status: syncStatus,
///     pendingCount: 3,
///     onTap: () => _showSyncDetails(),
///   )
/// ```
class PendingSyncChip extends StatelessWidget {
  final SyncStatus status;
  final int pendingCount;
  final VoidCallback? onTap;

  const PendingSyncChip({
    super.key,
    this.status = SyncStatus.pending,
    this.pendingCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (status == SyncStatus.synced) {
      return const SizedBox.shrink();
    }

    return Semantics(
      label: _getSemanticLabel(),
      button: onTap != null,
      child: ActionChip(
        avatar: _buildIcon(),
        label: Text(_getLabel(), style: const TextStyle(fontSize: 12)),
        backgroundColor: _getBackgroundColor(),
        onPressed: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildIcon() {
    switch (status) {
      case SyncStatus.syncing:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        );
      case SyncStatus.pending:
        return const Icon(
          Icons.cloud_upload_outlined,
          size: 16,
          color: Colors.orange,
        );
      case SyncStatus.error:
        return const Icon(Icons.error_outline, size: 16, color: Colors.red);
      case SyncStatus.synced:
        return const SizedBox.shrink();
    }
  }

  String _getLabel() {
    switch (status) {
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.pending:
        return pendingCount > 0 ? '$pendingCount pending' : 'Pending';
      case SyncStatus.error:
        return 'Sync failed';
      case SyncStatus.synced:
        return '';
    }
  }

  String _getSemanticLabel() {
    switch (status) {
      case SyncStatus.syncing:
        return 'Syncing pending operations';
      case SyncStatus.pending:
        return '$pendingCount operations pending sync. Tap for details.';
      case SyncStatus.error:
        return 'Sync failed. Tap to retry.';
      case SyncStatus.synced:
        return '';
    }
  }

  Color _getBackgroundColor() {
    switch (status) {
      case SyncStatus.syncing:
        return Colors.blue.shade50;
      case SyncStatus.pending:
        return Colors.orange.shade50;
      case SyncStatus.error:
        return Colors.red.shade50;
      case SyncStatus.synced:
        return Colors.transparent;
    }
  }
}

/// Sync Details Dialog
///
/// Shows list of pending operations with retry/cancel options.
///
/// IMPLEMENTATION TODO:
/// - List pending operations from queue
/// - Retry individual operations
/// - Clear failed operations
/// - Show sync timestamps
class SyncDetailsDialog extends StatelessWidget {
  final List<PendingOperation> operations;
  final VoidCallback? onRetryAll;
  final VoidCallback? onClearFailed;

  const SyncDetailsDialog({
    super.key,
    required this.operations,
    this.onRetryAll,
    this.onClearFailed,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pending Sync'),
      content: SizedBox(
        width: double.maxFinite,
        child: operations.isEmpty
            ? const Text('No pending operations')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: operations.length,
                itemBuilder: (context, index) {
                  final op = operations[index];
                  return ListTile(
                    leading: Icon(
                      op.status == OperationStatus.pending
                          ? Icons.pending
                          : Icons.error_outline,
                      color: op.status == OperationStatus.pending
                          ? Colors.orange
                          : Colors.red,
                    ),
                    title: Text(op.description),
                    subtitle: Text(
                      op.timestamp.toString(),
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: op.status == OperationStatus.failed
                        ? IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: op.onRetry,
                            tooltip: 'Retry',
                          )
                        : null,
                  );
                },
              ),
      ),
      actions: [
        if (operations.any((op) => op.status == OperationStatus.failed))
          TextButton(
            onPressed: onClearFailed,
            child: const Text('Clear Failed'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (operations.isNotEmpty)
          FilledButton(onPressed: onRetryAll, child: const Text('Retry All')),
      ],
    );
  }
}

/// Pending operation model
class PendingOperation {
  final String id;
  final String description;
  final DateTime timestamp;
  final OperationStatus status;
  final VoidCallback? onRetry;

  PendingOperation({
    required this.id,
    required this.description,
    required this.timestamp,
    required this.status,
    this.onRetry,
  });
}

enum OperationStatus { pending, syncing, failed }
