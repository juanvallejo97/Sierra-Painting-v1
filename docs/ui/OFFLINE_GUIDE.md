# Offline & Network Resilience Guide

This guide documents how to implement and test offline/weak-network states in the Sierra Painting app.

## Architecture Overview

The app implements an **offline-first architecture** with local queue persistence and automatic sync when connectivity is restored.

See: `docs/ADRs/0002-offline-first-architecture.md` for detailed design decisions.

---

## Core Components

### 1. OfflineService

Location: `lib/core/services/offline_service.dart`

Manages offline data persistence using Hive:
- Stores user data locally
- Provides offline read access
- Queues write operations when offline

### 2. QueueService

Location: `lib/core/services/queue_service.dart`

Manages the sync queue for offline operations:
- Queues write operations (clock in/out, create invoice, etc.)
- Automatically retries failed operations
- Provides queue status information

### 3. SyncStatusChip

Location: `lib/core/widgets/sync_status_chip.dart`

Visual indicator for sync state:
- **Pending** (Yellow): Waiting for network
- **Synced** (Green): Successfully synced
- **Error** (Red): Sync failed, tap to retry

### 4. GlobalSyncIndicator

Location: `lib/core/widgets/sync_status_chip.dart`

App-wide sync status in the app bar:
- Badge showing number of pending items
- Spinner when sync is in progress
- Tap to view sync queue details

---

## Implementation Patterns

### Pattern 1: Offline-First Write Operations

```dart
Future<void> clockIn(String userId, String jobId) async {
  final now = DateTime.now();
  
  // 1. Update local state immediately (optimistic update)
  await _localDb.saveTimeEntry(TimeEntry(
    userId: userId,
    jobId: jobId,
    clockInTime: now,
    status: SyncStatus.pending,
  ));
  
  // 2. Queue operation for sync
  await _queueService.enqueue(QueueItem(
    id: uuid.v4(),
    operation: 'clockIn',
    data: {
      'userId': userId,
      'jobId': jobId,
      'timestamp': now.toIso8601String(),
    },
    createdAt: now,
  ));
  
  // 3. Attempt immediate sync (will retry automatically if fails)
  _queueService.processPendingItems();
}
```

### Pattern 2: Offline-First Read Operations

```dart
Future<List<Invoice>> getInvoices({bool forceRefresh = false}) async {
  // 1. Return cached data immediately
  final cached = await _localDb.getInvoices();
  
  // 2. Attempt to refresh from server in background
  if (forceRefresh || await _shouldRefresh()) {
    try {
      final fresh = await _api.getInvoices();
      await _localDb.saveInvoices(fresh);
      return fresh;
    } catch (e) {
      // Network error - return cached data
      return cached;
    }
  }
  
  return cached;
}

bool _shouldRefresh() {
  final lastSync = _prefs.getLastSyncTime();
  final now = DateTime.now();
  return now.difference(lastSync) > const Duration(minutes: 5);
}
```

### Pattern 3: Connectivity Detection

```dart
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  
  Stream<bool> get isOnline {
    return _connectivity.onConnectivityChanged.map((result) {
      return result != ConnectivityResult.none;
    });
  }
  
  Future<bool> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }
}
```

### Pattern 4: Retry with Exponential Backoff

```dart
Future<T> retryWithBackoff<T>(
  Future<T> Function() operation, {
  int maxRetries = 3,
  Duration initialDelay = const Duration(seconds: 1),
}) async {
  int attempt = 0;
  Duration delay = initialDelay;
  
  while (attempt < maxRetries) {
    try {
      return await operation();
    } catch (e) {
      attempt++;
      if (attempt >= maxRetries) rethrow;
      
      await Future.delayed(delay);
      delay *= 2; // Exponential backoff
    }
  }
  
  throw Exception('Max retries exceeded');
}
```

---

## UI States

### Loading States

Show skeleton loaders while fetching data:

```dart
FutureBuilder<List<Invoice>>(
  future: _getInvoices(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const SkeletonLoader(count: 5);
    }
    
    if (snapshot.hasError) {
      return ErrorScreen(
        error: snapshot.error.toString(),
        onRetry: () => setState(() {}),
      );
    }
    
    final invoices = snapshot.data ?? [];
    if (invoices.isEmpty) {
      return const EmptyState(
        message: 'No invoices yet',
        icon: Icons.receipt_long,
      );
    }
    
    return ListView.builder(
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        return InvoiceListItem(
          invoice: invoice,
          syncStatus: invoice.syncStatus,
        );
      },
    );
  },
);
```

### Error States

Show clear error messages with retry options:

```dart
class ErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;
  
  const ErrorScreen({
    Key? key,
    required this.error,
    this.onRetry,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Network Error',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ],
      ),
    );
  }
}
```

### Offline Banner

Show persistent banner when offline:

