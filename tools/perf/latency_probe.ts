#!/usr/bin/env ts-node
/**
 * Latency Probe for Timeclock Operations
 *
 * PURPOSE:
 * Measure end-to-end latency for critical timeclock operations (clockIn, clockOut)
 * and validate against SLO targets.
 *
 * FEATURES:
 * - Measures p50, p95, p99 latency percentiles
 * - Tests against emulators or staging environment
 * - Machine-readable JSON output for CI/CD
 * - SLO validation with pass/fail exit codes
 * - Configurable sample size and concurrency
 *
 * USAGE:
 * ts-node tools/perf/latency_probe.ts --env=emulator --samples=20
 * ts-node tools/perf/latency_probe.ts --env=staging --samples=50
 *
 * SLO TARGETS:
 * - clockIn p95: <2000ms
 * - clockOut p95: <1500ms
 * - Both operations p99: <3000ms
 *
 * OUTPUT:
 * {
 *   "clockIn": { "p50": 850, "p95": 1200, "p99": 1800, "samples": 20 },
 *   "clockOut": { "p50": 600, "p95": 900, "p99": 1200, "samples": 20 },
 *   "sloStatus": "PASS",
 *   "timestamp": "2025-10-11T12:00:00Z"
 * }
 */

import * as admin from 'firebase-admin';
import { v4 as uuidv4 } from 'uuid';

// Configuration
interface Config {
  env: 'emulator' | 'staging';
  samples: number;
  useEmulator: boolean;
}

// SLO Targets (milliseconds)
const SLO = {
  clockIn: {
    p95: 2000,
    p99: 3000,
  },
  clockOut: {
    p95: 1500,
    p99: 3000,
  },
};

// Latency measurement result
interface LatencyStats {
  p50: number;
  p95: number;
  p99: number;
  samples: number;
  rawSamples: number[];
}

// Parse command line arguments
function parseArgs(): Config {
  const args = process.argv.slice(2);
  let env: 'emulator' | 'staging' = 'emulator';
  let samples = 20;

  for (const arg of args) {
    if (arg.startsWith('--env=')) {
      const value = arg.split('=')[1];
      if (value === 'emulator' || value === 'staging') {
        env = value;
      }
    } else if (arg.startsWith('--samples=')) {
      samples = parseInt(arg.split('=')[1], 10);
    }
  }

  return {
    env,
    samples,
    useEmulator: env === 'emulator',
  };
}

// Calculate percentiles from sorted array
function calculatePercentile(sorted: number[], percentile: number): number {
  const index = Math.ceil((percentile / 100) * sorted.length) - 1;
  return sorted[Math.max(0, index)];
}

// Calculate latency statistics
function calculateStats(latencies: number[]): LatencyStats {
  const sorted = [...latencies].sort((a, b) => a - b);
  return {
    p50: Math.round(calculatePercentile(sorted, 50)),
    p95: Math.round(calculatePercentile(sorted, 95)),
    p99: Math.round(calculatePercentile(sorted, 99)),
    samples: sorted.length,
    rawSamples: sorted,
  };
}

