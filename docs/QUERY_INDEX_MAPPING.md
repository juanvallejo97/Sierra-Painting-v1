# Query → Index → Rule Mapping

## Overview

This document maps all Firestore query patterns to their required composite indexes and security rules. Every query pattern MUST have:
1. **Query Implementation** in repository/service
2. **Composite Index** in `firestore.indexes.json`
3. **Security Rule** in `firestore.rules`
4. **Test Coverage** in `functions/src/test/rules.test.ts`

## Performance & Cost Guidelines

### Pagination Norms
- ✅ **All list queries**: Default limit of 50, max 100
- ✅ **Cursor-based pagination**: Use `startAfterDocument()` for infinite scroll
- ✅ **Cache-first**: Enable offline persistence (already enabled in `lib/core/providers/firestore_provider.dart`)
- ⚠️ **Unbounded queries**: NEVER use `.get()` without `.limit()`

### Cache Strategy
- **Offline Persistence**: Enabled with unlimited cache size
- **Stale-while-revalidate**: Use `GetOptions(source: Source.cache)` then refresh from server
- **Cache indicators**: Show UI indicator when data is from cache

---

## Time Entries Collection

Time entries are stored as subcollections under jobs: `jobs/{jobId}/timeEntries/{entryId}`

### Query Pattern 1: User's Time Entries (Basic)
**Location**: `lib/features/timeclock/data/timeclock_repository.dart::getTimeEntries()`

**Query**:
```dart
firestore
  .collectionGroup('timeEntries')
  .where('userId', isEqualTo: userId)
  .orderBy('clockIn', descending: true)
  .limit(50)
```

**Index** (`firestore.indexes.json` lines 98-109):
```json
{
  "collectionGroup": "timeEntries",
  "queryScope": "COLLECTION_GROUP",
  "fields": [
    { "fieldPath": "userId", "order": "ASCENDING" },
    { "fieldPath": "clockIn", "order": "DESCENDING" }
  ]
}
```

**Rule** (`firestore.rules` lines 113-121):
```javascript
match /jobs/{jobId}/timeEntries/{entryId} {
  allow read: if isAuthed() && 
                 (request.auth.uid == resource.data.userId || hasRole('admin'));
}
```

**Tests**: `functions/src/test/rules.test.ts::Firestore Rules - Time Entries`
- ✅ User can read their own time entries
- ✅ Admin can read any time entries in their org

---

### Query Pattern 2: User's Time Entries by Job
**Location**: `lib/features/timeclock/data/timeclock_repository.dart::getTimeEntries(jobId: jobId)`

**Query**:
```dart
firestore
  .collectionGroup('timeEntries')
  .where('userId', isEqualTo: userId)
  .where('jobId', isEqualTo: jobId)
  .orderBy('clockIn', descending: true)
  .limit(50)
```

**Index** (`firestore.indexes.json` - NEW):
```json
{
  "collectionGroup": "timeEntries",
  "queryScope": "COLLECTION_GROUP",
  "fields": [
    { "fieldPath": "userId", "order": "ASCENDING" },
    { "fieldPath": "jobId", "order": "ASCENDING" },
    { "fieldPath": "clockIn", "order": "DESCENDING" }
  ]
}
```

**Rule**: Same as Query Pattern 1

**Tests**: Same test coverage as Query Pattern 1

**Cost**: Lower than Pattern 1 due to job filter reducing result set

---

### Query Pattern 3: Active Time Entries (Open Clock-ins)
**Location**: `lib/features/timeclock/data/timeclock_repository.dart::getActiveEntries()`

**Query**:
```dart
firestore
  .collectionGroup('timeEntries')
  .where('userId', isEqualTo: userId)
  .where('clockOut', isEqualTo: null)
  .limit(10)
```

**Index** (`firestore.indexes.json` - NEW):
```json
{
  "collectionGroup": "timeEntries",
  "queryScope": "COLLECTION_GROUP",
  "fields": [
    { "fieldPath": "userId", "order": "ASCENDING" },
    { "fieldPath": "clockOut", "order": "ASCENDING" }
  ]
}
```

**Rule**: Same as Query Pattern 1

**Tests**: Same test coverage as Query Pattern 1

**Cost**: Very low - typically returns 0-1 documents per user

---

### Query Pattern 4: Organization Time Entries
**Location**: `lib/features/timeclock/data/timeclock_repository.dart` (via orgId filter)

**Query**:
```dart
firestore
  .collectionGroup('timeEntries')
  .where('orgId', isEqualTo: orgId)
  .where('userId', isEqualTo: userId)
  .orderBy('clockIn', descending: true)
  .limit(50)
```

**Index** (`firestore.indexes.json` lines 39-46):
```json
{
  "collectionGroup": "timeEntries",
  "queryScope": "COLLECTION_GROUP",
  "fields": [
    { "fieldPath": "orgId", "order": "ASCENDING" },
    { "fieldPath": "userId", "order": "ASCENDING" },
    { "fieldPath": "clockIn", "order": "DESCENDING" }
  ]
}
```

**Rule**: Organization scoping enforced via custom claims

**Tests**: Covered by org-scoping tests

---

## Jobs Collection

### Query Pattern 5: Jobs by Organization and Schedule
**Location**: Jobs list screen (future implementation)

**Query**:
```dart
firestore
  .collection('jobs')
  .where('orgId', isEqualTo: orgId)
  .orderBy('scheduledDate', ascending: true)
  .limit(50)
```

**Index** (`firestore.indexes.json` lines 22-28):
```json
{
  "collectionGroup": "jobs",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "orgId", "order": "ASCENDING" },
    { "fieldPath": "scheduledDate", "order": "ASCENDING" }
  ]
}
```

