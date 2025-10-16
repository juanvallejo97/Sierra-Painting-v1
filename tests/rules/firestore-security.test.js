/**
 * Firestore Security Rules Test Suite
 *
 * PURPOSE:
 * - Validate multi-tenant data isolation
 * - Test RBAC (role-based access control)
 * - Verify company-scoped queries work correctly
 * - Ensure no cross-tenant data leaks
 * - Test field immutability
 *
 * USAGE:
 * npm install --prefix . @firebase/rules-unit-testing
 * firebase emulators:exec --only firestore "npm test -- firestore-security.test.js"
 */

const testing = require('@firebase/rules-unit-testing');
const { readFileSync } = require('fs');
const { resolve } = require('path');

const PROJECT_ID = 'sierra-painting-test';

// Test user contexts
const COMPANY_A = 'company-a-test';
const COMPANY_B = 'company-b-test';

const ADMIN_A = { uid: 'admin-a', email: 'admin@companya.test', companyId: COMPANY_A, role: 'admin' };
const MANAGER_A = { uid: 'manager-a', email: 'manager@companya.test', companyId: COMPANY_A, role: 'manager' };
const WORKER_A = { uid: 'worker-a', email: 'worker@companya.test', companyId: COMPANY_A, role: 'worker' };

const ADMIN_B = { uid: 'admin-b', email: 'admin@companyb.test', companyId: COMPANY_B, role: 'admin' };
const WORKER_B = { uid: 'worker-b', email: 'worker@companyb.test', companyId: COMPANY_B, role: 'worker' };

let testEnv;

