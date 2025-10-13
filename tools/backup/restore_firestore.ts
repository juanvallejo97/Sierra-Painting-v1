#!/usr/bin/env ts-node
/**
 * Firestore Backup Restore Tool
 *
 * PURPOSE:
 * Restore Firestore data from backup files created by export_firestore.ts.
 * Supports full and selective restore, merge or replace strategies, and dry-run mode.
 *
 * FEATURES:
 * - Full restore: Restore all collections from backup
 * - Selective restore: Restore specific collections only
 * - Merge strategy: Merge backup data with existing data
 * - Replace strategy: Delete existing data before restore
 * - Dry-run mode: Preview restore without making changes
 * - Progress reporting: Real-time progress updates
 * - Validation: Verify backup integrity before restore
 * - Transaction batching: Efficient batch writes (500 docs per batch)
 *
 * USAGE:
 * # Dry-run (preview only)
 * ts-node tools/backup/restore_firestore.ts --file=backups/staging/2025-10-11-full.json.gz --dry-run
 *
 * # Full restore with merge
 * ts-node tools/backup/restore_firestore.ts --file=backups/staging/2025-10-11-full.json.gz --strategy=merge
 *
 * # Replace existing data (DANGEROUS!)
 * ts-node tools/backup/restore_firestore.ts --file=backups/staging/2025-10-11-full.json.gz --strategy=replace --confirm
 *
 * # Selective restore (specific collections)
 * ts-node tools/backup/restore_firestore.ts --file=backup.json.gz --collections=timeEntries,clockEvents
 *
 * REQUIREMENTS:
 * - Firebase service account with Firestore write permissions
 * - Backup file from export_firestore.ts
 * - Node.js 20+
 *
 * SAFETY:
 * - Dry-run by default (requires --confirm for actual restore)
 * - Validation before restore
 * - Replace strategy requires explicit --confirm flag
 * - Progress reporting for transparency
 *
 * OUTPUT:
 * {
 *   "success": true,
 *   "restoredDocuments": 1250,
 *   "collections": ["companies", "users", "jobs", ...],
 *   "duration": 45.2,
 *   "strategy": "merge"
 * }
 */

import * as admin from 'firebase-admin';
import * as fs from 'fs';
import * as zlib from 'zlib';

// Configuration
interface Config {
  filePath: string;
  env: 'staging' | 'production';
  strategy: 'merge' | 'replace';
  dryRun: boolean;
  collections?: string[];
  confirm: boolean;
}

// Backup data structure
interface BackupData {
  metadata: {
    timestamp: string;
    environment: string;
    type: string;
    collections: string[];
    documentCount: number;
  };
  data: {
    collections: Array<{
      name: string;
      documents: Array<{
        id: string;
        data: any;
      }>;
    }>;
  };
}

// Restore result
interface RestoreResult {
  success: boolean;
  restoredDocuments: number;
  collections: string[];
  duration: number;
  strategy: string;
  error?: string;
}

// Parse command line arguments
function parseArgs(): Config {
  const args = process.argv.slice(2);
  let filePath = '';
  let env: 'staging' | 'production' = 'staging';
  let strategy: 'merge' | 'replace' = 'merge';
  let dryRun = true;
  let collections: string[] | undefined;
  let confirm = false;

  for (const arg of args) {
    if (arg.startsWith('--file=')) {
      filePath = arg.split('=')[1];
    } else if (arg.startsWith('--env=')) {
      const value = arg.split('=')[1];
      if (value === 'staging' || value === 'production') {
        env = value;
      }
    } else if (arg.startsWith('--strategy=')) {
      const value = arg.split('=')[1];
      if (value === 'merge' || value === 'replace') {
        strategy = value;
      }
    } else if (arg === '--dry-run') {
      dryRun = true;
    } else if (arg === '--confirm') {
      confirm = true;
      dryRun = false;
    } else if (arg.startsWith('--collections=')) {
      collections = arg.split('=')[1].split(',');
    }
  }

  if (!filePath) {
    throw new Error('Missing required argument: --file=<path>');
  }

  return {
    filePath,
    env,
    strategy,
    dryRun,
    collections,
    confirm,
  };
}

