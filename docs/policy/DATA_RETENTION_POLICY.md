# Data Retention Policy

**Version:** 1.0
**Effective Date:** 2025-10-12
**Last Updated:** 2025-10-12
**Owner:** Engineering & Compliance
**Review Cycle:** Annual

---

## Purpose

This document defines the data retention and deletion policies for the Sierra Painting application. It ensures compliance with legal requirements (GDPR, CCPA, SOX) while maintaining operational efficiency and security.

---

## Scope

This policy applies to all data stored in:
- Firestore database (primary data store)
- Cloud Storage (files, PDFs, images)
- Cloud Functions logs
- Firebase Analytics
- Audit logs

---

## Retention Periods

### Critical Business Records

**Retention: 7 years from creation**

Required for tax audits, labor law compliance, and legal disputes.

| Collection | Description | Retention Period | Deletion Trigger |
|------------|-------------|------------------|------------------|
| `time_entries` | Worker clock in/out records | 7 years | Auto-delete after 7 years |
| `invoices` | Customer billing records | 7 years | Auto-delete after 7 years |
| `customers` | Customer contact & billing info | 7 years from last activity | Manual archive, then auto-delete |
| `jobs` | Job site details & history | 7 years from completion | Auto-delete after 7 years |
| `estimates` | Quote/estimate history | 7 years | Auto-delete after 7 years |
| `auditLog` | Security & compliance audit trail | 7 years | Auto-delete after 7 years |

**Legal Basis:**
- IRS: 7-year retention for employment tax records (Form 941, W-2, etc.)
- Fair Labor Standards Act (FLSA): 3-year minimum for payroll records
- SOX: 7-year retention for financial records
- GDPR/CCPA: Lawful basis for legitimate business interests

---

### Operational Data

**Retention: 90 days from creation**

Short-term operational data with no legal retention requirements.

| Collection | Description | Retention Period | Deletion Trigger |
|------------|-------------|------------------|------------------|
| `rateLimits` | Rate limiting counters | 24 hours | Auto-expire via Firestore TTL |
| `assignments` | Current worker job assignments | Until job completion + 90 days | Auto-delete |
| `companies` | Active company profiles | While account active | Soft-delete on cancellation |
| `users` | User profiles & preferences | While account active | Soft-delete on account closure |

**Legal Basis:**
- Operational necessity
- User consent (account creation)

---

### Transient Data

**Retention: 24 hours from creation**

Temporary data for anti-abuse and debugging.

| Collection | Description | Retention Period | Deletion Trigger |
|------------|-------------|------------------|------------------|
| `rateLimits` | IP-based rate limit counters | 24 hours | Firestore TTL (`expiresAt` field) |
| `idempotencyKeys` | Duplicate request prevention | 24 hours | Firestore TTL |

---

### Logs & Telemetry

**Retention: 30 days from creation**

| Data Type | Location | Retention Period | Deletion Trigger |
|-----------|----------|------------------|------------------|
| Cloud Functions logs | Cloud Logging | 30 days | Auto-delete by GCP |
| Analytics events | Firebase Analytics | 14 months | Auto-delete by Firebase |
| Performance traces | Firebase Performance | 90 days | Auto-delete by Firebase |
| Crash reports | Crashlytics | 90 days | Auto-delete by Firebase |

**Legal Basis:**
- Debugging & operational monitoring
- GDPR Article 6(1)(f): Legitimate interests

---

## Data Deletion Methods

### 1. Firestore TTL (Automatic)

**Collections:** `rateLimits`, `idempotencyKeys`

**Implementation:**
```typescript
// Document structure with TTL
{
  operation: 'clockIn',
  count: 3,
  windowStart: Timestamp,
  expiresAt: Timestamp // Auto-deleted when this passes
}
```

**Firestore TTL Policy:**
```bash
# Enable TTL on collections
gcloud firestore databases update --project=sierra-painting-prod \
  --delete-ttl-enabled \
  --delete-ttl-field=expiresAt
```

**Status:** ⚠️ **NOT YET IMPLEMENTED** - Requires Firestore TTL policy configuration

---

### 2. Scheduled Cloud Function (Auto-Archive)

**Collections:** `time_entries`, `invoices`, `jobs`, `estimates`, `auditLog`

**Schedule:** Daily at 2 AM UTC

**Implementation:**
```typescript
// functions/src/scheduled/data_retention.ts
export const dailyDataArchival = onSchedule({
  schedule: 'every day 02:00',
  timeZone: 'UTC',
  region: 'us-east4',
}, async () => {
  const db = admin.firestore();
  const sevenYearsAgo = new Date();
  sevenYearsAgo.setFullYear(sevenYearsAgo.getFullYear() - 7);

  // Archive time_entries older than 7 years
  const oldEntries = await db.collection('time_entries')
    .where('createdAt', '<', sevenYearsAgo)
    .limit(500) // Batch size
    .get();

  // Move to archive bucket (Cloud Storage)
  // Then delete from Firestore
  for (const doc of oldEntries.docs) {
    await archiveToStorage('time_entries', doc.id, doc.data());
    await doc.ref.delete();
  }
});
```

**Status:** ⚠️ **NOT YET IMPLEMENTED** - Requires scheduled function creation

---

### 3. Soft Delete (User-Initiated)

**Collections:** `companies`, `users`, `customers`

**Process:**
1. Mark record with `deletedAt` timestamp
2. Hide from queries (add `where('deletedAt', '==', null)` to all queries)
3. Auto-delete after 30-day grace period