beforeAll(async () => {
  // Load Firestore rules
  const rulesPath = resolve(__dirname, '../../firestore.rules');
  const rules = readFileSync(rulesPath, 'utf8');

  // Initialize test environment
  testEnv = await testing.initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules,
      host: 'localhost',
      port: 8080,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

/**
 * Helper to get authenticated Firestore instance
 */
function getFirestore(auth) {
  return testEnv.authenticatedContext(auth.uid, {
    email: auth.email,
    companyId: auth.companyId,
    role: auth.role,
  }).firestore();
}

/**
 * Helper to get unauthenticated Firestore instance
 */
function getUnauthenticatedFirestore() {
  return testEnv.unauthenticatedContext().firestore();
}

describe('Firestore Security Rules - Multi-Tenant Isolation', () => {
  describe('Authentication Requirements', () => {
    test('should deny all access to unauthenticated users', async () => {
      const db = getUnauthenticatedFirestore();

      await testing.assertFails(
        db.collection('companies').doc(COMPANY_A).get()
      );

      await testing.assertFails(
        db.collection('companies').doc(COMPANY_A).collection('jobs').get()
      );
    });
  });

  describe('Company Data Isolation', () => {
    test('admin can read their own company data', async () => {
      const db = getFirestore(ADMIN_A);

      // Seed data
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore()
          .collection('companies').doc(COMPANY_A)
          .collection('jobs').doc('job-1')
          .set({ companyId: COMPANY_A, name: 'Test Job', active: true });
      });

      await testing.assertSucceeds(
        db.collection('companies').doc(COMPANY_A)
          .collection('jobs').doc('job-1').get()
      );
    });

    test('admin CANNOT read other company data', async () => {
      const db = getFirestore(ADMIN_A);

      // Seed data for Company B
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore()
          .collection('companies').doc(COMPANY_B)
          .collection('jobs').doc('job-b')
          .set({ companyId: COMPANY_B, name: 'Secret Job', active: true });
      });

      await testing.assertFails(
        db.collection('companies').doc(COMPANY_B)
          .collection('jobs').doc('job-b').get()
      );
    });

    test('worker CANNOT access different company data', async () => {
      const db = getFirestore(WORKER_A);

      // Seed data for Company B
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore()
          .collection('companies').doc(COMPANY_B)
          .collection('invoices').doc('invoice-b')
          .set({ companyId: COMPANY_B, amount: 1000, status: 'draft' });
      });

      await testing.assertFails(
        db.collection('companies').doc(COMPANY_B)
          .collection('invoices').doc('invoice-b').get()
      );
    });
  });

  describe('Role-Based Access Control (RBAC)', () => {
    test('admin can create jobs', async () => {
      const db = getFirestore(ADMIN_A);

      await testing.assertSucceeds(
        db.collection('companies').doc(COMPANY_A)
          .collection('jobs').doc('new-job')
          .set({ companyId: COMPANY_A, name: 'New Job', active: true })
      );
    });

    test('manager can create jobs', async () => {
      const db = getFirestore(MANAGER_A);

      await testing.assertSucceeds(
        db.collection('companies').doc(COMPANY_A)
          .collection('jobs').doc('manager-job')
          .set({ companyId: COMPANY_A, name: 'Manager Job', active: true })
      );
    });

    test('worker CANNOT create jobs', async () => {
      const db = getFirestore(WORKER_A);

      await testing.assertFails(
        db.collection('companies').doc(COMPANY_A)
          .collection('jobs').doc('worker-job')
          .set({ companyId: COMPANY_A, name: 'Worker Job', active: true })
      );
    });

    test('worker CAN read jobs assigned to them', async () => {
      const db = getFirestore(WORKER_A);

      // Seed data
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore()
          .collection('companies').doc(COMPANY_A)
          .collection('jobs').doc('assigned-job')
          .set({ companyId: COMPANY_A, name: 'Assigned Job', active: true });
      });

      await testing.assertSucceeds(
        db.collection('companies').doc(COMPANY_A)
          .collection('jobs').doc('assigned-job').get()
      );
    });

    test('worker CAN create time entries', async () => {
      const db = getFirestore(WORKER_A);

      await testing.assertSucceeds(
        db.collection('companies').doc(COMPANY_A)
          .collection('time_entries').doc('entry-1')
          .set({
            companyId: COMPANY_A,
            userId: WORKER_A.uid,
            jobId: 'job-1',
            clockInAt: new Date(),
            status: 'active',
          })
      );
    });

    test('worker CANNOT modify other workers time entries', async () => {
      const db = getFirestore(WORKER_A);

      // Seed time entry for Worker B
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore()
          .collection('companies').doc(COMPANY_A)
          .collection('time_entries').doc('entry-b')
          .set({
            companyId: COMPANY_A,
            userId: 'worker-b-different',
            jobId: 'job-1',
            clockInAt: new Date(),
            status: 'active',
          });
      });

      await testing.assertFails(
        db.collection('companies').doc(COMPANY_A)
          .collection('time_entries').doc('entry-b')
          .update({ status: 'completed' })
      );
    });
  });

  describe('Field Immutability', () => {
    test('companyId field CANNOT be modified', async () => {
      const db = getFirestore(ADMIN_A);

      // Seed data
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore()
          .collection('companies').doc(COMPANY_A)
          .collection('jobs').doc('immutable-job')
          .set({ companyId: COMPANY_A, name: 'Test', active: true });
      });

      // Try to change companyId
      await testing.assertFails(
        db.collection('companies').doc(COMPANY_A)
          .collection('jobs').doc('immutable-job')
          .update({ companyId: COMPANY_B })  // Should fail
      );
    });

    test('userId in time entry CANNOT be modified', async () => {
      const db = getFirestore(WORKER_A);

      // Create time entry
      await db.collection('companies').doc(COMPANY_A)
        .collection('time_entries').doc('entry-1')
        .set({
          companyId: COMPANY_A,
          userId: WORKER_A.uid,
          jobId: 'job-1',
          clockInAt: new Date(),
          status: 'active',
        });

      // Try to change userId
      await testing.assertFails(
        db.collection('companies').doc(COMPANY_A)
          .collection('time_entries').doc('entry-1')
          .update({ userId: 'different-user' })
      );
    });
  });

  describe('Invoice Security', () => {
    test('worker CANNOT read invoices', async () => {
      const db = getFirestore(WORKER_A);

      // Seed invoice
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore()
          .collection('companies').doc(COMPANY_A)
          .collection('invoices').doc('invoice-1')
          .set({
            companyId: COMPANY_A,
            amount: 1000,
            status: 'draft',
          });
      });

      await testing.assertFails(
        db.collection('companies').doc(COMPANY_A)
          .collection('invoices').doc('invoice-1').get()
      );
    });

    test('admin CAN read invoices', async () => {
      const db = getFirestore(ADMIN_A);

      // Seed invoice
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore()
          .collection('companies').doc(COMPANY_A)
          .collection('invoices').doc('invoice-1')
          .set({
            companyId: COMPANY_A,
            amount: 1000,
            status: 'draft',
          });
      });

      await testing.assertSucceeds(
        db.collection('companies').doc(COMPANY_A)
          .collection('invoices').doc('invoice-1').get()
      );
    });

    test('admin CANNOT modify sent invoice', async () => {
      const db = getFirestore(ADMIN_A);

      // Seed sent invoice
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore()
          .collection('companies').doc(COMPANY_A)
          .collection('invoices').doc('sent-invoice')
          .set({
            companyId: COMPANY_A,
            amount: 1000,
            status: 'sent',
            number: 'INV-202510-0001',
          });
      });

      // Try to modify - should fail if immutability rules enforce it
      await testing.assertFails(
        db.collection('companies').doc(COMPANY_A)
          .collection('invoices').doc('sent-invoice')
          .update({ amount: 2000 })
      );
    });
  });

  describe('Query Security', () => {
    test('admin can query their company jobs', async () => {
      const db = getFirestore(ADMIN_A);

      // Seed multiple jobs
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const batch = context.firestore().batch();
        for (let i = 0; i < 5; i++) {
          const ref = context.firestore()
            .collection('companies').doc(COMPANY_A)
            .collection('jobs').doc(`job-${i}`);
          batch.set(ref, { companyId: COMPANY_A, name: `Job ${i}`, active: true });
        }
        await batch.commit();
      });

      await testing.assertSucceeds(
        db.collection('companies').doc(COMPANY_A)
          .collection('jobs')
          .where('companyId', '==', COMPANY_A)
          .where('active', '==', true)
          .get()
      );
    });

    test('query MUST include companyId filter', async () => {
      const db = getFirestore(ADMIN_A);

      // Query without companyId filter should fail
      await testing.assertFails(
        db.collection('companies').doc(COMPANY_A)
          .collection('jobs')
          .where('active', '==', true)
          .get()
      );
    });
  });
});

console.log('✅ Firestore security rules tests completed');