// Initialize Firebase
function initializeFirebase(config: Config): admin.app.App {
  const serviceAccountPath =
    config.env === 'production'
      ? '../../firebase-service-account-production.json'
      : '../../firebase-service-account-staging.json';

  try {
    const serviceAccount = require(serviceAccountPath);
    return admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId:
        config.env === 'production'
          ? 'sierra-painting-production'
          : 'sierra-painting-staging',
    });
  } catch (error) {
    console.error(`❌ Failed to load service account: ${serviceAccountPath}`);
    throw error;
  }
}

// Load and validate backup file
function loadBackupFile(filePath: string): BackupData {
  console.log(`Loading backup file: ${filePath}`);

  if (!fs.existsSync(filePath)) {
    throw new Error(`Backup file not found: ${filePath}`);
  }

  // Read file
  const compressed = fs.readFileSync(filePath);
  console.log(`  File size: ${(compressed.length / 1024 / 1024).toFixed(2)} MB`);

  // Decompress
  const decompressed = zlib.gunzipSync(compressed);
  console.log('  ✓ Decompressed');

  // Parse JSON
  const data: BackupData = JSON.parse(decompressed.toString('utf-8'));
  console.log('  ✓ Parsed JSON');

  // Validate structure
  if (!data.metadata || !data.data) {
    throw new Error('Invalid backup structure');
  }

  console.log(`  Backup timestamp: ${data.metadata.timestamp}`);
  console.log(`  Environment: ${data.metadata.environment}`);
  console.log(`  Type: ${data.metadata.type}`);
  console.log(`  Collections: ${data.metadata.collections.length}`);
  console.log(`  Documents: ${data.metadata.documentCount}`);

  return data;
}

// Delete existing data in collection (replace strategy)
async function deleteCollection(
  db: admin.firestore.Firestore,
  collectionName: string,
  dryRun: boolean
): Promise<number> {
  const collectionRef = db.collection(collectionName);
  const snapshot = await collectionRef.get();

  if (snapshot.empty) {
    console.log(`    Collection empty, nothing to delete`);
    return 0;
  }

  if (dryRun) {
    console.log(`    [DRY-RUN] Would delete ${snapshot.size} documents`);
    return snapshot.size;
  }

  // Delete in batches (500 per batch, Firestore limit)
  let deletedCount = 0;
  let batch = db.batch();
  let batchSize = 0;

  for (const doc of snapshot.docs) {
    batch.delete(doc.ref);
    batchSize++;

    if (batchSize >= 500) {
      await batch.commit();
      deletedCount += batchSize;
      console.log(`    Deleted ${deletedCount}/${snapshot.size} documents...`);
      batch = db.batch();
      batchSize = 0;
    }
  }

  // Commit remaining
  if (batchSize > 0) {
    await batch.commit();
    deletedCount += batchSize;
  }

  console.log(`    ✓ Deleted ${deletedCount} documents`);
  return deletedCount;
}

// Restore collection from backup
async function restoreCollection(
  db: admin.firestore.Firestore,
  collectionName: string,
  documents: Array<{ id: string; data: any }>,
  strategy: 'merge' | 'replace',
  dryRun: boolean
): Promise<number> {
  console.log(`  Restoring collection: ${collectionName}`);
  console.log(`    Documents: ${documents.length}`);
  console.log(`    Strategy: ${strategy}`);

  // Replace strategy: delete existing data first
  if (strategy === 'replace') {
    await deleteCollection(db, collectionName, dryRun);
  }

  if (dryRun) {
    console.log(`    [DRY-RUN] Would restore ${documents.length} documents`);
    return documents.length;
  }

  // Restore in batches (500 per batch, Firestore limit)
  let restoredCount = 0;
  let batch = db.batch();
  let batchSize = 0;

  for (const doc of documents) {
    const docRef = db.collection(collectionName).doc(doc.id);

    if (strategy === 'merge') {
      batch.set(docRef, doc.data, { merge: true });
    } else {
      batch.set(docRef, doc.data);
    }

    batchSize++;

    if (batchSize >= 500) {
      await batch.commit();
      restoredCount += batchSize;
      console.log(`    Restored ${restoredCount}/${documents.length} documents...`);
      batch = db.batch();
      batchSize = 0;
    }
  }

  // Commit remaining
  if (batchSize > 0) {
    await batch.commit();
    restoredCount += batchSize;
  }

  console.log(`    ✓ Restored ${restoredCount} documents`);
  return restoredCount;
}