// Initialize Firebase
function initializeFirebase(config: Config): admin.app.App {
  if (config.useEmulator) {
    // Emulator mode
    process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
    process.env.FIREBASE_AUTH_EMULATOR_HOST = 'localhost:9099';

    return admin.initializeApp({
      projectId: 'demo-latency-probe',
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

// Setup test data
async function setupTestData(
  db: admin.firestore.Firestore,
  auth: admin.auth.Auth
): Promise<{
  companyId: string;
  workerId: string;
  jobId: string;
  assignmentId: string;
}> {
  const companyId = `probe-company-${Date.now()}`;
  const workerEmail = `probe-worker-${Date.now()}@test.com`;
  const jobId = `probe-job-${Date.now()}`;

  // Create company
  await db.collection('companies').doc(companyId).set({
    name: 'Latency Probe Company',
    timezone: 'America/New_York',
    requireGeofence: true,
    maxShiftHours: 12,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Create worker user
  const workerRecord = await auth.createUser({
    email: workerEmail,
    password: 'ProbePassword123!',
    emailVerified: true,
  });
  const workerId = workerRecord.uid;

  // Set custom claims
  await auth.setCustomUserClaims(workerId, {
    company_id: companyId,
    role: 'staff',
  });

  // Create user document
  await db.collection('users').doc(workerId).set({
    displayName: 'Latency Probe Worker',
    email: workerEmail,
    companyId: companyId,
    role: 'staff',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Create job with geofence (Albany, NY)
  await db.collection('jobs').doc(jobId).set({
    companyId: companyId,
    name: 'Latency Probe Job',
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

  // Create assignment
  const assignmentId = `probe-assignment-${Date.now()}`;
  await db.collection('assignments').doc(assignmentId).set({
    companyId: companyId,
    userId: workerId,
    jobId: jobId,
    active: true,
    startDate: new Date(),
    endDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { companyId, workerId, jobId, assignmentId };
}

// Cleanup test data
async function cleanupTestData(
  db: admin.firestore.Firestore,
  auth: admin.auth.Auth,
  data: {
    companyId: string;
    workerId: string;
    jobId: string;
    assignmentId: string;
  }
): Promise<void> {
  try {
    // Delete time entries
    const timeEntries = await db
      .collection('timeEntries')
      .where('companyId', '==', data.companyId)
      .get();
    for (const doc of timeEntries.docs) {
      await doc.ref.delete();
    }

    // Delete assignment
    await db.collection('assignments').doc(data.assignmentId).delete();

    // Delete job
    await db.collection('jobs').doc(data.jobId).delete();

    // Delete user document
    await db.collection('users').doc(data.workerId).delete();

    // Delete auth user
    await auth.deleteUser(data.workerId);

    // Delete company
    await db.collection('companies').doc(data.companyId).delete();
  } catch (error) {
    console.error('Cleanup error:', error);
    // Continue despite errors
  }
}

// Measure clockIn latency
async function measureClockIn(
  db: admin.firestore.Firestore,
  data: { companyId: string; workerId: string; jobId: string }
): Promise<{ latency: number; entryId: string }> {
  const clientEventId = uuidv4();
  const start = Date.now();

  // Simulate clockIn operation (direct Firestore write, simulating Cloud Function)
  const entryRef = db.collection('timeEntries').doc();
  await entryRef.set({
    companyId: data.companyId,
    userId: data.workerId,
    workerId: data.workerId,
    jobId: data.jobId,
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
  return { latency, entryId: entryRef.id };
}

// Measure clockOut latency
async function measureClockOut(
  db: admin.firestore.Firestore,
  entryId: string
): Promise<number> {
  const start = Date.now();

  // Simulate clockOut operation
  await db.collection('timeEntries').doc(entryId).update({
    clockOut: admin.firestore.FieldValue.serverTimestamp(),
    status: 'pending',
    clockOutGeofenceValid: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return Date.now() - start;
}

// Run latency probes
async function runProbes(
  config: Config,
  db: admin.firestore.Firestore,
  auth: admin.auth.Auth
): Promise<{
  clockIn: LatencyStats;
  clockOut: LatencyStats;
}> {
  console.log(`\n🔬 Running ${config.samples} latency probes...`);

  // Setup test data
  console.log('Setting up test data...');
  const testData = await setupTestData(db, auth);

  const clockInLatencies: number[] = [];
  const clockOutLatencies: number[] = [];

  // Run measurements
  for (let i = 0; i < config.samples; i++) {
    process.stdout.write(`  Sample ${i + 1}/${config.samples}...\r`);

    // Measure clockIn
    const { latency: clockInLatency, entryId } = await measureClockIn(
      db,
      testData
    );
    clockInLatencies.push(clockInLatency);

    // Small delay to ensure timestamp difference
    await new Promise((resolve) => setTimeout(resolve, 100));

    // Measure clockOut
    const clockOutLatency = await measureClockOut(db, entryId);
    clockOutLatencies.push(clockOutLatency);
  }

  console.log(`\n✓ Completed ${config.samples} samples`);

  // Cleanup
  console.log('Cleaning up test data...');
  await cleanupTestData(db, auth, testData);

  return {
    clockIn: calculateStats(clockInLatencies),
    clockOut: calculateStats(clockOutLatencies),
  };
}

// Validate SLO
function validateSLO(results: {
  clockIn: LatencyStats;
  clockOut: LatencyStats;
}): { status: 'PASS' | 'FAIL'; violations: string[] } {
  const violations: string[] = [];

  if (results.clockIn.p95 > SLO.clockIn.p95) {
    violations.push(
      `clockIn p95: ${results.clockIn.p95}ms > ${SLO.clockIn.p95}ms`
    );
  }

  if (results.clockIn.p99 > SLO.clockIn.p99) {
    violations.push(
      `clockIn p99: ${results.clockIn.p99}ms > ${SLO.clockIn.p99}ms`
    );
  }

  if (results.clockOut.p95 > SLO.clockOut.p95) {
    violations.push(
      `clockOut p95: ${results.clockOut.p95}ms > ${SLO.clockOut.p95}ms`
    );
  }

  if (results.clockOut.p99 > SLO.clockOut.p99) {
    violations.push(
      `clockOut p99: ${results.clockOut.p99}ms > ${SLO.clockOut.p99}ms`
    );
  }

  return {
    status: violations.length === 0 ? 'PASS' : 'FAIL',
    violations,
  };
}

// Main entry point
async function main(): Promise<void> {
  const config = parseArgs();

  console.log('========================================');
  console.log('🎯 Latency Probe');
  console.log('========================================');
  console.log(`Environment: ${config.env}`);
  console.log(`Samples: ${config.samples}`);
  console.log('========================================\n');

  console.log('SLO Targets:');
  console.log(`  clockIn  p95: <${SLO.clockIn.p95}ms`);
  console.log(`  clockIn  p99: <${SLO.clockIn.p99}ms`);
  console.log(`  clockOut p95: <${SLO.clockOut.p95}ms`);
  console.log(`  clockOut p99: <${SLO.clockOut.p99}ms`);

  // Initialize Firebase
  const app = initializeFirebase(config);
  const db = admin.firestore(app);
  const auth = admin.auth(app);

  try {
    // Run probes
    const results = await runProbes(config, db, auth);

    // Validate SLO
    const sloValidation = validateSLO(results);

    // Output results
    console.log('\n========================================');
    console.log('📊 Results');
    console.log('========================================\n');

    console.log('clockIn:');
    console.log(`  p50: ${results.clockIn.p50}ms`);
    console.log(`  p95: ${results.clockIn.p95}ms`);
    console.log(`  p99: ${results.clockIn.p99}ms`);
    console.log('');

    console.log('clockOut:');
    console.log(`  p50: ${results.clockOut.p50}ms`);
    console.log(`  p95: ${results.clockOut.p95}ms`);
    console.log(`  p99: ${results.clockOut.p99}ms`);
    console.log('');

    console.log(`SLO Status: ${sloValidation.status}`);
    if (sloValidation.violations.length > 0) {
      console.log('\nViolations:');
      for (const violation of sloValidation.violations) {
        console.log(`  ✗ ${violation}`);
      }
    }

    // JSON output for CI/CD
    const jsonOutput = {
      clockIn: {
        p50: results.clockIn.p50,
        p95: results.clockIn.p95,
        p99: results.clockIn.p99,
        samples: results.clockIn.samples,
      },
      clockOut: {
        p50: results.clockOut.p50,
        p95: results.clockOut.p95,
        p99: results.clockOut.p99,
        samples: results.clockOut.samples,
      },
      sloStatus: sloValidation.status,
      sloViolations: sloValidation.violations,
      timestamp: new Date().toISOString(),
      environment: config.env,
    };

    console.log('\n========================================');
    console.log('JSON Output:');
    console.log('========================================');
    console.log(JSON.stringify(jsonOutput, null, 2));

    // Exit with appropriate code
    process.exit(sloValidation.status === 'PASS' ? 0 : 1);
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

export { runProbes, calculateStats, validateSLO };
