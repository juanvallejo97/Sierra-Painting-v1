/**
 * Firestore Rules Security Tests - time_entries Collection
 *
 * PURPOSE:
 * Critical security boundary tests for the canonical time_entries collection.
 * Validates security findings from Security Patch Analysis.
 *
 * COVERAGE:
 * - Cross-company data isolation (prevent company A from accessing company B's entries)
 * - Immutable field enforcement (companyId, userId, clockInAt cannot be changed)
 * - Nested GeoPoint tampering (clockInLocation, clockOutLocation)
 * - Function-write only enforcement (clients cannot create/update/delete)
 *
 * REFERENCES:
 * - Security Analysis Finding C2: No Rules tests for cross-company isolation
 * - Security Analysis Finding H3: No immutable field tests
 * - Firestore Rules: firestore.rules:243-267 (time_entries rules)
 */

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import * as fs from 'fs';
import * as path from 'path';

// Only run if Firestore emulator is active
const RUN_RULES = !!process.env.FIRESTORE_EMULATOR_HOST;

if (!RUN_RULES) {
  test('time_entries security tests skipped (FIRESTORE_EMULATOR_HOST not set)', () => {
    expect(true).toBe(true);
  });
} else {

let testEnv: RulesTestEnvironment;

// Test companies
const COMPANY_A = 'company-a';
const COMPANY_B = 'company-b';

// Test users
const ADMIN_A_UID = 'admin-a';
const WORKER_A_UID = 'worker-a';
const WORKER_B_UID = 'worker-b';

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-time-entries-security',
    firestore: {
      host: 'localhost',
      port: 8080,
      rules: fs.readFileSync(
        path.resolve(__dirname, '../../../firestore.rules'),
        'utf8'
      ),
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

// ============================================================================
// CROSS-COMPANY ISOLATION (Security Analysis Finding C2)
// ============================================================================
describe('time_entries - Cross-Company Isolation', () => {
  beforeEach(async () => {
    // Create time entry for Company A
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('time_entries').doc('entry-a').set({
        companyId: COMPANY_A,
        userId: WORKER_A_UID,
        jobId: 'job-a',
        clockInAt: new Date('2025-10-12T08:00:00Z'),
        clockInLocation: { latitude: 40.7128, longitude: -74.0060 },
        clockInGeofenceValid: true,
        clockOutAt: null,
        clockOutLocation: null,
        clockOutGeofenceValid: null,
        notes: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      });
    });

    // Create time entry for Company B
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('time_entries').doc('entry-b').set({
        companyId: COMPANY_B,
        userId: WORKER_B_UID,
        jobId: 'job-b',
        clockInAt: new Date('2025-10-12T08:00:00Z'),
        clockInLocation: { latitude: 34.0522, longitude: -118.2437 },
        clockInGeofenceValid: true,
        clockOutAt: null,
        clockOutLocation: null,
        clockOutGeofenceValid: null,
        notes: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      });
    });
  });

  test('Worker from Company A cannot read Company B time entry', async () => {
    const workerA = testEnv.authenticatedContext(WORKER_A_UID, {
      company_id: COMPANY_A,
      companyId: COMPANY_A,
      role: 'staff',
    });

    await assertFails(
      workerA.firestore().collection('time_entries').doc('entry-b').get()
    );
  });

  test('Admin from Company A cannot read Company B time entry', async () => {
    const adminA = testEnv.authenticatedContext(ADMIN_A_UID, {
      company_id: COMPANY_A,
      companyId: COMPANY_A,
      role: 'admin',
    });

    await assertFails(
      adminA.firestore().collection('time_entries').doc('entry-b').get()
    );
  });

  test('Worker from Company A can read their own Company A time entry', async () => {
    const workerA = testEnv.authenticatedContext(WORKER_A_UID, {
      company_id: COMPANY_A,
      companyId: COMPANY_A,
      role: 'staff',
    });

    await assertSucceeds(
      workerA.firestore().collection('time_entries').doc('entry-a').get()
    );
  });

  test('Admin from Company A can read Company A time entries', async () => {
    const adminA = testEnv.authenticatedContext(ADMIN_A_UID, {
      company_id: COMPANY_A,
      companyId: COMPANY_A,
      role: 'admin',
    });

    await assertSucceeds(
      adminA.firestore().collection('time_entries')
        .where('companyId', '==', COMPANY_A)
        .get()
    );
  });

  test('Query for Company B entries from Company A context returns empty', async () => {
    const adminA = testEnv.authenticatedContext(ADMIN_A_UID, {
      company_id: COMPANY_A,
      companyId: COMPANY_A,
      role: 'admin',
    });

    // This should fail at the Rules level (no reads allowed for other companies)
    await assertFails(
      adminA.firestore().collection('time_entries')
        .where('companyId', '==', COMPANY_B)
        .get()
    );
  });
});