**Rule** (`firestore.rules` lines 91-111):
```javascript
match /jobs/{jobId} {
  allow read: if isAuthed() && 
                 (hasRole('admin') || 
                  (resource.data.orgId != null && inOrg(resource.data.orgId)) ||
                  isJobOwner(resource.data));
}
```

**Tests**: `functions/src/test/rules.test.ts::Firestore Rules - Jobs Collection`
- ✅ User in same org can read job
- ✅ User in different org cannot read job

---

## Invoices Collection

### Query Pattern 6: Invoices by Organization and Status
**Location**: `lib/features/invoices/presentation/invoices_screen.dart` (TODO)

**Query**:
```dart
firestore
  .collection('invoices')
  .where('orgId', isEqualTo: orgId)
  .where('status', isEqualTo: status)
  .orderBy('createdAt', descending: true)
  .limit(50)
```

**Index** (`firestore.indexes.json` lines 3-11):
```json
{
  "collectionGroup": "invoices",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "orgId", "order": "ASCENDING" },
    { "fieldPath": "status", "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "DESCENDING" }
  ]
}
```

**Rule** (`firestore.rules` lines 143-152):
```javascript
match /invoices/{invoiceId} {
  allow read: if isAuthed() && 
                 (hasRole('admin') || request.auth.uid == resource.data.userId);
}
```

**Tests**: Not yet implemented - TODO

---

### Query Pattern 7: Unpaid Invoices by Due Date
**Location**: Dashboard (future implementation)

**Query**:
```dart
firestore
  .collection('invoices')
  .where('orgId', isEqualTo: orgId)
  .where('paid', isEqualTo: false)
  .orderBy('dueDate', ascending: true)
  .limit(50)
```

**Index** (`firestore.indexes.json` lines 29-37):
```json
{
  "collectionGroup": "invoices",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "orgId", "order": "ASCENDING" },
    { "fieldPath": "paid", "order": "ASCENDING" },
    { "fieldPath": "dueDate", "order": "ASCENDING" }
  ]
}
```

**Rule**: Same as Query Pattern 6

**Tests**: Not yet implemented - TODO

---

## Estimates Collection

### Query Pattern 8: Estimates by Organization and Status
**Location**: `lib/features/estimates/presentation/estimates_screen.dart` (TODO)

**Query**:
```dart
firestore
  .collection('estimates')
  .where('orgId', isEqualTo: orgId)
  .where('status', isEqualTo: status)
  .orderBy('createdAt', descending: true)
  .limit(50)
```

**Index** (`firestore.indexes.json` lines 12-20):
```json
{
  "collectionGroup": "estimates",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "orgId", "order": "ASCENDING" },
    { "fieldPath": "status", "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "DESCENDING" }
  ]
}
```

**Rule** (`firestore.rules` lines 154-161):
```javascript
match /estimates/{estimateId} {
  allow read: if isAuthed() && 
                 (hasRole('admin') || 
                  (resource.data.orgId != null && inOrg(resource.data.orgId)));
}
```

**Tests**: Not yet implemented - TODO

---

## Audit Logs Collection

### Query Pattern 9: Audit Logs by Organization
**Location**: Admin dashboard (future implementation)

**Query**:
```dart
firestore
  .collection('audit_logs')
  .where('orgId', isEqualTo: orgId)
  .orderBy('timestamp', descending: true)
  .limit(100)  // Higher limit for admin
```

**Index** (`firestore.indexes.json` lines 80-87):
```json
{
  "collectionGroup": "audit_logs",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "orgId", "order": "ASCENDING" },
    { "fieldPath": "timestamp", "order": "DESCENDING" }
  ]
}
```

**Rule** (`firestore.rules` lines 169-173):
```javascript
match /activity_logs/{logId} {
  allow read: if hasRole('admin');
  allow write: if false;
}
```

**Tests**: Not yet implemented - TODO

---

## CI Gates & Monitoring

### Automated Checks

1. **Rules Tests** (`.github/workflows/firestore_rules.yml`)
   - ✅ Runs on every PR touching rules
   - ✅ Uses Firebase emulator
   - ✅ Currently 29 tests covering query patterns

2. **Index Coverage** (TODO)
   - ⚠️ Script to extract queries from Dart code
   - ⚠️ Verify index exists for each query
   - ⚠️ Fail CI if missing index detected

3. **Query Cost Monitoring** (TODO)
   - ⚠️ Track document reads per operation
   - ⚠️ Alert on >20% cost increase
   - ⚠️ Use Firebase Performance Monitoring

### Future Enhancements

- [ ] Automated index generation from emulator query logs
- [ ] Per-collection cost snapshots in CI
- [ ] Query plan validation in tests
- [ ] Hot collection sharding strategy (hashed doc IDs)

---

## Best Practices

### DO ✅
- Always use `.limit()` on queries
- Use cursor-based pagination with `startAfterDocument()`
- Add indexes before deploying queries
- Test rules with unit tests
- Monitor query costs in production
- Use `GetOptions(source: Source.cache)` for stale-while-revalidate

### DON'T ❌
- Never use `.get()` without `.limit()`
- Don't add indexes without testing
- Don't skip security rules tests
- Don't use real-time listeners for static data
- Don't exceed 100 document reads per user action

---

## Related Documentation

- [Firestore Performance Playbook](./perf-playbook-fe.md)
- [Performance Implementation Guide](./PERFORMANCE_IMPLEMENTATION.md)
- [Security Rules Documentation](./Security.md)
- [Testing Guide](./Testing.md)

---

**Last Updated**: 2024  
**Version**: 1.0  
**Owner**: Engineering Team
