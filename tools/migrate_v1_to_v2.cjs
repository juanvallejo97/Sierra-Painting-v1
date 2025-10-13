/**
 * Migration Script: Legacy Schema v1.x → Canonical Schema v2.0
 *
 * Version: 2.0 (Option B Stability Patch)
 * Last Updated: 2025-10-12
 *
 * Migrates Firestore documents to canonical v2.0 schemas:
 * - Users: Remove role/companyId/active from Firestore (kept in custom claims only)
 * - Jobs: Convert flat geofence to nested structure
 * - Assignments: Rename fields to canonical names
 * - TimeEntries: Rename workerId→userId, clockIn→clockInAt, etc.
 *
 * IMPORTANT:
 * - Run this script ONCE after deploying v2.0 code
 * - Script is idempotent (safe to run multiple times)
 * - Creates backups before migrating
 * - Dry-run mode available for testing
 *
 * Usage:
 *   node tools/migrate_v1_to_v2.cjs --project=sierra-painting-staging
 *   node tools/migrate_v1_to_v2.cjs --project=sierra-painting-staging --dry-run
 *   node tools/migrate_v1_to_v2.cjs --project=sierra-painting-prod --collection=jobs
 *
 * See: docs/schemas/README.md
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Parse command line arguments
const args = process.argv.slice(2);
const projectId = args.find(arg => arg.startsWith('--project='))?.split('=')[1];
const isDryRun = args.includes('--dry-run');
const targetCollection = args.find(arg => arg.startsWith('--collection='))?.split('=')[1];

if (!projectId) {
  console.error('❌ Error: --project argument required');
  console.error('Usage: node tools/migrate_v1_to_v2.cjs --project=sierra-painting-staging [--dry-run] [--collection=jobs]');
  process.exit(1);
}

// Initialize Firebase Admin
admin.initializeApp({ projectId });
const db = admin.firestore();

// Migration statistics
const stats = {
  users: { total: 0, migrated: 0, skipped: 0, errors: 0 },
  jobs: { total: 0, migrated: 0, skipped: 0, errors: 0 },
  assignments: { total: 0, migrated: 0, skipped: 0, errors: 0 },
  timeEntries: { total: 0, migrated: 0, skipped: 0, errors: 0 },
};

// Backup directory
const backupDir = path.join(__dirname, '../.backups', `migration-${Date.now()}`);

/**
 * Create backup of document before migration
 */
function backupDocument(collection, docId, data) {
  if (isDryRun) return;

  const collectionDir = path.join(backupDir, collection);
  if (!fs.existsSync(collectionDir)) {
    fs.mkdirSync(collectionDir, { recursive: true });
  }

  const filePath = path.join(collectionDir, `${docId}.json`);
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
}

/**
 * Migrate Users collection
 *
 * Changes:
 * - Remove companyId, role, active from Firestore (kept in custom claims)
 * - Add userId field (document ID)
 * - Ensure photoURL, createdAt, updatedAt exist
 */
async function migrateUsers() {
  console.log('\n📋 Migrating Users collection...');

  const snapshot = await db.collection('users').get();
  stats.users.total = snapshot.size;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const docId = doc.id;

    try {
      // Check if already migrated
      if (data.userId && !data.companyId && !data.role && !data.active) {
        stats.users.skipped++;
        continue;
      }

      // Backup original
      backupDocument('users', docId, data);

      // Build canonical user document
      const canonical = {
        userId: docId,
        displayName: data.displayName || data.name || 'Unknown User',
        email: data.email || `unknown-${docId}@example.com`,
        photoURL: data.photoURL || null,
        createdAt: data.createdAt || admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: data.updatedAt || admin.firestore.FieldValue.serverTimestamp(),
      };

      // Log migration
      console.log(`  ✅ Migrating user ${docId} (removed: companyId, role, active)`);

      if (!isDryRun) {
        await doc.ref.set(canonical, { merge: false });
      }

      stats.users.migrated++;
    } catch (error) {
      console.error(`  ❌ Error migrating user ${docId}:`, error.message);
      stats.users.errors++;
    }
  }

  console.log(`  📊 Users: ${stats.users.migrated} migrated, ${stats.users.skipped} skipped, ${stats.users.errors} errors`);
}

/**
 * Migrate Jobs collection
 *
 * Changes:
 * - Convert flat geofence (lat, lng, radiusM) to nested structure
 * - Handle legacy field names (latitude→lat, longitude→lng, radiusMeters→radiusM)
 * - Add jobId field
 * - Ensure updatedAt exists
 */