// ============================================================================
// FUNCTION-WRITE ONLY ENFORCEMENT
// ============================================================================
describe('time_entries - Function-Write Only', () => {
  test('Worker cannot create time entry directly', async () => {
    const worker = testEnv.authenticatedContext(WORKER_A_UID, {
      company_id: COMPANY_A,
      companyId: COMPANY_A,
      role: 'staff',
    });

    await assertFails(
      worker.firestore().collection('time_entries').add({
        companyId: COMPANY_A,
        userId: WORKER_A_UID,
        jobId: 'job-a',
        clockInAt: new Date(),
        clockInLocation: { latitude: 40.7128, longitude: -74.0060 },
        clockInGeofenceValid: true,
        clockOutAt: null,
      })
    );
  });

  test('Admin cannot create time entry directly', async () => {
    const admin = testEnv.authenticatedContext(ADMIN_A_UID, {
      company_id: COMPANY_A,
      companyId: COMPANY_A,
      role: 'admin',
    });

    await assertFails(
      admin.firestore().collection('time_entries').add({
        companyId: COMPANY_A,
        userId: WORKER_A_UID,
        jobId: 'job-a',
        clockInAt: new Date(),
        clockInLocation: { latitude: 40.7128, longitude: -74.0060 },
        clockInGeofenceValid: true,
        clockOutAt: null,
      })
    );
  });

  test('Worker cannot update their own time entry', async () => {
    // Setup: Create time entry
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('time_entries').doc('entry-1').set({
        companyId: COMPANY_A,
        userId: WORKER_A_UID,
        jobId: 'job-a',
        clockInAt: new Date('2025-10-12T08:00:00Z'),
        clockInLocation: { latitude: 40.7128, longitude: -74.0060 },
        clockInGeofenceValid: true,
        clockOutAt: null,
        clockOutLocation: null,
        clockOutGeofenceValid: null,
        notes: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      });
    });

    const worker = testEnv.authenticatedContext(WORKER_A_UID, {
      company_id: COMPANY_A,
      companyId: COMPANY_A,
      role: 'staff',
    });

    await assertFails(
      worker.firestore().collection('time_entries').doc('entry-1').update({
        clockOutAt: new Date(),
      })
    );
  });

  test('Admin cannot update time entry directly', async () => {
    // Setup: Create time entry
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('time_entries').doc('entry-2').set({
        companyId: COMPANY_A,
        userId: WORKER_A_UID,
        jobId: 'job-a',
        clockInAt: new Date('2025-10-12T08:00:00Z'),
        clockInLocation: { latitude: 40.7128, longitude: -74.0060 },
        clockInGeofenceValid: true,
        clockOutAt: null,
        clockOutLocation: null,
        clockOutGeofenceValid: null,
        notes: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      });
    });

    const admin = testEnv.authenticatedContext(ADMIN_A_UID, {
      company_id: COMPANY_A,
      companyId: COMPANY_A,
      role: 'admin',
    });

    await assertFails(
      admin.firestore().collection('time_entries').doc('entry-2').update({
        notes: 'Admin note',
      })
    );
  });

  test('Worker cannot delete their time entry', async () => {
    // Setup: Create time entry
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('time_entries').doc('entry-3').set({
        companyId: COMPANY_A,
        userId: WORKER_A_UID,
        jobId: 'job-a',
        clockInAt: new Date('2025-10-12T08:00:00Z'),
        clockInLocation: { latitude: 40.7128, longitude: -74.0060 },
        clockInGeofenceValid: true,
        clockOutAt: null,
        createdAt: new Date(),
      });
    });

    const worker = testEnv.authenticatedContext(WORKER_A_UID, {
      company_id: COMPANY_A,
      companyId: COMPANY_A,
      role: 'staff',
    });

    await assertFails(
      worker.firestore().collection('time_entries').doc('entry-3').delete()
    );
  });

  test('Admin cannot delete time entry', async () => {
    // Setup: Create time entry
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('time_entries').doc('entry-4').set({
        companyId: COMPANY_A,
        userId: WORKER_A_UID,
        jobId: 'job-a',
        clockInAt: new Date('2025-10-12T08:00:00Z'),
        clockInLocation: { latitude: 40.7128, longitude: -74.0060 },
        clockInGeofenceValid: true,
        clockOutAt: null,
        createdAt: new Date(),
      });
    });

    const admin = testEnv.authenticatedContext(ADMIN_A_UID, {
      company_id: COMPANY_A,
      companyId: COMPANY_A,
      role: 'admin',
    });

    await assertFails(
      admin.firestore().collection('time_entries').doc('entry-4').delete()
    );
  });
});

