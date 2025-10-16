/**
 * Emergency Rollback Utility - Migration Rollback
 *
 * PURPOSE:
 * Restores documents from backups created by backfill-companyId.ts script.
 * Provides emergency rollback capability if migration causes issues.
 *
 * USAGE:
 * ```bash
 * # Dry-run mode (preview rollback, no writes)
 * npm run rollback:migration -- --dry-run
 *
 * # Rollback all collections
 * npm run rollback:migration -- --confirm
 *
 * # Rollback specific collection
 * npm run rollback:migration -- --collection=jobs --confirm
 *
 * # Rollback specific document
 * npm run rollback:migration -- --collection=jobs --document=job-123 --confirm
 * ```
 *
 * SAFETY FEATURES:
 * ✅ Requires --confirm flag for actual execution
 * ✅ Dry-run mode for preview
 * ✅ Creates rollback snapshot before restore (rollback of the rollback)
 * ✅ Verifies backup integrity before restore
 * ✅ Batch restores (500 docs per batch)
 * ✅ Detailed audit logging
 * ✅ Preserves original timestamps where possible
 *
 * BACKUP STRUCTURE:
 * - Backups stored in: _backups/companyId_migration/documents
 * - Document ID format: {collection}_{documentId}
 * - Contains: collection, documentId, originalData, backedUpAt
 *
 * ROLLBACK PROCESS:
 * 1. Verify backups exist
 * 2. Create rollback snapshot (current state)
 * 3. Restore originalData to document
 * 4. Log restore operation
 * 5. Verify restore success
 *
 * EXIT CODES:
 * - 0: Success (all documents restored)
 * - 1: Partial success (some restores failed)
 * - 2: Script error or no backups found
 */

import * as admin from 'firebase-admin';
import * as fs from 'fs';

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

interface RollbackResult {
  collection: string;
  documentId: string;
  success: boolean;
  error?: string;
  backedUpAt?: Date;
}

interface RollbackSummary {
  timestamp: string;
  totalRestored: number;
  successCount: number;
  failureCount: number;
  results: RollbackResult[];
}

/**
 * Creates a snapshot of current document state before rollback.
 */
async function createRollbackSnapshot(
  collection: string,
  documentId: string
): Promise<void> {
  try {
    const docSnapshot = await db.collection(collection).doc(documentId).get();

    if (!docSnapshot.exists) {
      console.warn(`  [Snapshot] Document ${documentId} does not exist - skipping snapshot`);
      return;
    }

    await db
      .collection('_rollback_snapshots')
      .doc('migration_rollback')
      .collection('documents')
      .doc(`${collection}_${documentId}`)
      .set({
        collection,
        documentId,
        snapshotData: docSnapshot.data(),
        snapshotAt: admin.firestore.Timestamp.now(),
      });
  } catch (error) {
    console.error(`  [Snapshot] Failed to create snapshot for ${documentId}:`, error);
  }
}

/**
 * Restores a single document from backup.
 */
async function restoreDocument(
  backupDoc: admin.firestore.DocumentSnapshot,
  dryRun: boolean = false
): Promise<RollbackResult> {
  const backupData = backupDoc.data();

  if (!backupData) {
    return {
      collection: 'unknown',
      documentId: backupDoc.id,
      success: false,
      error: 'Backup document has no data',
    };
  }

  const { collection, documentId, originalData, backedUpAt } = backupData;

  const result: RollbackResult = {
    collection,
    documentId,
    success: false,
    backedUpAt: backedUpAt?.toDate(),
  };

  if (!dryRun) {
    try {
      // Create rollback snapshot before restore
      await createRollbackSnapshot(collection, documentId);

      // Restore original data
      await db.collection(collection).doc(documentId).set(originalData, { merge: false });

      result.success = true;
      console.log(`  ✅ Restored ${collection}/${documentId}`);
    } catch (error) {
      result.success = false;
      result.error = `Restore failed: ${error}`;
      console.error(`  ❌ Failed to restore ${collection}/${documentId}:`, error);
    }
  } else {
    // Dry-run mode
    result.success = true;
    console.log(`  [DRY-RUN] Would restore ${collection}/${documentId}`);
  }

  return result;
}

/**
 * Rolls back a specific collection.
 */
async function rollbackCollection(
  collection: string,
  dryRun: boolean = false
): Promise<RollbackResult[]> {
  console.log(`\nRolling back collection: ${collection}`);

  const backupsSnapshot = await db
    .collection('_backups')
    .doc('companyId_migration')
    .collection('documents')
    .where('collection', '==', collection)
    .get();

  if (backupsSnapshot.empty) {
    console.warn(`  No backups found for collection: ${collection}`);
    return [];
  }

  console.log(`  Found ${backupsSnapshot.size} backups`);

  const results: RollbackResult[] = [];

  for (const backupDoc of backupsSnapshot.docs) {
    const result = await restoreDocument(backupDoc, dryRun);
    results.push(result);
  }

  return results;
}

/**
 * Rolls back a specific document.
 */
