#!/usr/bin/env node
/**
 * Firestore Data Migration: timeEntries → time_entries
 *
 * PURPOSE:
 * Migrates all documents from the legacy "timeEntries" collection to the
 * canonical "time_entries" collection for schema consistency.
 *
 * USAGE:
 * # Dry run (no writes)
 * node tools/migrate_timeEntries_to_time_entries.cjs --dry-run
 *
 * # Execute migration
 * node tools/migrate_timeEntries_to_time_entries.cjs
 *
 * # Execute for specific project
 * GOOGLE_APPLICATION_CREDENTIALS=path/to/key.json node tools/migrate_timeEntries_to_time_entries.cjs
 *
 * SAFETY:
 * - Uses merge writes (preserves any existing data in time_entries)
 * - Original timeEntries collection is NOT deleted (manual cleanup after verification)
 * - Supports dry-run mode for testing
 * - Batch writes for efficiency (500 docs per batch)
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
}

const db = admin.firestore();

// Parse command-line arguments
const DRY_RUN = process.argv.includes('--dry-run');
const VERBOSE = process.argv.includes('--verbose');

// Migration configuration
const SOURCE_COLLECTION = 'timeEntries';
const TARGET_COLLECTION = 'time_entries';
const BATCH_SIZE = 500;

/**
 * Main migration function
 */
async function migrateTimeEntries() {
  console.log('╔════════════════════════════════════════════════════════════╗');
  console.log('║  Firestore Migration: timeEntries → time_entries          ║');
  console.log('╚════════════════════════════════════════════════════════════╝');
  console.log('');
  console.log(`Mode: ${DRY_RUN ? '🔍 DRY RUN (no writes)' : '⚡ LIVE MIGRATION'}`);
  console.log(`Source: /${SOURCE_COLLECTION}`);
  console.log(`Target: /${TARGET_COLLECTION}`);
  console.log('');

  try {
    // Fetch all documents from source collection
    console.log('📥 Fetching documents from source collection...');
    const sourceSnapshot = await db.collection(SOURCE_COLLECTION).get();
    const totalDocs = sourceSnapshot.size;

    console.log(`✅ Found ${totalDocs} documents to migrate`);
    console.log('');

    if (totalDocs === 0) {
      console.log('ℹ️  No documents to migrate. Exiting.');
      return;
    }

    // Process documents in batches
    let migratedCount = 0;
    let batch = db.batch();
    let batchCount = 0;

    for (const doc of sourceSnapshot.docs) {
      const docId = doc.id;
      const docData = doc.data();

      if (VERBOSE) {
        console.log(`  → Migrating ${docId}`);
      }

      if (!DRY_RUN) {
        const targetRef = db.collection(TARGET_COLLECTION).doc(docId);
        batch.set(targetRef, docData, { merge: true });
        batchCount++;

        // Commit batch when it reaches BATCH_SIZE
        if (batchCount >= BATCH_SIZE) {
          console.log(`  💾 Committing batch (${batchCount} documents)...`);
          await batch.commit();
          batch = db.batch();
          batchCount = 0;
        }
      }

      migratedCount++;
    }

    // Commit remaining documents
    if (!DRY_RUN && batchCount > 0) {
      console.log(`  💾 Committing final batch (${batchCount} documents)...`);
      await batch.commit();
    }

    console.log('');
    console.log('╔════════════════════════════════════════════════════════════╗');
    console.log(`║  ${DRY_RUN ? 'DRY RUN COMPLETE' : 'MIGRATION COMPLETE'}                                 ║`);
    console.log('╚════════════════════════════════════════════════════════════╝');
    console.log('');
    console.log(`✅ ${DRY_RUN ? 'Would migrate' : 'Migrated'} ${migratedCount} documents`);
    console.log('');

    if (DRY_RUN) {
      console.log('ℹ️  This was a dry run. No data was written.');
      console.log('ℹ️  Run without --dry-run to execute the migration.');
    } else {
      console.log('✅ Migration complete!');
      console.log('');
      console.log('📋 Next steps:');
      console.log(`   1. Verify data in /${TARGET_COLLECTION} collection`);
      console.log(`   2. Update all Dart queries to use "${TARGET_COLLECTION}"`);
      console.log(`   3. Test Clock In/Out flow end-to-end`);
      console.log(`   4. After verification, manually delete /${SOURCE_COLLECTION} collection`);
      console.log('');
      console.log('⚠️  DO NOT delete source collection until you\'ve verified the migration!');
    }

  } catch (error) {
    console.error('');
    console.error('❌ Migration failed with error:');
    console.error(error);
    process.exit(1);
  }
}

// Run migration
migrateTimeEntries()
  .then(() => {
    console.log('');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Unhandled error:', error);
    process.exit(1);
  });
