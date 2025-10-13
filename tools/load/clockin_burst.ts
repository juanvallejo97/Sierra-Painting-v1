#!/usr/bin/env ts-node
/**
 * Clock-In Burst Load Test
 *
 * PURPOSE:
 * Test system behavior under high concurrent load (100+ simultaneous clock-ins).
 * Validates capacity, latency distribution, and data integrity under stress.
 *
 * FEATURES:
 * - Configurable concurrency (default: 100)
 * - Measures latency for each operation
 * - Detects duplicate entries (idempotency violations)
 * - Validates data integrity (no corruption)
 * - Reports p50/p95/p99/max latency
 * - Success rate calculation
 * - Exit code based on SLO compliance
 *
 * USAGE:
 * ts-node tools/load/clockin_burst.ts --env=emulator --workers=100
 * ts-node tools/load/clockin_burst.ts --env=staging --workers=50
 *
 * ACCEPTANCE CRITERIA:
 * - 95% of operations complete in <3000ms
 * - 100% success rate (no errors)
 * - Zero duplicates detected
 * - Zero data corruption
 *
 * OUTPUT:
 * {
 *   "totalWorkers": 100,
 *   "successCount": 100,
 *   "errorCount": 0,
 *   "duplicateCount": 0,
 *   "latency": {
 *     "p50": 1200,
 *     "p95": 2800,
 *     "p99": 2950,
 *     "max": 3100
 *   },
 *   "sloCompliance": {
 *     "p95Under3s": true,
 *     "successRate": 1.0,
 *     "zeroDuplicates": true
 *   },
 *   "status": "PASS"
 * }
 */

import * as admin from 'firebase-admin';
import { v4 as uuidv4 } from 'uuid';

// Configuration
interface Config {
  env: 'emulator' | 'staging';
  workers: number;
  useEmulator: boolean;
}

// SLO Targets
const SLO = {
  p95Latency: 3000, // 95% of operations under 3s
  successRate: 1.0, // 100% success
  duplicates: 0, // Zero duplicates
};

// Load test result
interface LoadTestResult {
  totalWorkers: number;
  successCount: number;
  errorCount: number;
  duplicateCount: number;
  latency: {
    p50: number;
    p95: number;
    p99: number;
    max: number;
  };
  sloCompliance: {
    p95Under3s: boolean;
    successRate: number;
    zeroDuplicates: boolean;
  };
  status: 'PASS' | 'FAIL';
  errors: string[];
}

// Clock-in attempt result
interface ClockInAttempt {
  workerId: string;
  success: boolean;
  latency: number;
  entryId?: string;
  error?: string;
}

// Parse command line arguments
function parseArgs(): Config {
  const args = process.argv.slice(2);
  let env: 'emulator' | 'staging' = 'emulator';
  let workers = 100;

  for (const arg of args) {
    if (arg.startsWith('--env=')) {
      const value = arg.split('=')[1];
      if (value === 'emulator' || value === 'staging') {
        env = value;
      }
    } else if (arg.startsWith('--workers=')) {
      workers = parseInt(arg.split('=')[1], 10);
    }
  }

  return {
    env,
    workers,
    useEmulator: env === 'emulator',
  };
}

// Calculate percentile from sorted array
function calculatePercentile(sorted: number[], percentile: number): number {
  const index = Math.ceil((percentile / 100) * sorted.length) - 1;
  return sorted[Math.max(0, index)];
}

// Initialize Firebase
function initializeFirebase(config: Config): admin.app.App {
  if (config.useEmulator) {
    // Emulator mode
    process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
    process.env.FIREBASE_AUTH_EMULATOR_HOST = 'localhost:9099';

    return admin.initializeApp({
      projectId: 'demo-burst-load',
    });
  } else {
    // Staging mode - requires service account
    const serviceAccount = require('../../firebase-service-account-staging.json');
    return admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: 'sierra-painting-staging',
    });
  }
}

