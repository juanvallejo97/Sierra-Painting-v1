# Offline-first design

This document explains Sierra Painting's offline-first architecture and why it's critical for field
workers.

## Why offline-first?

Painting crews work in buildings with:

- No WiFi
- Poor cellular coverage
- Concrete walls blocking signal
- Remote job sites

Traditional online-only apps would be unusable. Offline-first design ensures the app works
everywhere.

## How it works

### 1. Local-first storage

All data is stored locally first using Hive:

```dart
// Write happens immediately to local storage
await hiveService.saveTimeEntry(entry);

// Queue sync to server
await syncQueue.add(SyncOperation(
  type: 'createTimeEntry',
  data: entry.toJson(),
));
```

**User experience**: Instant feedback, no waiting for network.

### 2. Background synchronization

When connectivity is available, queued operations sync:

```
User Action → Local Storage → Sync Queue → Firestore
    ↓              ↓              ↓            ↓
Instant UI    Persisted     Queued      Synced when
  Update      Locally      for Sync     connected
```

**Sync characteristics**:

- Automatic when connection detected
- Retries with exponential backoff
- Preserves operation order
- Handles conflicts

### 3. Optimistic updates

UI updates immediately before server confirmation:

1. User clocks in
2. UI shows "clocked in" immediately
3. Entry queued for sync
4. Background sync happens later
5. UI confirms sync when complete

**Trade-off**: Rare cases where operation fails require rollback.

## Conflict resolution

Conflicts are rare but handled when they occur.

### Timestamp-based resolution

Most conflicts resolved by timestamp:

```dart
if (localEntry.timestamp > serverEntry.timestamp) {
  // Local wins - more recent
  await firestore.update(localEntry);
} else {
  // Server wins - keep server version
  await hive.update(serverEntry);
}
```

### Manual resolution

Admin operations (like marking paid) require manual resolution:

```dart
if (conflict.type == ConflictType.adminOperation) {
  // Show conflict to admin
  await showConflictDialog(conflict);
}
```

## Operation types

Different operations have different sync priorities.

### High priority (sync immediately)

- Clock in/out
- Emergency operations
- Payment confirmations

### Normal priority (sync within 5s)

- Time entry creation
- Job updates
- Note additions

### Low priority (batch sync)

- Analytics events
- Performance metrics
- Telemetry

## Queue management

### Queue structure

```dart
class SyncOperation {
  String id;              // Unique operation ID
  String type;            // Operation type
  Map<String, dynamic> data;
  DateTime createdAt;
  int retryCount;
  DateTime? lastRetryAt;
}
```

### Queue persistence

Queue survives app restarts:

- Stored in Hive
- Loaded on app start
- Resumed automatically

### Failed operations

Operations that fail repeatedly:

1. Retry with exponential backoff (1s, 2s, 4s, 8s, 16s)
2. After 5 failures, mark as "needs attention"
3. Admin can view and resolve failed operations
4. User notified when sync issues persist

## Network detection

App monitors connectivity:

```dart
class NetworkService {
  Stream<bool> get connectivity;  // Real-time connection status
  
  Future<bool> hasConnection();   // One-time check
  
  void startListening() {
    // Monitor network changes
    // Trigger sync when connection restored
  }
}
```

**Triggers**:

- App returns to foreground
- Network state changes
- Manual sync button
- Periodic background check (every 5 minutes)

## User experience

### Connection indicators

UI shows connection status:

- **Green dot**: Connected, synced
- **Yellow dot**: Offline, queued
- **Red dot**: Sync failed, needs attention

### Manual sync

Users can force sync:

```dart
ElevatedButton(
  onPressed: () async {
    await syncService.syncNow();
  },
  child: Text('Sync Now'),
)
```

### Sync status

Sync status available in settings:

- Last sync time
- Pending operations count
- Failed operations (if any)

## Testing offline behavior

### Emulator testing

1. Start app in online mode
2. Perform actions (clock in, add note)
3. Disable network in emulator
4. Verify UI still responsive
5. Enable network
6. Verify sync completes

### Manual testing

1. Enable airplane mode
2. Use app normally
3. Verify all features work
4. Disable airplane mode
5. Verify sync happens automatically

## Performance characteristics

| Operation | Offline | Online with sync |
|-----------|---------|-----------------|
| Clock in | < 100ms | < 100ms + background sync |
| Add note | < 50ms | < 50ms + background sync |
| Load jobs | < 200ms | < 200ms (from cache) |
| Sync queue | N/A | 1-5s per operation |

## Limitations

### Operations requiring server

Some operations can't work offline:

- Initial sign-in (requires Firebase Auth)
- PDF generation (server-side)
- Stripe payments (requires API)
- Lead form submission (requires verification)

**Workaround**: Queue operations, execute when online.

### Storage limits

Local storage is limited:

- Hive: ~10MB typical, ~100MB maximum
- Keep only recent data locally
- Archive older data on server

## Implementation details

### Key packages

```yaml
dependencies:
  hive: ^2.2.3              # Local storage
  connectivity_plus: ^5.0.2  # Network detection
  riverpod: ^2.4.9          # State management
```

### Key services

```dart
class OfflineService {
  Future<void> queueOperation(SyncOperation op);
  Future<void> syncQueue();
  Stream<SyncStatus> get syncStatus;
}

class SyncQueue {
  List<SyncOperation> get pending;
  Future<void> process();
  Future<void> retryFailed();
}
```

## Best practices

1. **Always queue writes**: Never assume network available
2. **Show sync status**: Keep users informed
3. **Graceful degradation**: Disable features that require network
4. **Test offline**: Include offline scenarios in tests
5. **Monitor queue size**: Alert if queue grows too large

## Next steps

- [System architecture](architecture.md)
- [How to run tests](../how-to/run-tests.md)
- [Understanding sync conflicts](sync-conflicts.md)

---