// ============================================================================
// IMMUTABLE FIELDS ENFORCEMENT (Security Analysis Finding H3)
// ============================================================================
describe('time_entries - Immutable Fields', () => {
  beforeEach(async () => {
    // Create time entry with initial values
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('time_entries').doc('entry-imm').set({
        companyId: COMPANY_A,
        userId: WORKER_A_UID,
        jobId: 'job-a',
        clockInAt: new Date('2025-10-12T08:00:00Z'),
        clockInLocation: { latitude: 40.7128, longitude: -74.0060 },
        clockInGeofenceValid: true,
        clockOutAt: null,
        clockOutLocation: null,
        clockOutGeofenceValid: null,
        notes: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      });
    });
  });

  test('Cannot change companyId via client update (should be blocked by write:false)', async () => {
    const admin = testEnv.authenticatedContext(ADMIN_A_UID, {
      company_id: COMPANY_A,
      companyId: COMPANY_A,
      role: 'admin',
    });

    // This should fail because clients cannot write at all
    await assertFails(
      admin.firestore().collection('time_entries').doc('entry-imm').update({
        companyId: COMPANY_B, // Attempt to change company
      })
    );
  });

  test('Cannot change userId via client update', async () => {
    const admin = testEnv.authenticatedContext(ADMIN_A_UID, {
      company_id: COMPANY_A,
      companyId: COMPANY_A,
      role: 'admin',
    });

    await assertFails(
      admin.firestore().collection('time_entries').doc('entry-imm').update({
        userId: WORKER_B_UID, // Attempt to reassign to different worker
      })
    );
  });

  test('Cannot change clockInAt via client update', async () => {
    const admin = testEnv.authenticatedContext(ADMIN_A_UID, {
      company_id: COMPANY_A,
      companyId: COMPANY_A,
      role: 'admin',
    });

    await assertFails(
      admin.firestore().collection('time_entries').doc('entry-imm').update({
        clockInAt: new Date('2025-10-12T09:00:00Z'), // Backdating attempt
      })
    );
  });
});

// ============================================================================
// NESTED MAP TAMPERING (GeoPoint fields)
// ============================================================================
describe('time_entries - Nested GeoPoint Tampering', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('time_entries').doc('entry-geo').set({
        companyId: COMPANY_A,
        userId: WORKER_A_UID,
        jobId: 'job-a',
        clockInAt: new Date('2025-10-12T08:00:00Z'),
        clockInLocation: { latitude: 40.7128, longitude: -74.0060 },
        clockInGeofenceValid: true,
        clockOutAt: null,
        clockOutLocation: null,
        clockOutGeofenceValid: null,
        notes: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      });
    });
  });

  test('Cannot modify clockInLocation.latitude directly', async () => {
    const admin = testEnv.authenticatedContext(ADMIN_A_UID, {
      company_id: COMPANY_A,
      companyId: COMPANY_A,
      role: 'admin',
    });

    // Attempt to change latitude without changing longitude
    await assertFails(
      admin.firestore().collection('time_entries').doc('entry-geo').update({
        'clockInLocation.latitude': 41.0000, // GPS spoofing attempt
      })
    );
  });

  test('Cannot replace clockInLocation with different GeoPoint', async () => {
    const admin = testEnv.authenticatedContext(ADMIN_A_UID, {
      company_id: COMPANY_A,
      companyId: COMPANY_A,
      role: 'admin',
    });

    await assertFails(
      admin.firestore().collection('time_entries').doc('entry-geo').update({
        clockInLocation: { latitude: 41.0000, longitude: -75.0000 },
      })
    );
  });
});

