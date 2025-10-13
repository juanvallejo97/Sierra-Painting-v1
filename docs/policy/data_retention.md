# Data Retention & Lifecycle Policy

**Version**: 1.0.0
**Last Updated**: 2025-10-11
**Owner**: Data Governance & Platform Team
**Status**: Active

---

## Table of Contents

1. [Overview](#overview)
2. [Retention Periods](#retention-periods)
3. [Data Lifecycle](#data-lifecycle)
4. [Backup Strategy](#backup-strategy)
5. [Disaster Recovery](#disaster-recovery)
6. [GDPR Compliance](#gdpr-compliance)
7. [Data Deletion](#data-deletion)
8. [Automated TTL Implementation](#automated-ttl-implementation)
9. [Audit and Compliance](#audit-and-compliance)

---

## Overview

This document defines data retention periods, lifecycle management, backup strategies, and deletion procedures for the Sierra Painting application.

**Objectives**:
- Minimize data storage costs by removing obsolete data
- Comply with legal requirements (GDPR, CCPA, labor laws)
- Enable disaster recovery with reliable backups
- Protect user privacy through timely data deletion
- Maintain audit trails for compliance and security

**Scope**: All data stored in Firestore, Cloud Storage, and third-party services (Stripe, Analytics).

---

## Retention Periods

### Production Data

| Collection | Retention Period | Reason | Auto-Delete |
|------------|------------------|--------|-------------|
| **timeEntries** | 7 years | Labor law compliance (audit trail) | No |
| **clockEvents** | 7 years | Immutable audit log | No |
| **invoices** | 7 years | Tax law requirement | No |
| **estimates** | 3 years | Business records | Yes |
| **jobs** | 5 years | Project history | No |
| **companies** | Indefinite | Active business entity | No |
| **users** | Until account deletion | GDPR right to erasure | Manual |
| **customers** | 3 years post-last-job | Business records | Yes |
| **assignments** | 2 years post-end-date | Scheduling history | Yes |
| **_backups** | 30 days | Metadata only | Yes |

### Logs and Analytics

| Data Type | Retention Period | Location | Auto-Delete |
|-----------|------------------|----------|-------------|
| **Function logs** | 30 days | Cloud Logging | Yes (GCP) |
| **Performance traces** | 90 days | Firebase Performance | Yes |
| **Crashlytics reports** | 180 days | Firebase Crashlytics | Yes |
| **Analytics events** | 14 months | Firebase Analytics | Yes (GA) |
| **Audit logs** | 1 year | Firestore `_audit` | Yes |

### Backups

| Backup Type | Retention Period | Location | Auto-Delete |
|-------------|------------------|----------|-------------|
| **Daily full backup** | 30 days | Cloud Storage | Yes |
| **Weekly backup** | 90 days | Cloud Storage | Yes |
| **Monthly backup** | 1 year | Cloud Storage | Yes |
| **Annual backup** | 7 years | Cloud Storage (Archive) | No |

---

## Data Lifecycle

### Stage 1: Active (0-12 months)

**Data**: Recently created, frequently accessed
**Storage Tier**: Standard (Firestore, Cloud Storage Standard)
**Access Pattern**: Read/write multiple times per day
**Collections**: timeEntries (status: active, pending, approved)

**Characteristics**:
- Full CRUD permissions for authorized users
- Real-time updates
- Indexed for fast queries
- Included in daily backups

### Stage 2: Archive (1-7 years)

**Data**: Historical records, infrequently accessed
**Storage Tier**: Nearline (Cloud Storage Nearline)
**Access Pattern**: Read-only, accessed monthly or less
**Collections**: timeEntries (status: invoiced, archived), old invoices

**Characteristics**:
- Read-only access
- Move to separate `_archive` collections
- Indexes removed to reduce costs
- Included in monthly backups only

### Stage 3: Legal Hold (7+ years)

**Data**: Required for legal compliance
**Storage Tier**: Coldline (Cloud Storage Coldline)
**Access Pattern**: Rarely accessed, legal disputes only
**Collections**: invoices, timeEntries (for tax audits)

**Characteristics**:
- Read-only, admin access only
- Stored in Cloud Storage (not Firestore)
- Not indexed
- Included in annual backups

### Stage 4: Deletion

**Data**: Expired retention period or user request
**Action**: Permanent deletion (GDPR compliance)
**Collections**: User accounts, expired estimates

**Characteristics**:
- Permanent deletion (no recovery)
- Logged in audit trail
- Cascading deletion (user data deleted across all collections)

---

## Backup Strategy

### Daily Backups

**Schedule**: Every day at 3:00 AM UTC
**Type**: Full backup (all collections)
**Format**: JSON.gz (gzip compressed)
**Location**: `gs://staging-backups-sierra-painting/YYYY-MM-DD-full-03h00m.json.gz`
**Retention**: 30 days
**Size**: ~50-100 MB (compressed)

**Command**:
```bash
ts-node tools/backup/export_firestore.ts --env=staging --type=full
```

### Hourly Incremental Backups (Production Only)

**Schedule**: Every hour
**Type**: Incremental (only changed documents)
**Format**: JSON.gz
**Location**: `gs://production-backups-sierra-painting/YYYY-MM-DD-incremental-HHh00m.json.gz`
**Retention**: 7 days
**Size**: ~5-10 MB (compressed)

**Command**:
```bash
ts-node tools/backup/export_firestore.ts --env=production --type=incremental
```

### Weekly Backups

**Schedule**: Every Sunday at 3:00 AM UTC
**Type**: Full backup
**Retention**: 90 days (12 weekly backups)
**Special**: Tagged with week number (e.g., `2025-W41-full.json.gz`)

### Monthly Backups

**Schedule**: First day of month at 3:00 AM UTC
**Type**: Full backup
**Retention**: 1 year (12 monthly backups)
**Special**: Tagged with month (e.g., `2025-10-full.json.gz`)

### Annual Backups

**Schedule**: January 1st at 3:00 AM UTC
**Type**: Full backup
**Retention**: 7 years (legal compliance)
**Special**: Moved to Coldline storage class for cost savings

---

## Disaster Recovery

### Recovery Point Objective (RPO)

- **Production**: 1 hour (hourly incremental backups)
- **Staging**: 24 hours (daily full backups)

### Recovery Time Objective (RTO)

- **Production**: 4 hours (time to restore and verify)
- **Staging**: 8 hours

### Disaster Scenarios

#### Scenario 1: Accidental Data Deletion

**Example**: Admin accidentally deletes a company's time entries

**Recovery Steps**:
1. Identify backup timestamp before deletion
2. Run restore with selective collection:
   ```bash
   ts-node tools/backup/restore_firestore.ts \
     --file=backups/production/2025-10-11-full.json.gz \
     --collections=timeEntries \
     --strategy=merge \
     --confirm
   ```
3. Verify restored data
4. Notify affected users

**RTO**: 30 minutes

#### Scenario 2: Database Corruption

**Example**: Bug in code causes data corruption across multiple collections

**Recovery Steps**:
1. Stop all writes (disable affected Cloud Functions)
2. Identify last known good backup
3. Run full restore with replace strategy:
   ```bash
   ts-node tools/backup/restore_firestore.ts \
     --file=backups/production/2025-10-11-full.json.gz \
     --strategy=replace \
     --confirm
   ```
4. Deploy hotfix
5. Re-enable Cloud Functions
6. Run smoke tests

**RTO**: 2-4 hours

#### Scenario 3: Complete Firestore Outage

**Example**: Firebase region outage, data unavailable

**Recovery Steps**:
1. Monitor Firebase status page
2. If outage >1 hour, prepare restore to alternate project
3. Create new Firebase project in different region
4. Restore latest backup:
   ```bash
   ts-node tools/backup/restore_firestore.ts \
     --file=backups/production/latest.json.gz \
     --env=production \
     --strategy=replace \
     --confirm
   ```
5. Update DNS/app config to point to new project
6. Migrate back when original region restored

**RTO**: 4-8 hours

### Testing Schedule

- **Quarterly**: Restore staging from backup (verify process)
- **Annually**: Full disaster recovery drill (simulate production outage)

---

## GDPR Compliance

### Right to Access

**Requirement**: Users can request copy of their data

**Implementation**:
- Export tool: `tools/gdpr/export_user_data.ts`
- Collects data from all collections where `userId` matches
- Formats as JSON, includes:
  - User profile
  - Time entries
  - Clock events
  - Associated jobs/assignments

**Command**:
```bash
ts-node tools/gdpr/export_user_data.ts --userId=<user-id> --output=user_data.json
```

**SLA**: 30 days from request

### Right to Erasure

**Requirement**: Users can request deletion of their data

**Implementation**:
- Deletion tool: `tools/gdpr/delete_user_data.ts`
- Cascading deletion across all collections
- Retains anonymized aggregates for analytics
- Cannot delete invoiced time entries (legal requirement)
  - Instead, PII redacted (name → "User [ID]", email → "deleted@example.com")

**Command**:
```bash
ts-node tools/gdpr/delete_user_data.ts --userId=<user-id> --confirm
```

**SLA**: 30 days from request

**Exceptions**:
- Invoiced time entries: PII redacted, record retained 7 years
- Audit logs: Anonymized, not deleted
- Backups: Not immediately deleted (expire per retention policy)

### Right to Portability

**Requirement**: Users can export data in machine-readable format

**Implementation**:
- Same as "Right to Access"
- Output format: JSON (machine-readable)
- Includes all user-generated content

### Data Processing Agreement (DPA)

**Firebase/GCP**: Covered by Google Cloud DPA
**Stripe**: Covered by Stripe DPA
**Subprocessors**: Listed in `docs/security/subprocessors.md`

---

## Data Deletion

### Manual Deletion Triggers

1. **User Account Deletion**: User requests account deletion
2. **Company Offboarding**: Company terminates service
3. **Test Data Cleanup**: Remove test/demo data from staging
4. **GDPR Request**: User exercises right to erasure

### Automated Deletion (TTL)

Implemented via Cloud Functions triggered daily:

```typescript
// functions/src/scheduled/cleanup.ts
export const dailyCleanup = functions.pubsub
  .schedule('0 2 * * *') // 2am UTC daily
  .onRun(async (context) => {
    await cleanupExpiredEstimates(); // >3 years old
    await cleanupExpiredAssignments(); // >2 years past end date
    await cleanupOldAuditLogs(); // >1 year old
    await cleanupExpiredBackupMetadata(); // >30 days old
  });
```

### Soft Delete vs Hard Delete

**Soft Delete** (Status-based):
- Collection: `timeEntries`, `jobs`, `invoices`
- Method: Set `status: 'deleted'`, `deletedAt: timestamp`
- Reason: Allow recovery, audit trail
- Final deletion: After 30 days via TTL function

**Hard Delete** (Immediate):
- Collection: `_cache`, temporary data
- Method: `doc.delete()`
- Reason: No compliance requirement, immediate cleanup

---

## Automated TTL Implementation

### Collection-Specific TTL Rules

#### estimates

**TTL**: 3 years from `createdAt`
**Reason**: Business records, not legally required
**Implementation**:
```typescript
const cutoffDate = new Date();
cutoffDate.setFullYear(cutoffDate.getFullYear() - 3);

const expiredEstimates = await db
  .collection('estimates')
  .where('createdAt', '<', cutoffDate)
  .where('status', '!=', 'accepted') // Keep accepted (became jobs)
  .get();

for (const doc of expiredEstimates.docs) {
  await doc.ref.delete();
}
```

#### assignments

**TTL**: 2 years from `endDate`
**Reason**: Scheduling history, no longer relevant
**Implementation**:
```typescript
const cutoffDate = new Date();
cutoffDate.setFullYear(cutoffDate.getFullYear() - 2);

const expiredAssignments = await db
  .collection('assignments')
  .where('endDate', '<', cutoffDate)
  .where('active', '==', false)
  .get();
```

#### _audit logs

**TTL**: 1 year from `timestamp`
**Reason**: Security audit trail
**Implementation**:
```typescript
const cutoffDate = new Date();
cutoffDate.setFullYear(cutoffDate.getFullYear() - 1);

const oldLogs = await db
  .collection('_audit')
  .where('timestamp', '<', cutoffDate)
  .get();
```

### Execution Schedule

**Daily**: 2:00 AM UTC (low traffic time)
**Duration**: ~5-10 minutes
**Monitoring**: Cloud Functions logs, alerting on failures

---

## Audit and Compliance

### Audit Log Requirements

All data lifecycle events must be logged:

```typescript
interface AuditLog {
  timestamp: Timestamp;
  action: 'create' | 'read' | 'update' | 'delete' | 'export';
  collection: string;
  documentId: string;
  userId: string;
  reason?: string; // e.g., "GDPR request"
  metadata?: Record<string, any>;
}
```

**Logged Actions**:
- Backup creation (daily)
- Backup restoration (disaster recovery)
- Data export (GDPR request)
- Data deletion (user request, TTL)
- Access to archived data (legal hold)

### Compliance Checklist

**Monthly Review**:
- [ ] Verify daily backups completed successfully
- [ ] Check backup retention compliance (30 days)
- [ ] Review TTL function execution logs
- [ ] Audit GDPR requests (response within 30 days)
- [ ] Verify no unauthorized data access

**Quarterly Review**:
- [ ] Test disaster recovery (restore staging from backup)
- [ ] Review data retention periods (update if needed)
- [ ] Audit storage costs (archive old data)
- [ ] Update subprocessor list
- [ ] Review and update this policy

**Annual Review**:
- [ ] Full disaster recovery drill (production simulation)
- [ ] Legal review of retention periods
- [ ] Update DPAs with vendors
- [ ] Security audit of backup procedures
- [ ] Compliance certification (SOC 2, ISO 27001 if applicable)

---

## Related Documentation

- [Backup Export Tool](../../tools/backup/export_firestore.ts)
- [Backup Restore Tool](../../tools/backup/restore_firestore.ts)
- [GDPR Compliance Guide](../security/gdpr_compliance.md)
- [Disaster Recovery Playbook](../ops/disaster_recovery.md)
- [Cloud Functions Cleanup Jobs](../../functions/src/scheduled/cleanup.ts)

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2025-10-11 | Initial version | Claude Code |

---

## Feedback

For questions or suggestions:
- Slack: #data-governance or #platform-team
- Email: compliance@example.com
- GitHub Issues: tag `data-governance` and `policy`
