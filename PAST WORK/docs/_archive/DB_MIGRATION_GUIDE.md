# Database Migration Reversibility Guide

## Overview

This guide provides best practices for creating reversible database migrations and backfill scripts to ensure safe deployments with quick rollback capabilities.

## Principles of Reversible Migrations

### 1. Always Additive First

Make changes in a way that doesn't break existing code:

**Good (Reversible):**
```javascript
// Step 1: Add new field (optional)
{
  oldField: "value",
  newField: "value"  // New code writes both
}

// Step 2: Backfill data
// Step 3: Update all code to use newField
// Step 4: Remove oldField (after verification)
```

**Bad (Not Reversible):**
```javascript
// Immediate rename breaks old code
{
  newField: "value"  // oldField gone immediately
}
```

### 2. Three-Phase Deployment

**Phase 1: Expand (Add New)**
- Add new fields/collections
- Keep old fields intact
- New code writes to both old and new
- Deploy and verify

**Phase 2: Backfill (Migrate Data)**
- Run backfill script to populate new fields
- Verify data integrity
- Monitor performance impact

**Phase 3: Contract (Remove Old)**
- Update code to only use new fields
- Deploy and verify
- Remove old fields (optional cleanup)

### 3. Rollback Support

Each phase should be independently reversible:

- **Phase 1 Rollback**: Remove new fields, revert code
- **Phase 2 Rollback**: New fields remain but unused
- **Phase 3 Rollback**: Restore code to use old fields

## Migration Patterns

### Pattern 1: Adding a Field

**Safe (Reversible):**
```typescript
// New field is optional
interface Job {
  title: string;
  description: string;
  newField?: string;  // Optional
}

// Code handles missing field
const value = job.newField ?? 'default';
```

**Rollback**: No action needed. Old code ignores new field.

### Pattern 2: Renaming a Field

**Safe (Three-Phase):**

**Phase 1: Add New Field**
```typescript
interface Job {
  oldName: string;
  newName?: string;
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
  .get();

for (const doc of jobs.docs) {
  await doc.ref.update({
    newName: doc.data().oldName
  });
}
```

**Phase 3: Remove Old Field**
```typescript
interface Job {
  newName: string;  // No longer optional
}

// Only write to newName
await jobRef.update({
  newName: value
});
```

**Rollback Plan:**
- Phase 1: Revert code, remove newName field
- Phase 2: Keep both fields, no action needed
- Phase 3: Restore code to use oldName, data still available

### Pattern 3: Changing Field Type

**Safe (Three-Phase):**

**Phase 1: Add New Typed Field**
```typescript
interface Invoice {
  total: string;        // Old: string
  totalAmount?: number; // New: number
}

// Write both
await invoiceRef.update({
  total: amount.toString(),
  totalAmount: amount
});
```

**Phase 2: Backfill**
```typescript
// Convert string to number
const invoices = await db.collection('invoices')
  .where('totalAmount', '==', null)
  .get();

for (const doc of invoices.docs) {
  const total = doc.data().total;
  await doc.ref.update({
    totalAmount: parseFloat(total)
  });
}
```

**Phase 3: Remove Old Field**
```typescript
interface Invoice {
  totalAmount: number;
}
```

**Rollback Plan:**
- Phase 1-2: Use old field (total)
- Phase 3: Backfill total from totalAmount

### Pattern 4: Restructuring Data

**Safe (Shadow Write):**

**Old Structure:**
```typescript
{
  address: "123 Main St, City, ST 12345"
}
```

**New Structure:**
```typescript
{
  address: "123 Main St, City, ST 12345",  // Keep old
  addressComponents: {                      // Add new
    street: "123 Main St",
    city: "City",
    state: "ST",
    zip: "12345"
  }
}
```

**Rollback**: Use old address field

## Backfill Scripts

### Safe Backfill Script Template

```typescript
import * as admin from 'firebase-admin';

interface BackfillOptions {
  batchSize: number;
  dryRun: boolean;
  collection: string;
}

async function backfillData(options: BackfillOptions) {
  const { batchSize, dryRun, collection } = options;
  
  console.log(`Starting backfill for ${collection}`);
  console.log(`Batch size: ${batchSize}`);
  console.log(`Dry run: ${dryRun}`);
  
  let processed = 0;
  let errors = 0;
  
  // Get documents needing backfill
  let query = admin.firestore()
    .collection(collection)
    .where('newField', '==', null)  // Only unprocessed
    .limit(batchSize);
  
  let snapshot = await query.get();
  
  while (!snapshot.empty) {
    const batch = admin.firestore().batch();
    
    for (const doc of snapshot.docs) {
      try {
        // Transform data
        const data = doc.data();
        const newValue = transformData(data);
        
        if (dryRun) {
          console.log(`[DRY RUN] Would update ${doc.id}`);
        } else {
          batch.update(doc.ref, { newField: newValue });
        }
        
        processed++;
      } catch (error) {
        console.error(`Error processing ${doc.id}:`, error);
        errors++;
      }
    }
    
    if (!dryRun) {
      await batch.commit();
      console.log(`Committed batch of ${snapshot.docs.length} documents`);
    }
    
    // Rate limiting
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Get next batch
    snapshot = await query.get();
  }
  
  console.log(`Backfill complete: ${processed} processed, ${errors} errors`);
}

function transformData(data: any): any {
  // Implement transformation logic
  return data.oldField;
}

// Run with options
backfillData({
  batchSize: 500,
  dryRun: true,  // Always test with dry run first
  collection: 'jobs'
});
```