```dart
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ConnectivityService().isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        
        if (isOnline) return const SizedBox.shrink();
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          color: Colors.amber.shade700,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.cloud_off, size: 16, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Offline - changes will sync when connected',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

---

## Testing Offline States

### Manual Testing

#### 1. Enable Airplane Mode
- iOS: Settings → Airplane Mode
- Android: Settings → Network & Internet → Airplane Mode

#### 2. Simulate Slow Network
- Use Charles Proxy or similar tool
- Throttle bandwidth to 2G speeds (50 Kbps)
- Add random latency (500-2000ms)

#### 3. Simulate Network Errors
- Use API mocking to return errors
- Test timeout scenarios
- Test connection drops mid-request

### Test Scenarios

#### Scenario 1: Clock In Offline
1. Enable airplane mode
2. Navigate to time clock screen
3. Tap "Clock In"
4. **Expected**: 
   - Clock in appears immediately with yellow "Pending" badge
   - Item added to sync queue
   - User can continue working
5. Disable airplane mode
6. **Expected**:
   - Badge changes to green "Synced"
   - Item removed from sync queue

#### Scenario 2: View Invoices Offline
1. Load invoices while online (cache data)
2. Enable airplane mode
3. Navigate to invoices screen
4. **Expected**:
   - Cached invoices display immediately
   - Optional: Show "Last synced X minutes ago" message
   - No loading spinner

#### Scenario 3: Create Invoice Offline
1. Enable airplane mode
2. Create a new invoice
3. **Expected**:
   - Invoice saved locally with yellow badge
   - Added to sync queue
   - Can view and edit locally
4. Disable airplane mode
5. **Expected**:
   - Invoice syncs to server
   - Badge turns green
   - Server-assigned ID updates local copy

#### Scenario 4: Sync Failure
1. Queue several operations offline
2. Modify server to return 500 errors
3. Restore connectivity
4. **Expected**:
   - Operations retry automatically
   - After max retries, badges turn red "Error"
   - User can tap to manually retry
   - Error message explains the issue

#### Scenario 5: Queue Overflow
1. Queue 100+ operations while offline
2. **Expected**:
   - Warning shown at 50 items
   - Operations blocked at 100 items
   - User prompted to resolve conflicts

### Automated Tests

```dart
// test/core/services/queue_service_test.dart
void main() {
  group('QueueService', () {
    test('enqueues operations when offline', () async {
      final service = QueueService();
      
      await service.enqueue(QueueItem(
        id: '1',
        operation: 'clockIn',
        data: {'userId': 'user1'},
      ));
      
      expect(service.pendingCount, 1);
    });
    
    test('retries failed operations', () async {
      final service = QueueService();
      int attempts = 0;
      
      service.registerHandler('test', (data) async {
        attempts++;
        if (attempts < 3) throw Exception('Network error');
        return true;
      });
      
      await service.enqueue(QueueItem(
        id: '1',
        operation: 'test',
        data: {},
      ));
      
      await service.processPendingItems();
      
      expect(attempts, 3);
      expect(service.pendingCount, 0);
    });
  });
}
```

---

## Performance Considerations

### Cache Strategy

- **Time-to-Live (TTL)**: 5 minutes for most data
- **Stale-While-Revalidate**: Show cached data, update in background
- **Cache Size Limits**: 50 MB maximum local storage

### Queue Limits

- **Max Queue Size**: 100 items
- **Item Expiry**: 7 days
- **Auto-cleanup**: Run daily

### Conflict Resolution

- **Last-Write-Wins**: Default strategy
- **Optimistic Locking**: Use version field for critical data
- **User Prompt**: Show conflict resolution UI when necessary

---

## Monitoring & Debugging

### Metrics to Track

- Queue size over time
- Sync success/failure rates
- Time to sync (P50, P95, P99)
- Cache hit/miss rates
- Network request retries

### Debug Tools

```dart
// Enable verbose logging
QueueService.setLogLevel(LogLevel.verbose);

// View queue contents
final items = await QueueService().getPendingItems();
debugPrint('Pending: ${items.length}');

// Force sync
await QueueService().processPendingItems(force: true);

// Clear queue (caution!)
await QueueService().clearQueue();
```

### Logging

```dart
// Structured logging for offline operations
telemetryService.logEvent('QUEUE_ITEM_ADDED', {
  'operation': 'clockIn',
  'queueSize': queueService.pendingCount,
  'userId': userId,
});

telemetryService.logEvent('SYNC_COMPLETED', {
  'itemsSynced': syncedCount,
  'syncDuration': duration.inMilliseconds,
  'failedItems': failedCount,
});
```

---

## Best Practices

1. **Always Update Local State First**: Provide instant feedback
2. **Queue Before Attempting Network**: Even if online, queue first
3. **Provide Clear Status Indicators**: Users should know what's synced
4. **Allow Manual Retry**: Don't rely only on automatic retry
5. **Test Offline First**: Make offline the default test scenario
6. **Limit Queue Size**: Prevent unbounded growth
7. **Expire Old Items**: Don't keep stale operations indefinitely
8. **Log Everything**: Comprehensive logging helps debug sync issues

---

## Future Enhancements

- [ ] Conflict resolution UI
- [ ] Batch sync for efficiency
- [ ] Delta sync (only changed fields)
- [ ] Background sync with WorkManager
- [ ] Offline-first image handling
- [ ] Network quality indicator
- [ ] Sync settings (WiFi-only, auto-sync)

---

**Last Updated**: 2025-10-03  
**See Also**:
- `docs/ADRs/0002-offline-first-architecture.md`
- `lib/core/services/offline_service.dart`
- `lib/core/services/queue_service.dart`
- `lib/core/widgets/sync_status_chip.dart`
