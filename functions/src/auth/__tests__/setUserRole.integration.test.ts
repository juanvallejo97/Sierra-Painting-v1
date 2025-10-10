/**
 * Integration tests for setUserRole Cloud Function
 *
 * These tests verify the complete setUserRole flow including:
 * - Authentication enforcement
 * - Admin authorization
 * - Custom claims setting (verified via Firestore doc)
 * - Firestore document updates
 * - Audit log creation
 * - Error scenarios
 *
 * Prerequisites:
 * - Firebase emulators running: FIRESTORE_EMULATOR_HOST=localhost:8080 npm test
 */

import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';
import { setUserRole } from '../setUserRole';

const RUN_INTEGRATION = !!process.env.FIRESTORE_EMULATOR_HOST;

// Skip tests if emulators not running
if (!RUN_INTEGRATION) {
  test('Integration tests skipped (FIRESTORE_EMULATOR_HOST not set)', () => {
    expect(true).toBe(true);
  });
} else {
  describe('setUserRole Integration Tests', () => {
    let testHelper: ReturnType<typeof functionsTest>;
    let wrappedFunction: any;
    const PROJECT_ID = 'test-sierra-painting';
    const COMPANY_ID = 'test-company-123';

    beforeAll(() => {
      // Initialize Firebase Functions Test
      testHelper = functionsTest({
        projectId: PROJECT_ID,
      });

      // Initialize admin SDK for emulators
      if (admin.apps.length === 0) {
        admin.initializeApp({
          projectId: PROJECT_ID,
        });
      }

      // Wrap the function for testing
      wrappedFunction = testHelper.wrap(setUserRole);
    });

    afterAll(async () => {
      testHelper.cleanup();
      // Clean up all admin apps
      await Promise.all(
        admin.apps.map((app) => {
          if (app) return app.delete();
          return Promise.resolve();
        })
      );
    });

    beforeEach(async () => {
      // Clear Firestore before each test
      const db = admin.firestore();
      const collections = ['users', 'auditLog'];

      for (const collectionName of collections) {
        const snapshot = await db.collection(collectionName).get();
        const batch = db.batch();
        snapshot.docs.forEach((doc) => {
          batch.delete(doc.ref);
        });
        await batch.commit();
      }
    });

    describe('Authentication & Authorization', () => {
      it('should reject unauthenticated requests', async () => {
        const request = {
          data: {
            uid: 'target-user',
            role: 'manager' as const,
            companyId: COMPANY_ID,
          },
          auth: undefined, // No auth
        };

        await expect(wrappedFunction(request)).rejects.toThrow(/unauthenticated/i);
      });

      it('should reject non-admin requests', async () => {
        const request = {
          data: {
            uid: 'target-user',
            role: 'staff' as const,
            companyId: COMPANY_ID,
          },
          auth: {
            uid: 'manager-user',
            token: {
              role: 'manager',
              companyId: COMPANY_ID,
              email: 'manager@test.com',
            },
          },
        };

        await expect(wrappedFunction(request)).rejects.toThrow(
          /permission-denied|Only admins/i
        );
      });

      it('should allow admin requests', async () => {
        // First create the target user in Auth emulator
        await admin.auth().createUser({
          uid: 'target-user',
          email: 'target@test.com',
        });

        const request = {
          data: {
            uid: 'target-user',
            role: 'staff' as const,
            companyId: COMPANY_ID,
          },
          auth: {
            uid: 'admin-user',
            token: {
              role: 'admin',
              companyId: COMPANY_ID,
              email: 'admin@test.com',
            },
          },
        };

        const result = await wrappedFunction(request);

        expect(result).toMatchObject({
          success: true,
          uid: 'target-user',
          role: 'staff',
          companyId: COMPANY_ID,
        });

        // Cleanup
        await admin.auth().deleteUser('target-user');
      });
    });

    describe('Input Validation', () => {
      const adminAuth = {
        uid: 'admin-user',
        token: {
          role: 'admin',
          companyId: COMPANY_ID,
          email: 'admin@test.com',
        },
      };

      it('should reject missing uid', async () => {
        const request = {
          data: {
            role: 'manager' as const,
            companyId: COMPANY_ID,
          },
          auth: adminAuth,
        };

        await expect(wrappedFunction(request)).rejects.toThrow(
          /invalid-argument|User ID is required/i
        );
      });

      it('should reject empty uid', async () => {
        const request = {
          data: {
            uid: '',
            role: 'manager' as const,
            companyId: COMPANY_ID,
          },
          auth: adminAuth,
        };

        await expect(wrappedFunction(request)).rejects.toThrow(
          /invalid-argument|User ID is required/i
        );
      });

      it('should reject invalid role', async () => {
        const request = {
          data: {
            uid: 'target-user',
            role: 'superuser',
            companyId: COMPANY_ID,
          },
          auth: adminAuth,
        };

        await expect(wrappedFunction(request)).rejects.toThrow(
          /invalid-argument|Invalid role/i
        );
      });

      it('should reject missing companyId', async () => {
        const request = {
          data: {
            uid: 'target-user',
            role: 'manager' as const,
          },
          auth: adminAuth,
        };

        await expect(wrappedFunction(request)).rejects.toThrow(
          /invalid-argument|Company ID is required/i
        );
      });

      it('should accept all valid roles', async () => {
        const validRoles = ['admin', 'manager', 'staff', 'crew'] as const;

        for (const role of validRoles) {
          const uid = `user-${role}`;

          // Create user
          await admin.auth().createUser({
            uid,
            email: `${role}@test.com`,
          });

          const request = {
            data: {
              uid,
              role,
              companyId: COMPANY_ID,
            },
            auth: adminAuth,
          };

          const result = await wrappedFunction(request);
          expect(result).toMatchObject({
            success: true,
            role,
          });

          // Cleanup
          await admin.auth().deleteUser(uid);
        }
      });
    });

    describe('Firestore Document Updates', () => {
      it('should create/update user document in Firestore', async () => {
        const targetUid = 'test-user-firestore';

        // Create user
        await admin.auth().createUser({
          uid: targetUid,
          email: 'test@test.com',
        });

        const request = {
          data: {
            uid: targetUid,
            role: 'manager' as const,
            companyId: COMPANY_ID,
          },
          auth: {
            uid: 'admin-user',
            token: {
              role: 'admin',
              companyId: COMPANY_ID,
              email: 'admin@test.com',
            },
          },
        };

        await wrappedFunction(request);

        // Verify Firestore document
        const userDoc = await admin.firestore().collection('users').doc(targetUid).get();

        expect(userDoc.exists).toBe(true);
        expect(userDoc.data()).toMatchObject({
          role: 'manager',
          companyId: COMPANY_ID,
        });
        expect(userDoc.data()?.roleUpdatedAt).toBeDefined();

        // Cleanup
        await admin.auth().deleteUser(targetUid);
      });

      it('should preserve existing fields when updating (merge mode)', async () => {
        const targetUid = 'test-user-merge';

        // Create user
        await admin.auth().createUser({
          uid: targetUid,
          email: 'test@test.com',
        });

        // Pre-create user document with existing fields
        await admin.firestore().collection('users').doc(targetUid).set({
          email: 'test@test.com',
          customField: 'should-be-preserved',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const request = {
          data: {
            uid: targetUid,
            role: 'crew' as const,
            companyId: COMPANY_ID,
          },
          auth: {
            uid: 'admin-user',
            token: {
              role: 'admin',
              companyId: COMPANY_ID,
              email: 'admin@test.com',
            },
          },
        };

        await wrappedFunction(request);

        // Verify existing fields are preserved
        const userDoc = await admin.firestore().collection('users').doc(targetUid).get();
        expect(userDoc.data()).toMatchObject({
          email: 'test@test.com',
          customField: 'should-be-preserved',
          role: 'crew',
          companyId: COMPANY_ID,
        });

        // Cleanup
        await admin.auth().deleteUser(targetUid);
      });
    });

    describe('Audit Log Creation', () => {
      it('should create audit log entry for role change', async () => {
        const targetUid = 'test-user-audit';
        const adminUid = 'admin-user-audit';

        // Create user
        await admin.auth().createUser({
          uid: targetUid,
          email: 'target@test.com',
        });

        const request = {
          data: {
            uid: targetUid,
            role: 'manager' as const,
            companyId: COMPANY_ID,
          },
          auth: {
            uid: adminUid,
            token: {
              role: 'admin',
              companyId: COMPANY_ID,
              email: 'admin@test.com',
            },
          },
        };

        await wrappedFunction(request);

        // Query audit log
        const snapshot = await admin
          .firestore()
          .collection('auditLog')
          .where('action', '==', 'setUserRole')
          .where('targetUserId', '==', targetUid)
          .get();

        expect(snapshot.empty).toBe(false);
        expect(snapshot.size).toBe(1);

        const auditLog = snapshot.docs[0].data();
        expect(auditLog).toMatchObject({
          action: 'setUserRole',
          targetUserId: targetUid,
          targetUserEmail: 'target@test.com',
          performedBy: adminUid,
          performedByEmail: 'admin@test.com',
          newRole: 'manager',
          companyId: COMPANY_ID,
        });
        expect(auditLog.timestamp).toBeDefined();

        // Cleanup
        await admin.auth().deleteUser(targetUid);
      });

      it('should create unique audit log entries for multiple changes', async () => {
        const targetUid = 'test-user-multi-audit';

        // Create user
        await admin.auth().createUser({
          uid: targetUid,
          email: 'target@test.com',
        });

        const adminAuth = {
          uid: 'admin-user',
          token: {
            role: 'admin',
            companyId: COMPANY_ID,
            email: 'admin@test.com',
          },
        };

        // Change role 3 times
        const roles = ['crew', 'staff', 'manager'] as const;
        for (const role of roles) {
          const request = {
            data: {
              uid: targetUid,
              role,
              companyId: COMPANY_ID,
            },
            auth: adminAuth,
          };

          await wrappedFunction(request);
        }

        // Verify 3 audit log entries
        const snapshot = await admin
          .firestore()
          .collection('auditLog')
          .where('targetUserId', '==', targetUid)
          .get();

        expect(snapshot.size).toBe(3);

        const loggedRoles = snapshot.docs.map((doc) => doc.data().newRole);
        expect(loggedRoles).toContain('crew');
        expect(loggedRoles).toContain('staff');
        expect(loggedRoles).toContain('manager');

        // Cleanup
        await admin.auth().deleteUser(targetUid);
      });
    });

    describe('Error Handling', () => {
      it('should handle non-existent user gracefully', async () => {
        const request = {
          data: {
            uid: 'non-existent-user-12345',
            role: 'manager' as const,
            companyId: COMPANY_ID,
          },
          auth: {
            uid: 'admin-user',
            token: {
              role: 'admin',
              companyId: COMPANY_ID,
              email: 'admin@test.com',
            },
          },
        };

        await expect(wrappedFunction(request)).rejects.toThrow(
          /not-found|User.*not found/i
        );
      });
    });

    describe('Edge Cases', () => {
      it('should handle setting same role multiple times (idempotent)', async () => {
        const targetUid = 'test-user-idempotent';

        // Create user
        await admin.auth().createUser({
          uid: targetUid,
          email: 'test@test.com',
        });

        const request = {
          data: {
            uid: targetUid,
            role: 'manager' as const,
            companyId: COMPANY_ID,
          },
          auth: {
            uid: 'admin-user',
            token: {
              role: 'admin',
              companyId: COMPANY_ID,
              email: 'admin@test.com',
            },
          },
        };

        // Set role twice
        const result1 = await wrappedFunction(request);
        const result2 = await wrappedFunction(request);

        expect(result1.success).toBe(true);
        expect(result2.success).toBe(true);

        // Both audit log entries should exist
        const snapshot = await admin
          .firestore()
          .collection('auditLog')
          .where('targetUserId', '==', targetUid)
          .get();

        expect(snapshot.size).toBe(2);

        // Cleanup
        await admin.auth().deleteUser(targetUid);
      });

      it('should handle admin promoting another user to admin', async () => {
        const targetUid = 'test-user-new-admin';

        // Create user
        await admin.auth().createUser({
          uid: targetUid,
          email: 'new-admin@test.com',
        });

        const request = {
          data: {
            uid: targetUid,
            role: 'admin' as const,
            companyId: COMPANY_ID,
          },
          auth: {
            uid: 'existing-admin',
            token: {
              role: 'admin',
              companyId: COMPANY_ID,
              email: 'admin@test.com',
            },
          },
        };

        const result = await wrappedFunction(request);

        expect(result).toMatchObject({
          success: true,
          role: 'admin',
        });

        // Verify audit log shows admin-to-admin promotion
        const snapshot = await admin
          .firestore()
          .collection('auditLog')
          .where('targetUserId', '==', targetUid)
          .where('newRole', '==', 'admin')
          .get();

        expect(snapshot.empty).toBe(false);

        // Cleanup
        await admin.auth().deleteUser(targetUid);
      });
    });
  });
}