### Backfill Best Practices

1. **Always dry-run first**
   ```bash
   npm run migrate:backfill -- --dry-run
   ```

2. **Use batching**
   - Process in small batches (100-500 documents)
   - Commit batches separately
   - Add rate limiting between batches

3. **Monitor performance**
   - Track processing time
   - Monitor Firestore quota usage
   - Check for errors

4. **Make idempotent**
   - Script can be run multiple times safely
   - Skip already-processed documents
   - Log progress for resumability

5. **Verify after backfill**
   ```typescript
   // Count documents processed
   const total = await db.collection('jobs').count().get();
   const processed = await db.collection('jobs')
     .where('newField', '!=', null)
     .count()
     .get();
   
   console.log(`Processed: ${processed.data().count}/${total.data().count}`);
   ```

## Rollback Scenarios

### Scenario 1: Code Deployment Failed

**Situation**: New code deployed but crashes

**Rollback**:
1. Revert to previous code version
2. Database state unchanged (additive changes only)
3. No data migration needed

**Prevention**: Pre-deploy checks, feature flags

### Scenario 2: Data Corruption During Backfill

**Situation**: Backfill script has bug, some data incorrect

**Rollback**:
1. Stop backfill script immediately
2. Code still uses old field (no impact)
3. Fix backfill script
4. Re-run on affected documents only

**Prevention**: Dry-run, gradual rollout, verification

### Scenario 3: Performance Degradation

**Situation**: New field causes slow queries

**Rollback**:
1. Update code to use old field
2. New field remains but unused
3. Create index if needed
4. Remove new field later (optional)

**Prevention**: Index planning, load testing

### Scenario 4: Breaking Change Deployed

**Situation**: Old field removed too early

**Rollback**:
1. **Immediate**: Use feature flag to disable new code path
2. **Short-term**: Redeploy old code version
3. **Long-term**: Backfill old field from new field

**Prevention**: Three-phase deployment, gradual rollout

## Migration Checklist

### Pre-Migration

- [ ] Migration follows three-phase pattern
- [ ] Backfill script written and tested (dry-run)
- [ ] Rollback procedure documented in MIGRATION_NOTES.md
- [ ] Indexes created for new fields (if needed)
- [ ] Performance impact estimated
- [ ] Backups verified and tested
- [ ] Team notified of migration schedule

### During Migration

- [ ] Run backfill script in dry-run mode
- [ ] Verify dry-run results
- [ ] Run backfill script in production (small batch first)
- [ ] Monitor Firestore metrics
- [ ] Verify data integrity
- [ ] Check application performance
- [ ] Monitor error rates

### Post-Migration

- [ ] Verify all documents processed
- [ ] Run smoke tests
- [ ] Monitor for 24 hours
- [ ] Document any issues encountered
- [ ] Update MIGRATION_NOTES.md with results
- [ ] Schedule cleanup (remove old fields) if applicable

## Firestore Backup and Restore

### Manual Backup

```bash
# Export collection
gcloud firestore export gs://your-backup-bucket/backup-$(date +%Y%m%d) \
  --collection-ids=jobs,invoices,estimates

# List backups
gsutil ls gs://your-backup-bucket/
```

### Restore from Backup

```bash
# Import from backup
gcloud firestore import gs://your-backup-bucket/backup-20240115

# Restore specific collection
gcloud firestore import gs://your-backup-bucket/backup-20240115 \
  --collection-ids=jobs
```

### Automated Backups

Set up automated backups in Firebase Console or with Cloud Scheduler:

```yaml
# Cloud Scheduler job
schedule: "0 2 * * *"  # Daily at 2 AM
target: "https://firestore.googleapis.com/v1/projects/PROJECT_ID/databases/(default):exportDocuments"
body:
  outputUriPrefix: "gs://your-backup-bucket/scheduled-backup"
```

## Related Documentation

- [MIGRATION_NOTES.md](./MIGRATION_NOTES.md) - Specific migration history
- [docs/rollout-rollback.md](./docs/rollout-rollback.md) - Rollback procedures
- [scripts/deploy/README.md](./scripts/deploy/README.md) - Deployment automation
- [CANARY_QUICKSTART.md](./CANARY_QUICKSTART.md) - Canary deployment guide

## Support

For questions or issues with migrations:
1. Review this guide and MIGRATION_NOTES.md
2. Test migration in dev/staging first
3. Always have rollback plan ready
4. Contact team lead before production migrations