async function migrateJobs() {
  console.log('\n🏗️  Migrating Jobs collection...');

  const snapshot = await db.collection('jobs').get();
  stats.jobs.total = snapshot.size;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const docId = doc.id;

    try {
      // Check if already migrated (has nested geofence)
      if (data.geofence && typeof data.geofence === 'object' && data.geofence.lat) {
        stats.jobs.skipped++;
        continue;
      }

      // Backup original
      backupDocument('jobs', docId, data);

      // Extract geofence from various legacy formats
      let lat, lng, radiusM;

      if (data.geofence && typeof data.geofence === 'object') {
        // Nested but wrong field names
        lat = data.geofence.lat || data.geofence.latitude;
        lng = data.geofence.lng || data.geofence.longitude;
        radiusM = data.geofence.radiusM || data.geofence.radiusMeters || data.geofence.radius;
      } else {
        // Flat structure
        lat = data.lat || data.latitude;
        lng = data.lng || data.longitude;
        radiusM = data.radiusM || data.radiusMeters || data.radius;
      }

      if (!lat || !lng || !radiusM) {
        throw new Error(`Missing geofence data: lat=${lat}, lng=${lng}, radiusM=${radiusM}`);
      }

      // Build canonical job document
      const canonical = {
        jobId: data.jobId || data.id || docId,
        companyId: data.companyId,
        name: data.name,
        address: data.address || '',
        geofence: {
          lat: Number(lat),
          lng: Number(lng),
          radiusM: Number(radiusM),
        },
        active: data.active !== undefined ? data.active : true,
        createdAt: data.createdAt || admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: data.updatedAt || admin.firestore.FieldValue.serverTimestamp(),
      };

      console.log(`  ✅ Migrating job ${docId} (nested geofence: ${lat}, ${lng}, ${radiusM}m)`);

      if (!isDryRun) {
        await doc.ref.set(canonical, { merge: false });
      }

      stats.jobs.migrated++;
    } catch (error) {
      console.error(`  ❌ Error migrating job ${docId}:`, error.message);
      stats.jobs.errors++;
    }
  }

  console.log(`  📊 Jobs: ${stats.jobs.migrated} migrated, ${stats.jobs.skipped} skipped, ${stats.jobs.errors} errors`);
}

/**
 * Migrate Assignments collection
 *
 * Changes:
 * - Rename id → assignmentId
 * - Rename assignedAt → createdAt
 * - Add updatedAt if missing
 */
async function migrateAssignments() {
  console.log('\n🔗 Migrating Assignments collection...');

  const snapshot = await db.collection('assignments').get();
  stats.assignments.total = snapshot.size;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const docId = doc.id;

    try {
      // Check if already migrated
      if (data.assignmentId && !data.id && data.createdAt && !data.assignedAt) {
        stats.assignments.skipped++;
        continue;
      }

      // Backup original
      backupDocument('assignments', docId, data);

      // Build canonical assignment document
      const canonical = {
        assignmentId: data.assignmentId || data.id || docId,
        companyId: data.companyId,
        userId: data.userId,
        jobId: data.jobId,
        active: data.active !== undefined ? data.active : true,
        createdAt: data.createdAt || data.assignedAt || admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: data.updatedAt || data.createdAt || data.assignedAt || admin.firestore.FieldValue.serverTimestamp(),
      };

      console.log(`  ✅ Migrating assignment ${docId}`);

      if (!isDryRun) {
        await doc.ref.set(canonical, { merge: false });
      }

      stats.assignments.migrated++;
    } catch (error) {
      console.error(`  ❌ Error migrating assignment ${docId}:`, error.message);
      stats.assignments.errors++;
    }
  }

  console.log(`  📊 Assignments: ${stats.assignments.migrated} migrated, ${stats.assignments.skipped} skipped, ${stats.assignments.errors} errors`);
}

/**
 * Migrate TimeEntries collection
 *
 * Changes:
 * - Rename workerId → userId
 * - Rename clockIn → clockInAt
 * - Rename clockOut → clockOutAt
 * - Split location → clockInLocation/clockOutLocation
 * - Split geofenceValid → clockInGeofenceValid/clockOutGeofenceValid
 */
