#!/usr/bin/env ts-node
/**
 * Firestore Backup Export Tool
 *
 * PURPOSE:
 * Automated daily backups of Firestore data to Cloud Storage with retention policy.
 * Supports full and incremental backups, compression, and backup verification.
 *
 * FEATURES:
 * - Full backup: Export all collections
 * - Incremental backup: Export only documents modified since last backup
 * - Compression: gzip compression for storage efficiency
 * - Cloud Storage upload: Automatic upload to GCS bucket
 * - Retention policy: Keep last 30 daily backups (configurable)
 * - Verification: Validate backup integrity
 * - Multi-environment: Supports staging and production
 *
 * USAGE:
 * ts-node tools/backup/export_firestore.ts --env=staging --type=full
 * ts-node tools/backup/export_firestore.ts --env=production --type=incremental
 *
 * REQUIREMENTS:
 * - Firebase service account with Firestore read permissions
 * - Cloud Storage bucket for backups
 * - Node.js 20+
 *
 * SCHEDULE:
 * - Daily full backup: 3am UTC
 * - Hourly incremental backup: Every hour (production only)
 *
 * OUTPUT:
 * backups/
 *   staging/
 *     2025-10-11-full-03h00m.json.gz
 *     2025-10-11-incremental-04h00m.json.gz
 *   production/
 *     2025-10-11-full-03h00m.json.gz
 */

import * as admin from 'firebase-admin';
import * as fs from 'fs';
import * as path from 'path';
import * as zlib from 'zlib';
import { promisify } from 'util';

const gzip = promisify(zlib.gzip);

// Configuration
interface Config {
  env: 'staging' | 'production';
  type: 'full' | 'incremental';
  outputDir: string;
  bucketName?: string;
  retentionDays: number;
  collections: string[];
}

// Backup metadata
interface BackupMetadata {
  timestamp: string;
  environment: string;
  type: 'full' | 'incremental';
  collections: string[];
  documentCount: number;
  sizeBytes: number;
  duration: number;
  lastBackupTimestamp?: string;
}

// Backup result
interface BackupResult {
  success: boolean;
  metadata: BackupMetadata;
  filePath: string;
  error?: string;
}