// ============================================================================
// WORKER READ PERMISSIONS (Own entries only)
// ============================================================================
describe('time_entries - Worker Read Permissions', () => {
  beforeEach(async () => {
    // Create entry for Worker A
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('time_entries').doc('entry-worker-a').set({
        companyId: COMPANY_A,
        userId: WORKER_A_UID,
        jobId: 'job-a',
        clockInAt: new Date('2025-10-12T08:00:00Z'),
        clockInLocation: { latitude: 40.7128, longitude: -74.0060 },
        clockInGeofenceValid: true,
        clockOutAt: null,
        createdAt: new Date(),
      });
    });

    // Create entry for Worker B (same company)
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('time_entries').doc('entry-worker-b').set({
        companyId: COMPANY_A,
        userId: WORKER_B_UID,
        jobId: 'job-a',
        clockInAt: new Date('2025-10-12T08:00:00Z'),
        clockInLocation: { latitude: 40.7128, longitude: -74.0060 },
        clockInGeofenceValid: true,
        clockOutAt: null,
        createdAt: new Date(),
      });
    });
  });

  test('Worker can read their own time entry', async () => {
    const workerA = testEnv.authenticatedContext(WORKER_A_UID, {
      company_id: COMPANY_A,
      companyId: COMPANY_A,
      role: 'staff',
    });

    await assertSucceeds(
      workerA.firestore().collection('time_entries').doc('entry-worker-a').get()
    );
  });

  test('Worker cannot read another worker time entry (same company)', async () => {
    const workerA = testEnv.authenticatedContext(WORKER_A_UID, {
      company_id: COMPANY_A,
      companyId: COMPANY_A,
      role: 'staff',
    });

    await assertFails(
      workerA.firestore().collection('time_entries').doc('entry-worker-b').get()
    );
  });

  test('Worker cannot query all company time entries', async () => {
    const workerA = testEnv.authenticatedContext(WORKER_A_UID, {
      company_id: COMPANY_A,
      companyId: COMPANY_A,
      role: 'staff',
    });

    // Worker can only query their own entries (userId == auth.uid)
    await assertFails(
      workerA.firestore().collection('time_entries')
        .where('companyId', '==', COMPANY_A)
        .get()
    );
  });

  test('Worker can query their own time entries', async () => {
    const workerA = testEnv.authenticatedContext(WORKER_A_UID, {
      company_id: COMPANY_A,
      companyId: COMPANY_A,
      role: 'staff',
    });

    await assertSucceeds(
      workerA.firestore().collection('time_entries')
        .where('userId', '==', WORKER_A_UID)
        .where('companyId', '==', COMPANY_A)
        .get()
    );
  });
});

// ============================================================================
// UNAUTHENTICATED ACCESS
// ============================================================================
describe('time_entries - Unauthenticated Access', () => {
  test('Unauthenticated user cannot read time entries', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('time_entries').doc('entry-public').set({
        companyId: COMPANY_A,
        userId: WORKER_A_UID,
        jobId: 'job-a',
        clockInAt: new Date(),
        clockInLocation: { latitude: 40.7128, longitude: -74.0060 },
        clockInGeofenceValid: true,
        clockOutAt: null,
        createdAt: new Date(),
      });
    });

    const unauth = testEnv.unauthenticatedContext();

    await assertFails(
      unauth.firestore().collection('time_entries').doc('entry-public').get()
    );
  });

  test('Unauthenticated user cannot create time entry', async () => {
    const unauth = testEnv.unauthenticatedContext();

    await assertFails(
      unauth.firestore().collection('time_entries').add({
        companyId: COMPANY_A,
        userId: WORKER_A_UID,
        jobId: 'job-a',
        clockInAt: new Date(),
        clockInLocation: { latitude: 40.7128, longitude: -74.0060 },
        clockInGeofenceValid: true,
        clockOutAt: null,
      })
    );
  });
});

}
