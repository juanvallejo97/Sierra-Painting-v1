/**
 * Cloud Function to set user custom claims for role-based access control
 *
 * SECURITY:
 * - Admin-only function (requires admin custom claim)
 * - Sets custom claims on user's Firebase Auth token
 * - Eliminates need for Firestore reads in security rules
 *
 * USAGE:
 *   const setUserRole = httpsCallable(functions, 'setUserRole');
 *   await setUserRole({ uid: 'user123', role: 'admin', companyId: 'company456' });
 *
 * CLAIMS SET:
 * - role: 'admin' | 'manager' | 'staff' | 'crew'
 * - companyId: string (user's company identifier)
 * - updatedAt: timestamp of when claims were set
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { z } from 'zod';
import { ensureAppCheck } from '../middleware/ensureAppCheck';

// Validation schema
const SetUserRoleSchema = z.object({
  uid: z.string().min(1, 'User ID is required'),
  role: z.enum(['admin', 'manager', 'staff', 'crew'], {
    message: 'Invalid role. Must be: admin, manager, staff, or crew',
  }),
  companyId: z.string().min(1, 'Company ID is required'),
});

type SetUserRoleRequest = z.infer<typeof SetUserRoleSchema>;

/**
 * Set custom claims for a user
 * Callable by admins only
 */
export const setUserRole = onCall<SetUserRoleRequest>(
  {
    region: 'us-east4',
    memory: '256MiB',
    timeoutSeconds: 30,
    enforceAppCheck: true, // Native App Check enforcement (Firebase SDK)
  },
  async (request) => {
    // 1. Verify App Check token (defense-in-depth)
    ensureAppCheck(request);

    // 2. Verify caller is authenticated
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be authenticated to call this function');
    }

    // 3. Verify caller is an admin
    const callerToken = request.auth.token;
    if (callerToken.role !== 'admin') {
      throw new HttpsError(
        'permission-denied',
        'Only admins can set user roles'
      );
    }

    // 4. Validate input
    let validatedData: SetUserRoleRequest;
    try {
      validatedData = SetUserRoleSchema.parse(request.data);
    } catch (err) {
      if (err instanceof z.ZodError) {
        throw new HttpsError('invalid-argument', err.issues[0].message);
      }
      throw new HttpsError('invalid-argument', 'Invalid request data');
    }

    const { uid, role, companyId } = validatedData;

    try {
      // 5. Verify target user exists
      let user: admin.auth.UserRecord;
      try {
        user = await admin.auth().getUser(uid);
      } catch {
        throw new HttpsError('not-found', `User with ID ${uid} not found`);
      }

      // 6. Set custom claims
      const customClaims = {
        role,
        companyId,
        updatedAt: Date.now(),
      };

      await admin.auth().setCustomUserClaims(uid, customClaims);

      // 7. Update user document in Firestore (for legacy compatibility)
      // This ensures rules using Firestore lookups still work during migration
      const userRef = admin.firestore().collection('users').doc(uid);
      await userRef.set(
        {
          role,
          companyId,
          roleUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          // Force token refresh flag (client will detect and refresh)
          forceTokenRefresh: true,
          tokenRefreshReason: 'role_change',
        },
        { merge: true }
      );

      // 8. Log the change for audit
      await admin.firestore().collection('auditLog').add({
        action: 'setUserRole',
        targetUserId: uid,
        targetUserEmail: user.email,
        performedBy: request.auth.uid,
        performedByEmail: callerToken.email || 'unknown',
        oldRole: callerToken.role || null,
        newRole: role,
        companyId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        message: `Role '${role}' set for user ${uid}`,
        uid,
        role,
        companyId,
      };
    } catch (error) {
      // Handle known errors
      if (error instanceof HttpsError) {
        throw error;
      }

      // Log unexpected errors
      console.error('Error setting user role:', error);
      throw new HttpsError('internal', 'Failed to set user role');
    }
  }
);

/**
 * Helper function to initialize admin user (for bootstrapping)
 * This should be called once to create the first admin user
 * After that, admins can use setUserRole to create other admins
 *
 * SECURITY NOTE: This is intentionally not exported as a callable function
 * Call this manually via Firebase Functions shell or as a one-time migration
 */
export async function bootstrapFirstAdmin(
  email: string,
  password: string,
  companyId: string
): Promise<void> {
  try {
    // Create user if doesn't exist
    let user: admin.auth.UserRecord;
    try {
      user = await admin.auth().getUserByEmail(email);
      // User already exists - continue with setting claims
    } catch {
      user = await admin.auth().createUser({
        email,
        password,
        emailVerified: false,
      });
      // Created new user successfully
    }

    // Set admin claims
    await admin.auth().setCustomUserClaims(user.uid, {
      role: 'admin',
      companyId,
      updatedAt: Date.now(),
    });

    // Create user document
    await admin.firestore().collection('users').doc(user.uid).set(
      {
        email: user.email,
        role: 'admin',
        companyId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        roleUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // Admin user bootstrapped successfully
  } catch (error) {
    console.error('Error bootstrapping admin:', error);
    throw error;
  }
}
