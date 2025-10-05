/// Single source of truth for sync-state across the app.
enum SyncStatus {
  /// Data is fully synced with the backend.
  synced,

  /// Sync is pending (e.g., queued/offline work still to be uploaded).
  pending,

  /// A previous sync failed (optional state - used by UI if needed).
  failed,
}

/// Optional helpers usable by presentation/widgets.
extension SyncStatusX on SyncStatus {
  String get label {
    switch (this) {
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.pending:
        return 'Pending';
      case SyncStatus.failed:
        return 'Failed';
    }
  }
}