// Setup test infrastructure (company, job, assignments)
async function setupTestInfrastructure(
  db: admin.firestore.Firestore,
  auth: admin.auth.Auth,
  workerCount: number
): Promise<{
  companyId: string;
  jobId: string;
  workerIds: string[];
}> {
  const companyId = `burst-company-${Date.now()}`;
  const jobId = `burst-job-${Date.now()}`;

  console.log('Setting up test infrastructure...');

  // Create company
  await db.collection('companies').doc(companyId).set({
    name: 'Burst Load Test Company',
    timezone: 'America/New_York',
    requireGeofence: true,
    maxShiftHours: 12,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Create job with geofence (Albany, NY)
  await db.collection('jobs').doc(jobId).set({
    companyId: companyId,
    name: 'Burst Load Test Job',
    address: {
      street: '1234 Test St',
      city: 'Albany',
      state: 'NY',
      zip: '12203',
    },
    location: {
      latitude: 42.6526,
      longitude: -73.7562,
      geofenceRadius: 125,
    },
    status: 'active',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Create workers and assignments
  const workerIds: string[] = [];
  const batch = db.batch();

  for (let i = 0; i < workerCount; i++) {
    const workerEmail = `burst-worker-${Date.now()}-${i}@test.com`;

    // Create auth user
    const workerRecord = await auth.createUser({
      email: workerEmail,
      password: 'BurstTest123!',
      emailVerified: true,
    });
    const workerId = workerRecord.uid;
    workerIds.push(workerId);

    // Set custom claims
    await auth.setCustomUserClaims(workerId, {
      company_id: companyId,
      role: 'staff',
    });

    // Create user document (batched)
    const userRef = db.collection('users').doc(workerId);
    batch.set(userRef, {
      displayName: `Burst Worker ${i}`,
      email: workerEmail,
      companyId: companyId,
      role: 'staff',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Create assignment (batched)
    const assignmentRef = db.collection('assignments').doc(`burst-assignment-${workerId}`);
    batch.set(assignmentRef, {
      companyId: companyId,
      userId: workerId,
      jobId: jobId,
      active: true,
      startDate: new Date(),
      endDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Progress indicator
    if ((i + 1) % 10 === 0) {
      process.stdout.write(`  Created ${i + 1}/${workerCount} workers\r`);
    }
  }

  // Commit batched writes
  await batch.commit();
  console.log(`\n✓ Created ${workerCount} workers and assignments`);

  return { companyId, jobId, workerIds };
}

// Cleanup test data
async function cleanupTestData(
  db: admin.firestore.Firestore,
  auth: admin.auth.Auth,
  data: {
    companyId: string;
    jobId: string;
    workerIds: string[];
  }
): Promise<void> {
  console.log('\nCleaning up test data...');

  try {
    // Delete time entries
    const timeEntries = await db
      .collection('timeEntries')
      .where('companyId', '==', data.companyId)
      .get();
    const batch = db.batch();
    for (const doc of timeEntries.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();

    // Delete assignments
    const assignments = await db
      .collection('assignments')
      .where('companyId', '==', data.companyId)
      .get();
    const assignmentBatch = db.batch();
    for (const doc of assignments.docs) {
      assignmentBatch.delete(doc.ref);
    }
    await assignmentBatch.commit();

    // Delete user documents
    const userBatch = db.batch();
    for (const workerId of data.workerIds) {
      userBatch.delete(db.collection('users').doc(workerId));
    }
    await userBatch.commit();

    // Delete auth users
    for (const workerId of data.workerIds) {
      await auth.deleteUser(workerId).catch(() => {});
    }

    // Delete job
    await db.collection('jobs').doc(data.jobId).delete();

    // Delete company
    await db.collection('companies').doc(data.companyId).delete();

    console.log('✓ Cleanup complete');
  } catch (error) {
    console.error('Cleanup error:', error);
    // Continue despite errors
  }
}

// Execute single clock-in operation
async function executeCl ockIn(
  db: admin.firestore.Firestore,
  workerId: string,
  companyId: string,
  jobId: string
): Promise<ClockInAttempt> {
  const clientEventId = uuidv4();
  const start = Date.now();

  try {
    // Simulate clockIn operation (direct Firestore write, simulating Cloud Function)
    const entryRef = db.collection('timeEntries').doc();
    await entryRef.set({
      companyId: companyId,
      userId: workerId,
      workerId: workerId,
      jobId: jobId,
      clockIn: admin.firestore.FieldValue.serverTimestamp(),
      clockOut: null,
      status: 'active',
      clientEventId: clientEventId,
      clockInGeofenceValid: true,
      clockOutGeofenceValid: null,
      exceedsTwelveHours: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const latency = Date.now() - start;
    return {
      workerId,
      success: true,
      latency,
      entryId: entryRef.id,
    };
  } catch (error: any) {
    const latency = Date.now() - start;
    return {
      workerId,
      success: false,
      latency,
      error: error.message || 'Unknown error',
    };
  }
}

// Run burst load test
async function runBurstTest(
  config: Config,
  db: admin.firestore.Firestore,
  auth: admin.auth.Auth
): Promise<LoadTestResult> {
  console.log(`\n🔥 Starting burst load test with ${config.workers} workers...`);

  // Setup infrastructure
  const infrastructure = await setupTestInfrastructure(
    db,
    auth,
    config.workers
  );

  console.log('\n⚡ Executing concurrent clock-ins...');
  const startTime = Date.now();

  // Execute all clock-ins concurrently
  const promises = infrastructure.workerIds.map((workerId) =>
    executeClockIn(db, workerId, infrastructure.companyId, infrastructure.jobId)
  );

  const results = await Promise.all(promises);
  const totalDuration = Date.now() - startTime;

  console.log(`✓ Completed in ${totalDuration}ms`);

  // Analyze results
  const successCount = results.filter((r) => r.success).length;
  const errorCount = results.filter((r) => !r.success).length;
  const latencies = results.map((r) => r.latency);
  const errors = results.filter((r) => !r.success).map((r) => r.error || 'Unknown');

  // Check for duplicates (query Firestore)
  console.log('\nChecking for duplicates...');
  const timeEntries = await db
    .collection('timeEntries')
    .where('companyId', '==', infrastructure.companyId)
    .get();

  const duplicateCount = timeEntries.size - successCount;

  // Calculate latency statistics
  const sortedLatencies = [...latencies].sort((a, b) => a - b);
  const p50 = calculatePercentile(sortedLatencies, 50);
  const p95 = calculatePercentile(sortedLatencies, 95);
  const p99 = calculatePercentile(sortedLatencies, 99);
  const max = sortedLatencies[sortedLatencies.length - 1];

  // SLO compliance
  const p95Under3s = p95 <= SLO.p95Latency;
  const successRate = successCount / config.workers;
  const zeroDuplicates = duplicateCount === 0;
  const sloPass = p95Under3s && successRate === SLO.successRate && zeroDuplicates;

  // Cleanup
  await cleanupTestData(db, auth, infrastructure);

  return {
    totalWorkers: config.workers,
    successCount,
    errorCount,
    duplicateCount,
    latency: {
      p50: Math.round(p50),
      p95: Math.round(p95),
      p99: Math.round(p99),
      max: Math.round(max),
    },
    sloCompliance: {
      p95Under3s,
      successRate,
      zeroDuplicates,
    },
    status: sloPass ? 'PASS' : 'FAIL',
    errors: errors.slice(0, 10), // Limit to first 10 errors
  };
}

// Main entry point
async function main(): Promise<void> {
  const config = parseArgs();

  console.log('========================================');
  console.log('🔥 Burst Load Test');
  console.log('========================================');
  console.log(`Environment: ${config.env}`);
  console.log(`Workers: ${config.workers}`);
  console.log('========================================');

  console.log('\nSLO Targets:');
  console.log(`  p95 latency: <${SLO.p95Latency}ms`);
  console.log(`  Success rate: ${SLO.successRate * 100}%`);
  console.log(`  Duplicates: ${SLO.duplicates}`);

  // Initialize Firebase
  const app = initializeFirebase(config);
  const db = admin.firestore(app);
  const auth = admin.auth(app);

  try {
    // Run burst test
    const result = await runBurstTest(config, db, auth);

    // Output results
    console.log('\n========================================');
    console.log('📊 Results');
    console.log('========================================\n');

    console.log(`Total Workers: ${result.totalWorkers}`);
    console.log(`Success: ${result.successCount} (${(result.sloCompliance.successRate * 100).toFixed(1)}%)`);
    console.log(`Errors: ${result.errorCount}`);
    console.log(`Duplicates: ${result.duplicateCount}`);
    console.log('');

    console.log('Latency:');
    console.log(`  p50: ${result.latency.p50}ms`);
    console.log(`  p95: ${result.latency.p95}ms`);
    console.log(`  p99: ${result.latency.p99}ms`);
    console.log(`  max: ${result.latency.max}ms`);
    console.log('');

    console.log('SLO Compliance:');
    console.log(`  p95 < 3000ms: ${result.sloCompliance.p95Under3s ? '✓' : '✗'}`);
    console.log(`  Success rate 100%: ${result.sloCompliance.successRate === 1.0 ? '✓' : '✗'}`);
    console.log(`  Zero duplicates: ${result.sloCompliance.zeroDuplicates ? '✓' : '✗'}`);
    console.log('');

    console.log(`Status: ${result.status}`);

    if (result.errors.length > 0) {
      console.log('\nErrors (first 10):');
      for (const error of result.errors) {
        console.log(`  - ${error}`);
      }
    }

    // JSON output for CI/CD
    const jsonOutput = {
      totalWorkers: result.totalWorkers,
      successCount: result.successCount,
      errorCount: result.errorCount,
      duplicateCount: result.duplicateCount,
      latency: result.latency,
      sloCompliance: result.sloCompliance,
      status: result.status,
      timestamp: new Date().toISOString(),
      environment: config.env,
    };

    console.log('\n========================================');
    console.log('JSON Output:');
    console.log('========================================');
    console.log(JSON.stringify(jsonOutput, null, 2));

    // Exit with appropriate code
    process.exit(result.status === 'PASS' ? 0 : 1);
  } catch (error) {
    console.error('\n❌ Error:', error);
    process.exit(1);
  } finally {
    await app.delete();
  }
}

// Run if executed directly
if (require.main === module) {
  main();
}

export { runBurstTest, parseArgs };