// Main restore function
async function runRestore(config: Config): Promise<RestoreResult> {
  const startTime = Date.now();

  console.log('========================================');
  console.log('📦 Firestore Backup Restore');
  console.log('========================================');
  console.log(`File: ${config.filePath}`);
  console.log(`Environment: ${config.env}`);
  console.log(`Strategy: ${config.strategy}`);
  console.log(`Mode: ${config.dryRun ? 'DRY-RUN' : 'LIVE'}`);
  if (config.collections) {
    console.log(`Collections: ${config.collections.join(', ')}`);
  }
  console.log('========================================\n');

  // Safety check for replace strategy
  if (config.strategy === 'replace' && !config.dryRun && !config.confirm) {
    console.error('❌ Replace strategy requires --confirm flag');
    console.error('   This will DELETE existing data!');
    console.error('   Use --dry-run to preview changes first');
    process.exit(1);
  }

  // Load backup file
  console.log('Loading backup...\n');
  const backupData = loadBackupFile(config.filePath);

  // Verify environment match
  if (backupData.metadata.environment !== config.env) {
    console.warn(`⚠️  Environment mismatch:`);
    console.warn(`   Backup: ${backupData.metadata.environment}`);
    console.warn(`   Target: ${config.env}`);
    console.warn('   Proceeding anyway...\n');
  }

  // Initialize Firebase
  const app = initializeFirebase(config);
  const db = admin.firestore(app);

  try {
    // Filter collections if specified
    let collectionsToRestore = backupData.data.collections;
    if (config.collections) {
      collectionsToRestore = collectionsToRestore.filter((c) =>
        config.collections!.includes(c.name)
      );
      console.log(`\nFiltered to ${collectionsToRestore.length} collection(s)\n`);
    }

    if (collectionsToRestore.length === 0) {
      throw new Error('No collections to restore');
    }

    // Restore each collection
    console.log('Restoring collections...\n');
    let totalRestored = 0;
    const restoredCollections: string[] = [];

    for (const collection of collectionsToRestore) {
      const count = await restoreCollection(
        db,
        collection.name,
        collection.documents,
        config.strategy,
        config.dryRun
      );

      totalRestored += count;
      restoredCollections.push(collection.name);
    }

    // Success
    const duration = (Date.now() - startTime) / 1000;
    console.log('\n========================================');
    if (config.dryRun) {
      console.log('✅ Dry-run completed');
      console.log('   No changes made to database');
    } else {
      console.log('✅ Restore completed successfully');
    }
    console.log('========================================');
    console.log(`Duration: ${duration.toFixed(2)}s`);
    console.log(`Collections: ${restoredCollections.length}`);
    console.log(`Documents: ${totalRestored}`);
    console.log('========================================\n');

    return {
      success: true,
      restoredDocuments: totalRestored,
      collections: restoredCollections,
      duration,
      strategy: config.strategy,
    };
  } catch (error: any) {
    console.error('\n❌ Restore failed:', error.message);
    return {
      success: false,
      restoredDocuments: 0,
      collections: [],
      duration: (Date.now() - startTime) / 1000,
      strategy: config.strategy,
      error: error.message,
    };
  } finally {
    await app.delete();
  }
}

// Main entry point
async function main(): Promise<void> {
  try {
    const config = parseArgs();
    const result = await runRestore(config);

    // Output JSON for CI/CD
    console.log('JSON Output:');
    console.log(JSON.stringify(result, null, 2));

    // Exit with appropriate code
    process.exit(result.success ? 0 : 1);
  } catch (error: any) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

// Run if executed directly
if (require.main === module) {
  main();
}

export { runRestore, parseArgs };