async function migrateTimeEntries() {
  console.log('\n⏰ Migrating TimeEntries collection...');

  const snapshot = await db.collection('time_entries').get();
  stats.timeEntries.total = snapshot.size;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const docId = doc.id;

    try {
      // Check if already migrated
      if (data.userId && data.clockInAt && !data.workerId && !data.clockIn) {
        stats.timeEntries.skipped++;
        continue;
      }

      // Backup original
      backupDocument('time_entries', docId, data);

      // Build canonical time entry document
      const canonical = {
        entryId: data.entryId || data.id || docId,
        companyId: data.companyId,
        userId: data.userId || data.workerId,
        jobId: data.jobId,
        clockInAt: data.clockInAt || data.clockIn,
        clockInLocation: data.clockInLocation || data.location,
        clockInGeofenceValid: data.clockInGeofenceValid ?? data.geofenceValid ?? false,
        clockOutAt: data.clockOutAt || data.clockOut || null,
        clockOutLocation: data.clockOutLocation || null,
        clockOutGeofenceValid: data.clockOutGeofenceValid ?? null,
        notes: data.notes || null,
        createdAt: data.createdAt || admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: data.updatedAt || data.createdAt || admin.firestore.FieldValue.serverTimestamp(),
      };

      console.log(`  ✅ Migrating time entry ${docId} (workerId→userId, clockIn→clockInAt)`);

      if (!isDryRun) {
        await doc.ref.set(canonical, { merge: false });
      }

      stats.timeEntries.migrated++;
    } catch (error) {
      console.error(`  ❌ Error migrating time entry ${docId}:`, error.message);
      stats.timeEntries.errors++;
    }
  }

  console.log(`  📊 TimeEntries: ${stats.timeEntries.migrated} migrated, ${stats.timeEntries.skipped} skipped, ${stats.timeEntries.errors} errors`);
}

/**
 * Main migration function
 */
async function migrate() {
  console.log('🚀 Starting Firestore Migration: v1.x → v2.0 (Canonical Schema)');
  console.log(`   Project: ${projectId}`);
  console.log(`   Mode: ${isDryRun ? 'DRY RUN (no changes)' : 'LIVE (will modify data)'}`);
  console.log(`   Backup Dir: ${backupDir}`);
  console.log('');

  if (!isDryRun) {
    console.log('⚠️  WARNING: This will modify your Firestore data!');
    console.log('   Press Ctrl+C within 5 seconds to cancel...\n');
    await new Promise(resolve => setTimeout(resolve, 5000));
  }

  const startTime = Date.now();

  try {
    // Run migrations
    if (!targetCollection || targetCollection === 'users') {
      await migrateUsers();
    }

    if (!targetCollection || targetCollection === 'jobs') {
      await migrateJobs();
    }

    if (!targetCollection || targetCollection === 'assignments') {
      await migrateAssignments();
    }

    if (!targetCollection || targetCollection === 'time_entries') {
      await migrateTimeEntries();
    }

    const duration = ((Date.now() - startTime) / 1000).toFixed(2);

    // Print summary
    console.log('\n' + '='.repeat(70));
    console.log('✅ MIGRATION COMPLETE');
    console.log('='.repeat(70));
    console.log(`   Duration: ${duration}s`);
    console.log(`   Mode: ${isDryRun ? 'DRY RUN' : 'LIVE'}`);
    console.log('');
    console.log('📊 Summary:');
    console.log(`   Users:       ${stats.users.migrated} migrated, ${stats.users.skipped} skipped, ${stats.users.errors} errors`);
    console.log(`   Jobs:        ${stats.jobs.migrated} migrated, ${stats.jobs.skipped} skipped, ${stats.jobs.errors} errors`);
    console.log(`   Assignments: ${stats.assignments.migrated} migrated, ${stats.assignments.skipped} skipped, ${stats.assignments.errors} errors`);
    console.log(`   TimeEntries: ${stats.timeEntries.migrated} migrated, ${stats.timeEntries.skipped} skipped, ${stats.timeEntries.errors} errors`);
    console.log('');

    if (!isDryRun) {
      console.log(`💾 Backups saved to: ${backupDir}`);
      console.log('');
    }

    console.log('📝 Next Steps:');
    console.log('   1. Verify data in Firestore console');
    console.log('   2. Test Clock In/Out functionality');
    console.log('   3. Remove legacy fallback code after 2025-10-26');
    console.log('   4. Delete backup files after verification');

    process.exit(0);
  } catch (error) {
    console.error('\n❌ MIGRATION FAILED:', error);
    console.error('   Backups preserved at:', backupDir);
    process.exit(1);
  }
}

// Run migration
migrate();