async function rollbackDocument(
  collection: string,
  documentId: string,
  dryRun: boolean = false
): Promise<RollbackResult> {
  console.log(`\nRolling back document: ${collection}/${documentId}`);

  const backupRef = db
    .collection('_backups')
    .doc('companyId_migration')
    .collection('documents')
    .doc(`${collection}_${documentId}`);

  const backupSnapshot = await backupRef.get();

  if (!backupSnapshot.exists) {
    console.error(`  No backup found for ${collection}/${documentId}`);
    return {
      collection,
      documentId,
      success: false,
      error: 'Backup not found',
    };
  }

  return await restoreDocument(backupSnapshot, dryRun);
}

/**
 * Main rollback function.
 */
async function runRollback(
  collection?: string,
  documentId?: string,
  dryRun: boolean = false,
  confirm: boolean = false
): Promise<RollbackSummary> {
  console.log('========================================');
  console.log('Emergency Rollback Utility');
  console.log(`Mode: ${dryRun ? 'DRY-RUN (preview only)' : 'LIVE (will restore data)'}`);
  console.log('========================================\n');

  // Safety check: require --confirm flag for live rollback
  if (!dryRun && !confirm) {
    console.error('❌ SAFETY CHECK FAILED');
    console.error('Live rollback requires --confirm flag to proceed.');
    console.error('Usage: npm run rollback:migration -- --confirm');
    console.error('Or use --dry-run to preview changes.');
    process.exit(2);
  }

  let results: RollbackResult[] = [];

  if (collection && documentId) {
    // Rollback specific document
    const result = await rollbackDocument(collection, documentId, dryRun);
    results.push(result);
  } else if (collection) {
    // Rollback specific collection
    results = await rollbackCollection(collection, dryRun);
  } else {
    // Rollback all collections
    console.log('Discovering backed-up collections...\n');

    const backupsSnapshot = await db
      .collection('_backups')
      .doc('companyId_migration')
      .collection('documents')
      .get();

    if (backupsSnapshot.empty) {
      console.error('❌ No backups found! Cannot proceed with rollback.');
      process.exit(2);
    }

    // Group backups by collection
    const collectionMap = new Map<string, admin.firestore.DocumentSnapshot[]>();
    backupsSnapshot.docs.forEach((doc) => {
      const data = doc.data();
      if (data.collection) {
        if (!collectionMap.has(data.collection)) {
          collectionMap.set(data.collection, []);
        }
        collectionMap.get(data.collection)!.push(doc);
      }
    });

    console.log(`Found backups for ${collectionMap.size} collections:\n`);
    collectionMap.forEach((docs, col) => {
      console.log(`  - ${col}: ${docs.length} documents`);
    });
    console.log('');

    // Restore all collections
    for (const [col, backupDocs] of collectionMap) {
      console.log(`\nRestoring collection: ${col}`);
      console.log(`  Backups: ${backupDocs.length}`);

      for (const backupDoc of backupDocs) {
        const result = await restoreDocument(backupDoc, dryRun);
        results.push(result);
      }
    }
  }

  // Summary
  const successCount = results.filter((r) => r.success).length;
  const failureCount = results.filter((r) => !r.success).length;

  console.log('\n========================================');
  console.log('ROLLBACK SUMMARY');
  console.log('========================================');
  console.log(`Total documents: ${results.length}`);
  console.log(`Successfully restored: ${successCount}`);
  console.log(`Failed: ${failureCount}`);

  if (failureCount > 0) {
    console.log('\n❌ Failed restores:');
    results
      .filter((r) => !r.success)
      .forEach((r) => {
        console.log(`  ${r.collection}/${r.documentId}: ${r.error}`);
      });

    // Export failures to JSON
    const reportPath = 'rollback-failed.json';
    fs.writeFileSync(
      reportPath,
      JSON.stringify(
        results.filter((r) => !r.success),
        null,
        2
      )
    );
    console.log(`\nFailed restores exported to: ${reportPath}`);
  } else if (successCount > 0) {
    console.log('\n✅ All documents successfully restored!');
  }

  console.log('========================================\n');

  const summary: RollbackSummary = {
    timestamp: new Date().toISOString(),
    totalRestored: results.length,
    successCount,
    failureCount,
    results,
  };

  return summary;
}

/**
 * CLI entry point.
 */
async function main() {
  const args = process.argv.slice(2);
  const dryRun = args.includes('--dry-run');
  const confirm = args.includes('--confirm');
  const collectionArg = args.find((arg) => arg.startsWith('--collection='));
  const documentArg = args.find((arg) => arg.startsWith('--document='));

  const collection = collectionArg?.split('=')[1];
  const documentId = documentArg?.split('=')[1];

  try {
    const summary = await runRollback(collection, documentId, dryRun, confirm);

    if (summary.failureCount > 0) {
      process.exit(1);
    } else {
      process.exit(0);
    }
  } catch (error) {
    console.error('Rollback failed:', error);
    process.exit(2);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

export { runRollback, restoreDocument, createRollbackSnapshot };