**Implementation:**
```typescript
// Soft delete
await db.collection('users').doc(userId).update({
  deletedAt: admin.firestore.FieldValue.serverTimestamp(),
  active: false,
});

// Permanent delete (after grace period)
const softDeleted = await db.collection('users')
  .where('deletedAt', '<', thirtyDaysAgo)
  .get();

for (const doc of softDeleted.docs) {
  await doc.ref.delete();
}
```

**Status:** ⚠️ **NOT YET IMPLEMENTED** - Requires soft-delete logic in app

---

## Deletion Safeguards

### 1. Two-Stage Deletion

All critical business records use two-stage deletion:

**Stage 1: Archive (Move to Cold Storage)**
- Data moved to Cloud Storage (lower cost)
- Indexed metadata retained in Firestore
- Searchable for legal/compliance needs

**Stage 2: Permanent Deletion (After retention period)**
- Cloud Storage objects deleted
- Metadata deleted from Firestore
- Irreversible

### 2. Deletion Audit Log

All deletions logged to `deletionAuditLog` collection:

```typescript
{
  collection: 'time_entries',
  documentId: 'entry-123',
  deletedAt: Timestamp,
  deletedBy: 'system' | userId,
  reason: 'retention_policy' | 'user_request' | 'admin_action',
  originalCreatedAt: Timestamp,
  dataHash: 'sha256-hash', // For verification
}
```

Retention: 10 years (longer than data itself for audit purposes)

### 3. Legal Hold

When legal hold is required (litigation, investigation):

```typescript
await db.collection('time_entries').doc(entryId).update({
  legalHold: true,
  legalHoldReason: 'Litigation: Case #12345',
  legalHoldBy: 'legal@company.com',
  legalHoldAt: Timestamp,
});
```

Documents with `legalHold: true` are **excluded from auto-deletion**.

---

## User Rights (GDPR/CCPA)

### Right to Erasure ("Right to be Forgotten")

**Scope:**
- User can request deletion of personal data
- Company must comply within 30 days

**Exceptions (data not deleted):**
- Time entries (7-year legal retention for tax/labor law)
- Invoices/billing records (7-year legal retention)
- Audit logs (compliance requirement)

**Implementation:**
1. User submits deletion request via support
2. Admin reviews request (legal team approval if needed)
3. Soft-delete user profile, customer contact info
4. Pseudonymize time entries (replace name with hash, retain hours/dates)
5. Send confirmation email to user

**Status:** ⚠️ **NOT YET IMPLEMENTED** - Requires user deletion workflow

---

### Right to Access ("Data Portability")

**Scope:**
- User can request copy of all their personal data
- Must be provided in machine-readable format (JSON/CSV)

**Implementation:**
```typescript
export const exportUserData = onCall(async (req) => {
  const userId = req.auth.uid;

  const userData = {
    profile: await getDocument('users', userId),
    timeEntries: await getCollection('time_entries', { userId }),
    invoices: await getCollection('invoices', { userId }),
  };

  // Upload to Cloud Storage with signed URL
  const exportUrl = await uploadExport(userId, userData);

  return { downloadUrl: exportUrl, expiresAt: oneDayFromNow };
});
```

**Status:** ⚠️ **NOT YET IMPLEMENTED** - Requires export function

---

## Implementation Checklist

### Phase 1: Immediate (Before Production)
- [x] Document retention policy (this file)
- [ ] Configure Firestore TTL for `rateLimits` collection
- [ ] Add `expiresAt` field to all rate limit writes
- [ ] Test TTL auto-deletion in staging

### Phase 2: Within 30 Days
- [ ] Implement `dailyDataArchival` scheduled function
- [ ] Create Cloud Storage archive bucket
- [ ] Add soft-delete logic for users/companies
- [ ] Create `deletionAuditLog` collection
- [ ] Test archival process in staging

### Phase 3: Within 90 Days
- [ ] Implement user data export function
- [ ] Implement user deletion request workflow
- [ ] Add legal hold functionality
- [ ] Create retention policy dashboard (admin view)
- [ ] Compliance training for staff

---

## Monitoring & Alerts

### Key Metrics

1. **Storage Growth Rate**
   - Alert if > 10% growth per week (indicates retention not working)

2. **Deletion Success Rate**
   - Alert if < 95% (indicates function failures)

3. **Legal Hold Count**
   - Review monthly (ensure holds are released when no longer needed)

### Dashboard

Create Cloud Monitoring dashboard with:
- Total documents per collection
- Documents eligible for deletion (age > retention period)
- Failed deletion attempts (last 7 days)
- Legal hold count by collection

---

## Review & Updates

**Annual Review:**
- Legal team reviews retention periods (Q1 each year)
- Engineering updates implementation status
- Compliance team audits deletion logs

**Trigger for Update:**
- New legal requirements (GDPR updates, new regulations)
- Business model changes (new data types collected)
- Incident response (data breach, audit finding)

---

## References

### Legal Requirements
- **IRS Publication 15**: Employment Tax Records (7-year retention)
- **FLSA Section 11(c)**: Payroll records (3-year minimum)
- **SOX Section 802**: Financial records (7-year retention)
- **GDPR Article 5(1)(e)**: Storage limitation principle
- **GDPR Article 17**: Right to erasure
- **CCPA Section 1798.105**: Consumer's right to deletion

### Internal Docs
- `firestore.rules`: Access control rules
- `functions/src/scheduled/`: Scheduled deletion functions (when implemented)
- `docs/security/`: Security policies
- `docs/runbooks/`: Operational runbooks

---

**Approved By:**
- Engineering: TBD
- Legal: TBD
- Compliance: TBD

**Next Review Date:** 2026-10-12
