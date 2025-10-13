/**
 * Firestore Rules Tests for time_entries Collection
 *
 * Tests immutability guarantees and security boundaries for time tracking.
 */

import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { setDoc, updateDoc, doc, Timestamp } from 'firebase/firestore';

describe('time_entries Firestore Rules', () => {
  let testEnv: RulesTestEnvironment;
  const PROJECT_ID = 'test-project';
  const COMPANY_ID = 'company123';
  const WORKER_UID = 'worker456';
  const JOB_ID = 'job789';

  beforeAll(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules: require('fs').readFileSync('firestore.rules', 'utf8'),
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

  describe('Create Operations', () => {
    it('should allow worker to create time entry for themselves', async () => {
      const workerContext = testEnv.authenticatedContext(WORKER_UID, {
        companyId: COMPANY_ID,
        role: 'worker',
      });

      const entryRef = doc(workerContext.firestore(), 'time_entries', 'entry1');
      await assertSucceeds(
        setDoc(entryRef, {
          entryId: 'entry1',
          companyId: COMPANY_ID,
          userId: WORKER_UID,
          jobId: JOB_ID,
          clockInAt: Timestamp.now(),
          clockInGeofenceValid: true,
          clockInLocation: { lat: 37.7793, lng: -122.4193 },
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
        })
      );
    });

    it('should reject create with clockOut fields present (prevents pre-clocking out)', async () => {
      const workerContext = testEnv.authenticatedContext(WORKER_UID, {
        companyId: COMPANY_ID,
        role: 'worker',
      });

      const entryRef = doc(workerContext.firestore(), 'time_entries', 'entry2');
      await assertFails(
        setDoc(entryRef, {
          entryId: 'entry2',
          companyId: COMPANY_ID,
          userId: WORKER_UID,
          jobId: JOB_ID,
          clockInAt: Timestamp.now(),
          clockInGeofenceValid: true,
          clockOutAt: Timestamp.now(), // ❌ Should be rejected
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
        })
      );
    });

    it('should reject create for different user (prevents spoofing)', async () => {
      const workerContext = testEnv.authenticatedContext(WORKER_UID, {
        companyId: COMPANY_ID,
        role: 'worker',
      });

      const entryRef = doc(workerContext.firestore(), 'time_entries', 'entry3');
      await assertFails(
        setDoc(entryRef, {
          entryId: 'entry3',
          companyId: COMPANY_ID,
          userId: 'otherWorker', // ❌ Not the authenticated user
          jobId: JOB_ID,
          clockInAt: Timestamp.now(),
          clockInGeofenceValid: true,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
        })
      );
    });
  });

  describe('Update Operations - Immutability', () => {
    beforeEach(async () => {
      // Seed an active time entry using admin context
      const adminContext = testEnv.authenticatedContext(WORKER_UID, {
        companyId: COMPANY_ID,
        role: 'admin',
      });

      const entryRef = doc(adminContext.firestore(), 'time_entries', 'activeEntry');
      await setDoc(entryRef, {
        entryId: 'activeEntry',
        companyId: COMPANY_ID,
        userId: WORKER_UID,
        jobId: JOB_ID,
        clockInAt: Timestamp.now(),
        clockInGeofenceValid: true,
        clockInLocation: { lat: 37.7793, lng: -122.4193 },
        clockOutAt: null,
        notes: null,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      });
    });

    it('should allow updating clockOut fields only', async () => {
      const workerContext = testEnv.authenticatedContext(WORKER_UID, {
        companyId: COMPANY_ID,
        role: 'worker',
      });

      const entryRef = doc(workerContext.firestore(), 'time_entries', 'activeEntry');
      await assertSucceeds(
        updateDoc(entryRef, {
          clockOutAt: Timestamp.now(),
          clockOutGeofenceValid: true,
          clockOutLocation: { lat: 37.7793, lng: -122.4193 },
          updatedAt: Timestamp.now(),
        })
      );
    });

    it('should allow updating notes field', async () => {
      const workerContext = testEnv.authenticatedContext(WORKER_UID, {
        companyId: COMPANY_ID,
        role: 'worker',
      });

      const entryRef = doc(workerContext.firestore(), 'time_entries', 'activeEntry');
      await assertSucceeds(
        updateDoc(entryRef, {
          notes: 'Finished painting',
          updatedAt: Timestamp.now(),
        })
      );
    });

    it('should reject changing companyId (immutable)', async () => {
      const workerContext = testEnv.authenticatedContext(WORKER_UID, {
        companyId: COMPANY_ID,
        role: 'worker',
      });

      const entryRef = doc(workerContext.firestore(), 'time_entries', 'activeEntry');
      await assertFails(
        updateDoc(entryRef, {
          companyId: 'differentCompany', // ❌ Immutable field
          updatedAt: Timestamp.now(),
        })
      );
    });

    it('should reject changing userId (immutable)', async () => {
      const workerContext = testEnv.authenticatedContext(WORKER_UID, {
        companyId: COMPANY_ID,
        role: 'worker',
      });

      const entryRef = doc(workerContext.firestore(), 'time_entries', 'activeEntry');
      await assertFails(
        updateDoc(entryRef, {
          userId: 'differentUser', // ❌ Immutable field
          updatedAt: Timestamp.now(),
        })
      );
    });

    it('should reject changing jobId (immutable)', async () => {
      const workerContext = testEnv.authenticatedContext(WORKER_UID, {
        companyId: COMPANY_ID,
        role: 'worker',
      });

      const entryRef = doc(workerContext.firestore(), 'time_entries', 'activeEntry');
      await assertFails(
        updateDoc(entryRef, {
          jobId: 'differentJob', // ❌ Immutable field
          updatedAt: Timestamp.now(),
        })
      );
    });

    it('should reject changing clockInAt (immutable)', async () => {
      const workerContext = testEnv.authenticatedContext(WORKER_UID, {
        companyId: COMPANY_ID,
        role: 'worker',
      });

      const entryRef = doc(workerContext.firestore(), 'time_entries', 'activeEntry');
      await assertFails(
        updateDoc(entryRef, {
          clockInAt: Timestamp.now(), // ❌ Immutable field
          updatedAt: Timestamp.now(),
        })
      );
    });

    it('should reject changing clockInGeofenceValid (immutable)', async () => {
      const workerContext = testEnv.authenticatedContext(WORKER_UID, {
        companyId: COMPANY_ID,
        role: 'worker',
      });

      const entryRef = doc(workerContext.firestore(), 'time_entries', 'activeEntry');
      await assertFails(
        updateDoc(entryRef, {
          clockInGeofenceValid: false, // ❌ Immutable field (prevents fraud)
          updatedAt: Timestamp.now(),
        })
      );
    });

    it('should reject updating other user\'s entry', async () => {
      const otherWorkerContext = testEnv.authenticatedContext('otherWorker', {
        companyId: COMPANY_ID,
        role: 'worker',
      });

      const entryRef = doc(otherWorkerContext.firestore(), 'time_entries', 'activeEntry');
      await assertFails(
        updateDoc(entryRef, {
          notes: 'Trying to tamper',
          updatedAt: Timestamp.now(),
        })
      );
    });
  });

  describe('Delete Operations', () => {
    beforeEach(async () => {
      // Seed a time entry using admin context
      const adminContext = testEnv.authenticatedContext(WORKER_UID, {
        companyId: COMPANY_ID,
        role: 'admin',
      });

      const entryRef = doc(adminContext.firestore(), 'time_entries', 'deleteTest');
      await setDoc(entryRef, {
        entryId: 'deleteTest',
        companyId: COMPANY_ID,
        userId: WORKER_UID,
        jobId: JOB_ID,
        clockInAt: Timestamp.now(),
        clockInGeofenceValid: true,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      });
    });

    it('should reject all client deletes (admin uses Cloud Functions)', async () => {
      const workerContext = testEnv.authenticatedContext(WORKER_UID, {
        companyId: COMPANY_ID,
        role: 'worker',
      });

      const entryRef = doc(workerContext.firestore(), 'time_entries', 'deleteTest');
      await assertFails(entryRef.delete());
    });

    it('should reject admin deletes from client (must use Cloud Functions)', async () => {
      const adminContext = testEnv.authenticatedContext('admin123', {
        companyId: COMPANY_ID,
        role: 'admin',
      });

      const entryRef = doc(adminContext.firestore(), 'time_entries', 'deleteTest');
      await assertFails(entryRef.delete());
    });
  });

  describe('Read Operations', () => {
    beforeEach(async () => {
      // Seed entries using admin SDK
      const adminContext = testEnv.authenticatedContext(WORKER_UID, {
        companyId: COMPANY_ID,
        role: 'admin',
      });

      const entry1Ref = doc(adminContext.firestore(), 'time_entries', 'entry1');
      await setDoc(entry1Ref, {
        entryId: 'entry1',
        companyId: COMPANY_ID,
        userId: WORKER_UID,
        jobId: JOB_ID,
        clockInAt: Timestamp.now(),
        clockInGeofenceValid: true,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      });

      const entry2Ref = doc(adminContext.firestore(), 'time_entries', 'entry2');
      await setDoc(entry2Ref, {
        entryId: 'entry2',
        companyId: 'otherCompany',
        userId: 'otherWorker',
        jobId: JOB_ID,
        clockInAt: Timestamp.now(),
        clockInGeofenceValid: true,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      });
    });

    it('should allow worker to read their own entries in same company', async () => {
      const workerContext = testEnv.authenticatedContext(WORKER_UID, {
        companyId: COMPANY_ID,
        role: 'worker',
      });

      const entryRef = doc(workerContext.firestore(), 'time_entries', 'entry1');
      await assertSucceeds(entryRef.get());
    });

    it('should reject worker reading entries from different company', async () => {
      const workerContext = testEnv.authenticatedContext(WORKER_UID, {
        companyId: COMPANY_ID,
        role: 'worker',
      });

      const entryRef = doc(workerContext.firestore(), 'time_entries', 'entry2');
      await assertFails(entryRef.get());
    });
  });
});