// Parse command line arguments
function parseArgs(): Config {
  const args = process.argv.slice(2);
  let env: 'staging' | 'production' = 'staging';
  let type: 'full' | 'incremental' = 'full';
  let outputDir = './backups';
  let retentionDays = 30;

  for (const arg of args) {
    if (arg.startsWith('--env=')) {
      const value = arg.split('=')[1];
      if (value === 'staging' || value === 'production') {
        env = value;
      }
    } else if (arg.startsWith('--type=')) {
      const value = arg.split('=')[1];
      if (value === 'full' || value === 'incremental') {
        type = value;
      }
    } else if (arg.startsWith('--output=')) {
      outputDir = arg.split('=')[1];
    } else if (arg.startsWith('--retention=')) {
      retentionDays = parseInt(arg.split('=')[1], 10);
    }
  }

  // Collections to back up
  const collections = [
    'companies',
    'users',
    'jobs',
    'assignments',
    'timeEntries',
    'clockEvents',
    'estimates',
    'invoices',
    'customers',
  ];

  return {
    env,
    type,
    outputDir,
    retentionDays,
    collections,
    bucketName: `${env}-backups-sierra-painting`,
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

// Get timestamp of last backup
async function getLastBackupTimestamp(
  db: admin.firestore.Firestore,
  env: string
): Promise<string | null> {
  try {
    const metadataDoc = await db
      .collection('_backups')
      .doc('metadata')
      .get();

    if (!metadataDoc.exists) {
      return null;
    }

    const data = metadataDoc.data();
    return data?.lastBackupTimestamp || null;
  } catch (error) {
    console.warn('No previous backup timestamp found');
    return null;
  }
}

// Update last backup timestamp
async function updateLastBackupTimestamp(
  db: admin.firestore.Firestore,
  timestamp: string
): Promise<void> {
  await db
    .collection('_backups')
    .doc('metadata')
    .set(
      {
        lastBackupTimestamp: timestamp,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
}

// Export collection to JSON
async function exportCollection(
  db: admin.firestore.Firestore,
  collectionName: string,
  type: 'full' | 'incremental',
  lastBackupTimestamp: string | null
): Promise<{ documents: any[]; count: number }> {
  console.log(`  Exporting collection: ${collectionName}`);

  let query: admin.firestore.Query = db.collection(collectionName);

  // For incremental backup, only export documents modified since last backup
  if (type === 'incremental' && lastBackupTimestamp) {
    const lastBackupDate = new Date(lastBackupTimestamp);
    query = query.where('updatedAt', '>', lastBackupDate);
    console.log(`    Incremental: filtering since ${lastBackupTimestamp}`);
  }

  const snapshot = await query.get();
  const documents: any[] = [];

  for (const doc of snapshot.docs) {
    documents.push({
      id: doc.id,
      data: doc.data(),
    });
  }

  console.log(`    Exported ${documents.length} documents`);
  return { documents, count: documents.length };
}

// Create backup file
async function createBackupFile(
  config: Config,
  backupData: any,
  metadata: BackupMetadata
): Promise<string> {
  // Ensure output directory exists
  const envDir = path.join(config.outputDir, config.env);
  if (!fs.existsSync(envDir)) {
    fs.mkdirSync(envDir, { recursive: true });
  }

  // Generate filename
  const timestamp = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
  const time = new Date()
    .toISOString()
    .split('T')[1]
    .split(':')
    .slice(0, 2)
    .join('h') + 'm'; // HHhMMm
  const filename = `${timestamp}-${config.type}-${time}.json`;
  const filePath = path.join(envDir, filename);

  // Write JSON to file
  const jsonData = JSON.stringify(
    {
      metadata,
      data: backupData,
    },
    null,
    2
  );

  fs.writeFileSync(filePath, jsonData, 'utf-8');
  console.log(`  Written to: ${filePath}`);

  // Compress with gzip
  const compressedPath = `${filePath}.gz`;
  const compressed = await gzip(jsonData);
  fs.writeFileSync(compressedPath, compressed);

  // Calculate size
  const stats = fs.statSync(compressedPath);
  metadata.sizeBytes = stats.size;

  // Delete uncompressed file
  fs.unlinkSync(filePath);

  console.log(`  Compressed: ${(stats.size / 1024 / 1024).toFixed(2)} MB`);
  return compressedPath;
}

// Upload to Cloud Storage (optional)
async function uploadToCloudStorage(
  config: Config,
  filePath: string
): Promise<void> {
  if (!config.bucketName) {
    console.log('  Skipping Cloud Storage upload (no bucket configured)');
    return;
  }

  try {
    const bucket = admin.storage().bucket(config.bucketName);
    const destination = path.basename(filePath);

    await bucket.upload(filePath, {
      destination: `${config.env}/${destination}`,
      metadata: {
        contentType: 'application/gzip',
        metadata: {
          environment: config.env,
          backupType: config.type,
          createdAt: new Date().toISOString(),
        },
      },
    });

    console.log(`  ✓ Uploaded to gs://${config.bucketName}/${config.env}/${destination}`);
  } catch (error: any) {
    console.warn(`  ⚠️  Cloud Storage upload failed: ${error.message}`);
    console.warn('  Backup file saved locally only');
  }
}

// Clean up old backups (retention policy)
async function cleanupOldBackups(
  config: Config
): Promise<number> {
  const envDir = path.join(config.outputDir, config.env);
  if (!fs.existsSync(envDir)) {
    return 0;
  }

  const files = fs.readdirSync(envDir);
  const backupFiles = files.filter((f) => f.endsWith('.json.gz'));

  // Sort by filename (timestamp)
  backupFiles.sort();

  // Calculate cutoff date
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - config.retentionDays);
  const cutoffStr = cutoffDate.toISOString().split('T')[0]; // YYYY-MM-DD

  // Delete old backups
  let deletedCount = 0;
  for (const file of backupFiles) {
    const fileDate = file.split('-').slice(0, 3).join('-'); // Extract YYYY-MM-DD
    if (fileDate < cutoffStr) {
      const filePath = path.join(envDir, file);
      fs.unlinkSync(filePath);
      console.log(`  Deleted old backup: ${file}`);
      deletedCount++;
    }
  }

  return deletedCount;
}

// Verify backup integrity
async function verifyBackup(filePath: string): Promise<boolean> {
  try {
    // Read compressed file
    const compressed = fs.readFileSync(filePath);

    // Decompress
    const decompressed = zlib.gunzipSync(compressed);

    // Parse JSON
    const data = JSON.parse(decompressed.toString('utf-8'));

    // Validate structure
    if (!data.metadata || !data.data) {
      throw new Error('Invalid backup structure');
    }

    // Validate metadata
    const requiredFields = [
      'timestamp',
      'environment',
      'type',
      'collections',
      'documentCount',
    ];
    for (const field of requiredFields) {
      if (!data.metadata[field]) {
        throw new Error(`Missing metadata field: ${field}`);
      }
    }

    // Validate document count
    let actualCount = 0;
    for (const collection of data.data.collections) {
      actualCount += collection.documents.length;
    }

    if (actualCount !== data.metadata.documentCount) {
      throw new Error(
        `Document count mismatch: expected ${data.metadata.documentCount}, found ${actualCount}`
      );
    }

    console.log('  ✓ Backup verification passed');
    return true;
  } catch (error: any) {
    console.error(`  ✗ Backup verification failed: ${error.message}`);
    return false;
  }
}

// Main backup function
async function runBackup(config: Config): Promise<BackupResult> {
  const startTime = Date.now();
  const timestamp = new Date().toISOString();

  console.log('========================================');
  console.log('📦 Firestore Backup Export');
  console.log('========================================');
  console.log(`Environment: ${config.env}`);
  console.log(`Type: ${config.type}`);
  console.log(`Timestamp: ${timestamp}`);
  console.log(`Collections: ${config.collections.length}`);
  console.log(`Retention: ${config.retentionDays} days`);
  console.log('========================================\n');

  // Initialize Firebase
  const app = initializeFirebase(config);
  const db = admin.firestore(app);

  try {
    // Get last backup timestamp for incremental backup
    let lastBackupTimestamp: string | null = null;
    if (config.type === 'incremental') {
      lastBackupTimestamp = await getLastBackupTimestamp(db, config.env);
      if (!lastBackupTimestamp) {
        console.warn('⚠️  No previous backup found, performing full backup instead');
        config.type = 'full';
      } else {
        console.log(`Last backup: ${lastBackupTimestamp}\n`);
      }
    }

    // Export all collections
    const backupData: any = { collections: [] };
    let totalDocuments = 0;

    console.log('Exporting collections...\n');
    for (const collectionName of config.collections) {
      const { documents, count } = await exportCollection(
        db,
        collectionName,
        config.type,
        lastBackupTimestamp
      );

      backupData.collections.push({
        name: collectionName,
        documents,
      });

      totalDocuments += count;
    }

    console.log(`\nTotal documents exported: ${totalDocuments}`);

    // Create metadata
    const duration = Date.now() - startTime;
    const metadata: BackupMetadata = {
      timestamp,
      environment: config.env,
      type: config.type,
      collections: config.collections,
      documentCount: totalDocuments,
      sizeBytes: 0, // Will be set after compression
      duration,
      lastBackupTimestamp: lastBackupTimestamp || undefined,
    };

    // Create backup file
    console.log('\nCreating backup file...');
    const filePath = await createBackupFile(config, backupData, metadata);

    // Verify backup
    console.log('\nVerifying backup...');
    const verified = await verifyBackup(filePath);
    if (!verified) {
      throw new Error('Backup verification failed');
    }

    // Upload to Cloud Storage
    console.log('\nUploading to Cloud Storage...');
    await uploadToCloudStorage(config, filePath);

    // Update last backup timestamp
    await updateLastBackupTimestamp(db, timestamp);

    // Clean up old backups
    console.log('\nCleaning up old backups...');
    const deletedCount = await cleanupOldBackups(config);
    console.log(`  Deleted ${deletedCount} old backup(s)`);

    // Success
    const elapsedSeconds = (Date.now() - startTime) / 1000;
    console.log('\n========================================');
    console.log('✅ Backup completed successfully');
    console.log('========================================');
    console.log(`Duration: ${elapsedSeconds.toFixed(2)}s`);
    console.log(`Documents: ${totalDocuments}`);
    console.log(`Size: ${(metadata.sizeBytes / 1024 / 1024).toFixed(2)} MB`);
    console.log(`File: ${filePath}`);
    console.log('========================================\n');

    return {
      success: true,
      metadata,
      filePath,
    };
  } catch (error: any) {
    console.error('\n❌ Backup failed:', error.message);
    return {
      success: false,
      metadata: {
        timestamp,
        environment: config.env,
        type: config.type,
        collections: config.collections,
        documentCount: 0,
        sizeBytes: 0,
        duration: Date.now() - startTime,
      },
      filePath: '',
      error: error.message,
    };
  } finally {
    await app.delete();
  }
}

// Main entry point
async function main(): Promise<void> {
  const config = parseArgs();

  const result = await runBackup(config);

  // Output JSON for CI/CD
  console.log('JSON Output:');
  console.log(JSON.stringify(result, null, 2));

  // Exit with appropriate code
  process.exit(result.success ? 0 : 1);
}

// Run if executed directly
if (require.main === module) {
  main();
}

export { runBackup, parseArgs };
