/**
 * Firestore Security Rules Tests - Timekeeping
 *
 * PURPOSE:
 * Test security rules for timekeeping collections to ensure:
 * - Workers can only create clockEvents for themselves
 * - Workers cannot write timeEntries (function-only writes)
 * - Cross-tenant isolation (no reads/writes across companies)
 * - Admin-only operations (e.g., job deletes)
 *
 * SETUP:
 * Requires Firebase emulator running:
 * firebase emulators:start --only firestore,auth
 *
 * RUN:
 * npm --prefix functions test -- --runInBand --testPathPattern=rules_
 */

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import * as fs from 'fs';
import * as path from 'path';

describe('Firestore Rules - Timekeeping', () => {
  let testEnv: RulesTestEnvironment;

  // Test users
  const worker1 = {uid: 'worker1', email: 'worker1@example.com', companyId: 'company1'};
  const worker2 = {uid: 'worker2', email: 'worker2@example.com', companyId: 'company2'};
  const admin = {uid: 'admin1', email: 'admin@example.com', companyId: 'company1', admin: true};

  beforeAll(async () => {
    // Load rules from firestore.rules
    const rulesPath = path.resolve(__dirname, '../../../firestore.rules');
    const rules = fs.existsSync(rulesPath)
      ? fs.readFileSync(rulesPath, 'utf8')
      : ''; // Fallback to empty rules if file not found

    testEnv = await initializeTestEnvironment({
      projectId: 'test-project',
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

  describe('clockEvents Collection', () => {
    it('allows worker to create clockEvent for self', async () => {
      const db = testEnv.authenticatedContext(worker1.uid, {
        companyId: worker1.companyId,
      }).firestore();

      const clockEventRef = db.collection('clockEvents').doc();
      await assertSucceeds(
        clockEventRef.set({
          userId: worker1.uid,
          companyId: worker1.companyId,
          type: 'clockIn',
          at: new Date(),
          jobId: 'job1',
          geo: {lat: 40.7128, lng: -74.0060},
          createdAt: new Date(),
        })
      );
    });

    it('denies worker creating clockEvent for another user', async () => {
      const db = testEnv.authenticatedContext(worker1.uid, {
        companyId: worker1.companyId,
      }).firestore();

      const clockEventRef = db.collection('clockEvents').doc();
      await assertFails(
        clockEventRef.set({
          userId: worker2.uid, // Different user!
          companyId: worker1.companyId,
          type: 'clockIn',
          at: new Date(),
          jobId: 'job1',
          geo: {lat: 40.7128, lng: -74.0060},
          createdAt: new Date(),
        })
      );
    });

    it('denies worker updating clockEvent', async () => {
      const db = testEnv.authenticatedContext(worker1.uid, {
        companyId: worker1.companyId,
      }).firestore();

      // Seed clockEvent
      const clockEventRef = db.collection('clockEvents').doc('event1');
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('clockEvents').doc('event1').set({
          userId: worker1.uid,
          companyId: worker1.companyId,
          type: 'clockIn',
          at: new Date(),
          jobId: 'job1',
        });
      });

      // Try to update
      await assertFails(
        clockEventRef.update({
          type: 'clockOut',
        })
      );
    });

    it('denies worker deleting clockEvent', async () => {
      const db = testEnv.authenticatedContext(worker1.uid, {
        companyId: worker1.companyId,
      }).firestore();

      // Seed clockEvent
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('clockEvents').doc('event1').set({
          userId: worker1.uid,
          companyId: worker1.companyId,
          type: 'clockIn',
          at: new Date(),
        });
      });

      const clockEventRef = db.collection('clockEvents').doc('event1');
      await assertFails(clockEventRef.delete());
    });

    it('denies cross-tenant read of clockEvents', async () => {
      // Seed clockEvent for company1
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('clockEvents').doc('event1').set({
          userId: worker1.uid,
          companyId: 'company1',
          type: 'clockIn',
          at: new Date(),
        });
      });

      // Try to read as worker2 (company2)
      const db = testEnv.authenticatedContext(worker2.uid, {
        companyId: worker2.companyId,
      }).firestore();

      const clockEventRef = db.collection('clockEvents').doc('event1');
      await assertFails(clockEventRef.get());
    });
  });

  describe('timeEntries Collection', () => {
    it('denies worker creating timeEntry directly', async () => {
      const db = testEnv.authenticatedContext(worker1.uid, {
        companyId: worker1.companyId,
      }).firestore();

      const timeEntryRef = db.collection('timeEntries').doc();
      await assertFails(
        timeEntryRef.set({
          userId: worker1.uid,
          companyId: worker1.companyId,
          jobId: 'job1',
          clockInAt: new Date(),
          clockOutAt: null,
        })
      );
    });

    it('denies worker updating timeEntry directly', async () => {
      // Seed timeEntry
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('timeEntries').doc('entry1').set({
          userId: worker1.uid,
          companyId: 'company1',
          jobId: 'job1',
          clockInAt: new Date(),
          clockOutAt: null,
        });
      });

      const db = testEnv.authenticatedContext(worker1.uid, {
        companyId: worker1.companyId,
      }).firestore();

      const timeEntryRef = db.collection('timeEntries').doc('entry1');
      await assertFails(
        timeEntryRef.update({
          clockOutAt: new Date(),
        })
      );
    });

    it('denies worker deleting timeEntry', async () => {
      // Seed timeEntry
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('timeEntries').doc('entry1').set({
          userId: worker1.uid,
          companyId: 'company1',
          jobId: 'job1',
          clockInAt: new Date(),
          clockOutAt: null,
        });
      });

      const db = testEnv.authenticatedContext(worker1.uid, {
        companyId: worker1.companyId,
      }).firestore();

      const timeEntryRef = db.collection('timeEntries').doc('entry1');
      await assertFails(timeEntryRef.delete());
    });

    it('allows worker to read own timeEntries', async () => {
      // Seed timeEntry for worker1
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('timeEntries').doc('entry1').set({
          userId: worker1.uid,
          companyId: 'company1',
          jobId: 'job1',
          clockInAt: new Date(),
          clockOutAt: null,
        });
      });

      const db = testEnv.authenticatedContext(worker1.uid, {
        companyId: worker1.companyId,
      }).firestore();

      const timeEntryRef = db.collection('timeEntries').doc('entry1');
      await assertSucceeds(timeEntryRef.get());
    });

    it('denies cross-tenant read of timeEntries', async () => {
      // Seed timeEntry for company1
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('timeEntries').doc('entry1').set({
          userId: worker1.uid,
          companyId: 'company1',
          jobId: 'job1',
          clockInAt: new Date(),
          clockOutAt: null,
        });
      });

      // Try to read as worker2 (company2)
      const db = testEnv.authenticatedContext(worker2.uid, {
        companyId: worker2.companyId,
      }).firestore();

      const timeEntryRef = db.collection('timeEntries').doc('entry1');
      await assertFails(timeEntryRef.get());
    });
  });

  describe('jobs Collection', () => {
    it('allows worker to read jobs in same company', async () => {
      // Seed job
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('jobs').doc('job1').set({
          companyId: 'company1',
          name: 'Test Job',
          status: 'active',
          createdAt: new Date(),
        });
      });

      const db = testEnv.authenticatedContext(worker1.uid, {
        companyId: worker1.companyId,
      }).firestore();

      const jobRef = db.collection('jobs').doc('job1');
      await assertSucceeds(jobRef.get());
    });

    it('denies worker deleting job', async () => {
      // Seed job
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('jobs').doc('job1').set({
          companyId: 'company1',
          name: 'Test Job',
          status: 'active',
          createdAt: new Date(),
        });
      });

      const db = testEnv.authenticatedContext(worker1.uid, {
        companyId: worker1.companyId,
      }).firestore();

      const jobRef = db.collection('jobs').doc('job1');
      await assertFails(jobRef.delete());
    });

    it('allows admin to delete job in same company', async () => {
      // Seed job
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('jobs').doc('job1').set({
          companyId: 'company1',
          name: 'Test Job',
          status: 'active',
          createdAt: new Date(),
        });
      });

      const db = testEnv.authenticatedContext(admin.uid, {
        companyId: admin.companyId,
        admin: true,
      }).firestore();

      const jobRef = db.collection('jobs').doc('job1');
      await assertSucceeds(jobRef.delete());
    });

    it('denies cross-tenant read of jobs', async () => {
      // Seed job for company1
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('jobs').doc('job1').set({
          companyId: 'company1',
          name: 'Test Job',
          status: 'active',
          createdAt: new Date(),
        });
      });

      // Try to read as worker2 (company2)
      const db = testEnv.authenticatedContext(worker2.uid, {
        companyId: worker2.companyId,
      }).firestore();

      const jobRef = db.collection('jobs').doc('job1');
      await assertFails(jobRef.get());
    });
  });

  describe('Cross-Tenant Isolation', () => {
    it('denies reading any document from another company', async () => {
      // Seed data for company1
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const firestore = context.firestore();
        await firestore.collection('jobs').doc('job1').set({
          companyId: 'company1',
          name: 'Company 1 Job',
        });
        await firestore.collection('timeEntries').doc('entry1').set({
          userId: worker1.uid,
          companyId: 'company1',
          jobId: 'job1',
          clockInAt: new Date(),
        });
        await firestore.collection('invoices').doc('invoice1').set({
          companyId: 'company1',
          customerId: 'customer1',
          total: 1000,
        });
      });

      // Try to read as worker2 (company2)
      const db = testEnv.authenticatedContext(worker2.uid, {
        companyId: worker2.companyId,
      }).firestore();

      await assertFails(db.collection('jobs').doc('job1').get());
      await assertFails(db.collection('timeEntries').doc('entry1').get());
      await assertFails(db.collection('invoices').doc('invoice1').get());
    });

    it('denies writing to another company documents', async () => {
      const db = testEnv.authenticatedContext(worker2.uid, {
        companyId: worker2.companyId,
      }).firestore();

      // Try to create docs with company1 companyId
      await assertFails(
        db.collection('jobs').doc().set({
          companyId: 'company1', // Wrong company!
          name: 'Malicious Job',
        })
      );
    });
  });
});
