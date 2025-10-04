# ADR-0002: Offline-First Architecture

**Status:** Accepted  
**Date:** 2025-01-15  
**Deciders:** Engineering Team  
**Tags:** architecture, offline, sync, mobile  
**Context:** Need to support field workers with unreliable connectivity

---

## Context and Problem Statement

Field workers (painters, estimators) often work in locations with poor or no internet connectivity (basements, job sites, rural areas). The application must function seamlessly offline and sync data when connectivity is restored.

**Requirements:**
- Workers must be able to clock in/out offline
- Invoices and estimates must be viewable offline
- Changes made offline must sync automatically when online
- Prevent data loss during network interruptions
- Provide clear feedback on sync status

## Decision Drivers

- Reliability in areas with poor connectivity
- User experience continuity (no disruptions)
- Data integrity and consistency
- Conflict resolution strategy
- Prevent duplicate operations during sync

## Considered Options

1. **Offline-first with local queue** (**selected**)
2. Online-only with graceful degradation
3. Hybrid: read offline, write online-only

---

## Decision Outcome

**Chosen option:** **Offline-first with local queue**

### Implementation Strategy

**Local Storage:**
- **Hive** for offline queue (pending operations)
- **Firestore offline persistence** for cached reads
- Store queue items with metadata: `clientId`, `timestamp`, `processed`, `retryCount`

**Queue Processing:**
1. User performs action (clock-in, create invoice) → saved to local queue
2. Queue service monitors network status
3. When online, queue items processed sequentially
4. Successful operations marked as `processed: true`
5. Failed operations retained with retry logic (exponential backoff)

**Idempotency:**
- Every operation generates a unique `clientId` (UUID)
- Server checks for duplicate `clientId` before processing
- If duplicate found, return cached result (idempotency collection)
- Prevents duplicate entries from multiple sync attempts

**Conflict Resolution:**
- **Strategy:** Last-write-wins with timestamp comparison
- Server compares client timestamp with server timestamp
- If conflict detected (stale data), reject with 409 status
- Client shows conflict resolution UI for manual merge

**Sync Status Indicators:**
- Yellow chip: pending sync
- Green checkmark: synced successfully
- Red icon: sync failed (tap to retry)
- Global sync indicator in app bar

---

## Pros and Cons Summary

**Pros**
- ✅ Works reliably in areas with no connectivity
- ✅ Seamless user experience (no "No Internet" errors)
- ✅ Automatic sync when network restored
- ✅ Prevents data loss
- ✅ Clear visibility into sync status

**Cons**
- ⚠️ Increased complexity (queue management, conflict resolution)
- ⚠️ Potential for stale data if offline for extended periods
- ⚠️ Storage overhead for queue items
- ⚠️ Need to handle queue size limits

---

## Consequences

**Positive**
1. Improved reliability for field workers
2. Better user experience (no interruptions)
3. Higher data capture rate (nothing lost due to connectivity)
4. Competitive advantage (many apps fail offline)

**Negative & Mitigations**
1. **Unbounded queue growth** → Limit queue to 100 items, auto-expire after 7 days
2. **Stale data conflicts** → Optimistic locking with version field, conflict UI
3. **Complex debugging** → Comprehensive logging, queue status dashboard
4. **Storage limits** → Monitor queue size, warn user when > 50 items

---

## Risks

### RISK-OFF-001: Unbounded Queue Growth
**Severity:** Medium  
**Mitigation:**
- Max queue size: 100 items
- Show warning when > 50 items
- Auto-expire items older than 7 days
- Add queue cleanup job

### RISK-OFF-002: Stale Data Conflicts
**Severity:** High  
**Mitigation:**
- Implement optimistic locking (version field)
- Detect conflicts on sync
- Show conflict resolution UI
- Default to last-write-wins with warning

### RISK-OFF-003: Offline Login Failures
**Severity:** Medium  
**Mitigation:**
- Cache Firebase Auth token securely
- Allow offline login with cached token (expires 1 hour)
- Show clear error if token expired

---

## Implementation Notes

### Queue Service API

```dart
// lib/core/services/queue_service.dart
class QueueService {
  Future<void> addToQueue(QueueItem item);
  List<QueueItem> getPendingItems();
  Future<void> markAsProcessed(int index);
  Future<void> removeItem(int index);
  Future<void> retryFailed();
  Future<void> clearOldItems(Duration age);
}
```

### Queue Item Model

```dart
// lib/core/models/queue_item.dart
@HiveType(typeId: 0)
class QueueItem extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String clientId;  // UUID for idempotency
  @HiveField(2) String operationType; // 'clockIn', 'createInvoice', etc.
  @HiveField(3) Map<String, dynamic> payload;
  @HiveField(4) DateTime timestamp;
  @HiveField(5) bool processed;
  @HiveField(6) int retryCount;
  @HiveField(7) String? error;
}
```

### Server-side Idempotency

```typescript
// functions/src/lib/idempotency.ts
export async function checkIdempotency(
  clientId: string,
  operation: string
): Promise<{ isDuplicate: boolean; result?: any }> {
  const idempotencyDoc = await db
    .collection('idempotency')
    .doc(clientId)
    .get();
  
  if (idempotencyDoc.exists) {
    return { isDuplicate: true, result: idempotencyDoc.data() };
  }
  
  return { isDuplicate: false };
}

export async function storeIdempotencyResult(
  clientId: string,
  operation: string,
  result: any,
  ttlHours: number = 24
): Promise<void> {
  const expiresAt = new Date(Date.now() + ttlHours * 60 * 60 * 1000);
  
  await db.collection('idempotency').doc(clientId).set({
    operation,
    result,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt,
  });
}
```

### Network Status Monitoring

```dart
// lib/core/services/network_service.dart
class NetworkService {
  Stream<bool> get isOnline => 
    Connectivity().onConnectivityChanged.map((result) => 
      result != ConnectivityResult.none
    );
  
  Future<void> processQueueWhenOnline() async {
    await for (final online in isOnline) {
      if (online) {
        await _processQueue();
      }
    }
  }
}
```

---

## Alternatives Considered

### 1. Online-only with graceful degradation
**Pros:** Simpler implementation, no sync complexity  
**Cons:** Unusable offline, poor UX for field workers  
**Why not chosen:** Core requirement is offline support

### 2. Hybrid: read offline, write online-only
**Pros:** Simpler than full offline-first  
**Cons:** Can't record time entries or create records offline  
**Why not chosen:** Workers need to perform critical actions offline

---

## Related Decisions

- ADR-0001: Technology Stack Selection (Flutter + Firebase)
- ADR-0006: Idempotency Strategy (client-side UUID generation)

## References

- [Firestore Offline Persistence](https://firebase.google.com/docs/firestore/manage-data/enable-offline)
- [Hive Documentation](https://docs.hivedb.dev/)
- [Idempotency Patterns](https://brandur.org/idempotency-keys)
- [Offline-First Apps](https://offlinefirst.org/)

## Superseded By

None (current decision)

---

> **Note:** ADRs are immutable. Revisions require a new ADR that supersedes this one.
