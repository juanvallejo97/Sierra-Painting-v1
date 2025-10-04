# Database Guide — Sierra Painting

> **Purpose**: Firestore schema, indexes, migrations, and optimization  
> **Last Updated**: 2024  
> **Status**: Production-Ready

---

## Table of Contents

1. [Overview](#overview)
2. [Schema](#schema)
3. [Composite Indexes](#composite-indexes)
4. [Query Patterns](#query-patterns)
5. [Migration Strategy](#migration-strategy)
6. [Optimization Guidelines](#optimization-guidelines)
7. [Backup & Restore](#backup--restore)

---

## Overview

Sierra Painting uses **Cloud Firestore** as its primary database with the following principles:

- **Deny-by-default security rules** with explicit grants
- **Composite indexes** for all query patterns
- **Reversible migrations** with three-phase deployment
- **Pagination everywhere** (no unbounded queries)
- **Stale-while-revalidate caching** for performance

---

## Schema

### Collections

#### `/users/{userId}`

User profile and authentication metadata.

```typescript
{
  uid: string;                  // Firebase Auth UID
  email: string;                // Email address
  displayName: string;          // Full name
  role: 'admin' | 'crew_lead' | 'crew';  // RBAC role
  orgId: string;                // Organization ID
  photoUrl?: string;            // Profile photo URL
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

**Security**: Users can read/write own profile; admins can read all profiles; role changes require admin

---

#### `/jobs/{jobId}`

Project/job tracking.

```typescript
{
  orgId: string;                // Organization ID (required)
  ownerId: string;              // User who created job
  title: string;
  description: string;
  status: 'pending' | 'in_progress' | 'completed' | 'cancelled';
  clientName: string;
  address: string;
  estimatedHours?: number;
  actualHours?: number;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

**Security**: Org members can read; owner/admin can write

---

#### `/jobs/{jobId}/timeEntries/{entryId}`

Time tracking for crew members.

```typescript
{
  userId: string;               // Crew member UID
  jobId: string;                // Parent job ID
  orgId: string;                // Organization ID
  clockIn: Timestamp;           // Start time
  clockOut: Timestamp | null;   // End time (null if active)
  hoursWorked?: number;         // Calculated hours
  notes?: string;
  createdAt: Timestamp;
}
```

**Security**: Users can create own entries; cannot update/delete (server-only); org scoping enforced

---

#### `/estimates/{estimateId}`

Quote/estimate documents.

```typescript
{
  orgId: string;
  jobId: string;
  title: string;
  lineItems: Array<{
    description: string;
    quantity: number;
    unitPrice: number;
    total: number;
  }>;
  subtotal: number;
  tax: number;
  total: number;
  status: 'draft' | 'sent' | 'approved' | 'rejected';
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

**Security**: Org members can read; admin/crew_lead can create/update

---

#### `/invoices/{invoiceId}`

Billing documents.

```typescript
{
  orgId: string;
  jobId: string;
  estimateId?: string;
  invoiceNumber: string;        // Sequential number
  lineItems: Array<{
    description: string;
    quantity: number;
    unitPrice: number;
    total: number;
  }>;
  subtotal: number;
  tax: number;
  total: number;
  paid: boolean;                // Server-only field
  paidAt: Timestamp | null;     // Server-only field
  paymentMethod?: 'cash' | 'check' | 'stripe';
  status: 'draft' | 'sent' | 'paid' | 'overdue';
  dueDate: Timestamp;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

**Security**: Org members can read; admin can create/update; `paid` and `paidAt` are server-only (callable function)

---

#### `/payments/{paymentId}`

Payment transaction records.

```typescript
{
  orgId: string;
  invoiceId: string;
  amount: number;
  method: 'cash' | 'check' | 'stripe';
  stripePaymentIntentId?: string;
  checkNumber?: string;
  notes?: string;
  processedBy: string;          // Admin UID
  createdAt: Timestamp;
}
```

**Security**: Server-only creation (callable function); admins can read org payments

---

#### `/leads/{leadId}`

Lead generation from website forms.

```typescript
{
  orgId: string;
  name: string;
  email: string;
  phone: string;
  message: string;
  status: 'new' | 'contacted' | 'qualified' | 'converted' | 'rejected';
  source: 'website' | 'referral' | 'other';
  createdAt: Timestamp;
  convertedToJobId?: string;
}
```

**Security**: Server-only creation (callable function); admins can read/update org leads

---

#### `/audit_logs/{logId}`

Immutable audit trail for sensitive operations.

```typescript
{
  orgId: string;
  userId: string;               // Actor
  action: string;               // e.g., 'mark_invoice_paid', 'create_payment'
  entityType: string;           // e.g., 'invoice', 'payment'
  entityId: string;
  details: Record<string, any>;
  ipAddress?: string;
  userAgent?: string;
  createdAt: Timestamp;
}
```

**Security**: Server-only writes; admins can read org audit logs

---

## Composite Indexes

All query patterns are covered by composite indexes in `firestore.indexes.json`.

### Index List

| Collection | Fields | Purpose |
|------------|--------|---------|
| `jobs` | `orgId ASC, status ASC, createdAt DESC` | List org jobs by status |
| `jobs` | `orgId ASC, ownerId ASC, createdAt DESC` | List user's jobs |
| `timeEntries` | `userId ASC, jobId ASC, clockIn DESC` | Get user's time entries for job |
| `timeEntries` | `userId ASC, clockOut ASC` | Get active entries (clockOut == null) |
| `timeEntries` | `orgId ASC, jobId ASC, clockIn DESC` | Get all time entries for job |
| `estimates` | `orgId ASC, status ASC, createdAt DESC` | List estimates by status |
| `estimates` | `orgId ASC, jobId ASC, createdAt DESC` | List estimates for job |
| `invoices` | `orgId ASC, status ASC, dueDate ASC` | List invoices by status and due date |
| `invoices` | `orgId ASC, jobId ASC, createdAt DESC` | List invoices for job |
| `invoices` | `orgId ASC, paid ASC, dueDate ASC` | List unpaid invoices |
| `payments` | `orgId ASC, invoiceId ASC, createdAt DESC` | List payments for invoice |
| `payments` | `orgId ASC, createdAt DESC` | List all org payments |
| `leads` | `orgId ASC, status ASC, createdAt DESC` | List leads by status |
| `leads` | `orgId ASC, createdAt DESC` | List all org leads |
| `audit_logs` | `orgId ASC, entityType ASC, createdAt DESC` | Query audit logs by entity |
| `audit_logs` | `orgId ASC, userId ASC, createdAt DESC` | Query audit logs by user |

### Deploying Indexes

```bash
# Preview indexes
firebase deploy --only firestore:indexes --project sierra-painting-staging --dry-run

# Deploy to staging
firebase deploy --only firestore:indexes --project sierra-painting-staging

# Deploy to production
firebase deploy --only firestore:indexes --project sierra-painting-prod
```

**Note**: Index creation can take several minutes depending on collection size.

---

## Query Patterns

### Pagination Best Practices

**All queries MUST have pagination** to prevent unbounded reads.

```dart
// Good: Explicit limit
final jobs = await db
  .collection('jobs')
  .where('orgId', isEqualTo: orgId)
  .orderBy('createdAt', descending: true)
  .limit(50)  // Always set limit
  .get();

// Bad: Unbounded query (expensive!)
final jobs = await db
  .collection('jobs')
  .where('orgId', isEqualTo: orgId)
  .get();  // ❌ No limit
```

**Cursor-based pagination** for next page:

```dart
DocumentSnapshot? lastDoc;

// First page
final firstPage = await query.limit(50).get();
lastDoc = firstPage.docs.last;

// Next page
final nextPage = await query
  .startAfterDocument(lastDoc!)
  .limit(50)
  .get();
```

**Pagination limits**:
- Default: 50 documents
- Maximum: 100 documents
- For large datasets, use cursor pagination

---

### Caching Strategy

**Stale-while-revalidate pattern** for optimal UX:

```dart
// 1. Show cached data immediately
final cachedSnapshot = await query.get(GetOptions(source: Source.cache));
setState(() => data = cachedSnapshot.docs);

// 2. Fetch fresh data in background
final freshSnapshot = await query.get(GetOptions(source: Source.server));
setState(() => data = freshSnapshot.docs);
```

**Cache settings** (already configured):
- Offline persistence: Enabled
- Cache size: Unlimited
- Sync: Real-time listeners for critical data

**UI indicators**:
- Show "Syncing..." badge during background refresh
- Show "Offline" banner when network unavailable

---

## Migration Strategy

### Three-Phase Deployment

All schema changes follow a **reversible three-phase pattern**:

#### Phase 1: Expand (Add New)
- Add new fields/collections
- Keep old fields intact
- New code writes to **both** old and new
- Deploy and verify

#### Phase 2: Backfill (Migrate Data)
- Run backfill script to populate new fields
- Verify data integrity
- Monitor performance impact

#### Phase 3: Contract (Remove Old)
- Update code to only use new fields
- Deploy and verify
- Remove old fields (optional cleanup)

**Rollback support**:
- Phase 1: Revert code, remove new fields
- Phase 2: New fields remain but unused
- Phase 3: Restore code to use old fields

---

### Example: Renaming a Field

**Phase 1: Add New Field**
```typescript
interface Job {
  oldName: string;
  newName?: string;  // Optional
}

// Write to both
await jobRef.update({
  oldName: value,
  newName: value
});
```

**Phase 2: Backfill**
```typescript
// Backfill script
const jobs = await db.collection('jobs')
  .where('newName', '==', null)
  .limit(500)
  .get();

const batch = db.batch();
jobs.docs.forEach(doc => {
  batch.update(doc.ref, {
    newName: doc.data().oldName
  });
});
await batch.commit();
```

**Phase 3: Remove Old Field**
```typescript
interface Job {
  newName: string;  // Required
}

// Only write to newName
await jobRef.update({
  newName: value
});
```

---

### Migration Checklist

Before running any migration:

- [ ] Migration follows three-phase pattern
- [ ] Backfill script written and tested (dry-run)
- [ ] Rollback procedure documented
- [ ] Indexes created for new fields (if needed)
- [ ] Performance impact estimated
- [ ] Backups verified and tested
- [ ] Team notified of migration schedule

During migration:

- [ ] Run backfill script in dry-run mode
- [ ] Verify dry-run results
- [ ] Run backfill in production (small batch first)
- [ ] Monitor Firestore metrics
- [ ] Verify data integrity
- [ ] Check application performance

After migration:

- [ ] Verify all documents processed
- [ ] Run smoke tests
- [ ] Monitor for 24 hours
- [ ] Document any issues encountered
- [ ] Schedule cleanup (remove old fields) if applicable

---

## Optimization Guidelines

### 1. Avoid N+1 Queries

**Bad**: Query in loop
```dart
// ❌ N+1 problem
for (final jobId in jobIds) {
  final job = await db.collection('jobs').doc(jobId).get();
}
```

**Good**: Batch read or denormalize
```dart
// ✅ Batch read (up to 10 docs)
final jobs = await db.getAll(jobRefs);

// ✅ Or denormalize: store job title in invoice
```

---

### 2. Use Listeners Sparingly

**Real-time listeners** are expensive. Use for:
- Active time entries (clock in/out screen)
- Dashboard metrics
- Chat/notifications

**Avoid** listeners for:
- Historical data (estimates, invoices)
- Static lists
- Search results

---

### 3. Index Every Query

**Rule**: If you query it, index it.

Running a query without an index will **fail in production** (or be very slow).

Use Firebase Console to auto-generate indexes during development, then copy to `firestore.indexes.json`.

---

### 4. Monitor Read/Write Costs

Check Firebase Console regularly:
- **Reads**: Should be mostly cached (< 50% server reads)
- **Writes**: Optimize batch writes where possible
- **Deletes**: Use batched deletes for bulk operations

**Cost thresholds**:
- < 100K reads/day: Normal
- 100K-500K reads/day: Monitor
- > 500K reads/day: Optimize (check for unbounded queries)

---

## Backup & Restore

### Automated Backups

Firestore backups are managed via Firebase Console (manual) or gcloud (automated).

**Manual backup** (via Console):
1. Firebase Console → Firestore → Backups
2. Create backup
3. Store backup location

**Automated backup** (recommended):
```bash
# Schedule daily backups (Cloud Scheduler + Cloud Function)
gcloud firestore operations describe \
  --project=sierra-painting-prod \
  --operation-id=OPERATION_ID
```

---

### Restore Procedures

**Option 1: Full Restore** (disaster recovery)
```bash
# Restore from backup
gcloud firestore import gs://BACKUP_BUCKET/BACKUP_FOLDER \
  --project=sierra-painting-prod
```

**Option 2: Selective Restore** (specific documents)
```bash
# Export specific collection
gcloud firestore export gs://EXPORT_BUCKET \
  --collection-ids=jobs,invoices \
  --project=sierra-painting-prod

# Import to temp collection for review
# Manually copy documents back
```

---

### Backup Testing

Test restore procedure quarterly:
- [ ] Create test Firebase project
- [ ] Export production data (anonymized)
- [ ] Import to test project
- [ ] Verify data integrity
- [ ] Document restore time

---

## Related Documentation

- [ARCHITECTURE.md](./ARCHITECTURE.md) - Overall system architecture
- [SECURITY.md](./SECURITY.md) - Firestore security rules
- [DEPLOYMENT.md](./DEPLOYMENT.md) - Deployment procedures
- [docs/QUERY_INDEX_MAPPING.md](./QUERY_INDEX_MAPPING.md) - Query-to-index mapping

---

## Support

For database issues:
1. Check this guide and query mapping docs
2. Review Firestore Console metrics
3. Run rules tests: `cd firestore-tests && npm test`
4. Check audit logs for recent changes
5. Contact team lead if unresolved

---

**Last Updated**: 2024  
**Owner**: Engineering Team  
**Review Schedule**: Quarterly
