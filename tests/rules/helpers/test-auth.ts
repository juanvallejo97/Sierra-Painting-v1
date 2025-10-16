/**
 * Test Authentication Helpers
 *
 * PURPOSE:
 * Provides standardized authentication contexts for Firestore security rules testing.
 * Simplifies test setup with pre-configured role and company claim builders.
 *
 * USAGE:
 * ```typescript
 * import { createAdminAuth, createWorkerAuth, getAuthenticatedDb } from './helpers/test-auth';
 *
 * const adminAuth = createAdminAuth('company-a');
 * const db = getAuthenticatedDb(testEnv, adminAuth);
 * await assertSucceeds(db.collection('jobs').doc('job-1').get());
 * ```
 *
 * AUTH CONTEXT STRUCTURE:
 * - uid: User ID (auto-generated if not provided)
 * - token.company_id: Company ID for multi-tenant isolation
 * - token.role: RBAC role (admin, manager, staff, worker)
 * - token.email: Test email address
 *
 * ROLE DEFINITIONS:
 * - admin: Full access to all company resources (create/read/update/delete)
 * - manager: Can manage resources but not delete critical data
 * - staff: Can create/read/update basic resources (customers, time tracking)
 * - worker: Can only read own assignments and create clock events
 *
 * TEST DATA CONVENTIONS:
 * - Company IDs: 'company-a', 'company-b', 'company-c'
 * - User IDs: '<role>-<companyId>' (e.g., 'admin-company-a')
 * - Emails: '<role>@<companyId>.test'
 */

import type { RulesTestContext } from '@firebase/rules-unit-testing';

/**
 * Authentication context for Firestore emulator testing.
 * Matches Firebase Auth custom claims structure used in production.
 */
export interface AuthContext {
  uid: string;
  token: {
    company_id: string;
    role: 'admin' | 'manager' | 'staff' | 'worker';
    email: string;
  };
}

/**
 * Creates an admin authentication context.
 *
 * Admins have full CRUD access to all company-scoped resources:
 * - Create/read/update/delete jobs, customers, estimates, invoices
 * - Manage assignments and user roles
 * - View all time entries (read-only, writes are function-only)
 *
 * @param companyId Company identifier for multi-tenant isolation
 * @param uid Optional custom user ID (defaults to 'admin-{companyId}')
 * @returns Admin authentication context
 *
 * @example
 * const adminAuth = createAdminAuth('company-a');
 * const db = getAuthenticatedDb(testEnv, adminAuth);
 * await assertSucceeds(db.collection('jobs').add({ companyId: 'company-a', ... }));
 */
export function createAdminAuth(companyId: string, uid?: string): AuthContext {
  return {
    uid: uid || `admin-${companyId}`,
    token: {
      company_id: companyId,
      role: 'admin',
      email: `admin@${companyId}.test`,
    },
  };
}

/**
 * Creates a manager authentication context.
 *
 * Managers can:
 * - Read all company resources
 * - Create/update jobs, customers, estimates, invoices
 * - Manage assignments (create/update/delete)
 * - Cannot delete jobs, customers, or financial records
 *
 * @param companyId Company identifier for multi-tenant isolation
 * @param uid Optional custom user ID (defaults to 'manager-{companyId}')
 * @returns Manager authentication context
 *
 * @example
 * const managerAuth = createManagerAuth('company-a');
 * const db = getAuthenticatedDb(testEnv, managerAuth);
 * await assertSucceeds(db.collection('assignments').doc('asgn-1').update({ active: false }));
 * await assertFails(db.collection('jobs').doc('job-1').delete()); // Managers cannot delete
 */
export function createManagerAuth(companyId: string, uid?: string): AuthContext {
  return {
    uid: uid || `manager-${companyId}`,
    token: {
      company_id: companyId,
      role: 'manager',
      email: `manager@${companyId}.test`,
    },
  };
}

/**
 * Creates a staff authentication context.
 *
 * Staff members can:
 * - Read company resources (jobs, customers)
 * - Create/update customers
 * - View time entries (read-only)
 * - Cannot create jobs or assignments
 * - Cannot delete any resources
 *
 * @param companyId Company identifier for multi-tenant isolation
 * @param uid Optional custom user ID (defaults to 'staff-{companyId}')
 * @returns Staff authentication context
 *
 * @example
 * const staffAuth = createStaffAuth('company-a', 'staff-123');
 * const db = getAuthenticatedDb(testEnv, staffAuth);
 * await assertSucceeds(db.collection('customers').add({ companyId: 'company-a', ... }));
 * await assertFails(db.collection('jobs').add({ companyId: 'company-a', ... })); // Staff cannot create jobs
 */
export function createStaffAuth(companyId: string, uid?: string): AuthContext {
  return {
    uid: uid || `staff-${companyId}`,
    token: {
      company_id: companyId,
      role: 'staff',
      email: `staff@${companyId}.test`,
    },
  };
}

/**
 * Creates a worker authentication context.
 *
 * Workers can:
 * - Read own assignments only
 * - Read own time entries only
 * - Create clock events (append-only)
 * - Cannot create time entries directly (function-only)
 * - Cannot read other workers' data
 * - Cannot modify or delete anything
 *
 * @param companyId Company identifier for multi-tenant isolation
 * @param uid Optional custom user ID (defaults to 'worker-{companyId}')
 * @returns Worker authentication context
 *
 * @example
 * const workerAuth = createWorkerAuth('company-a', 'worker-123');
 * const db = getAuthenticatedDb(testEnv, workerAuth);
 * await assertSucceeds(db.collection('clockEvents').add({
 *   companyId: 'company-a',
 *   userId: 'worker-123',
 *   type: 'in',
 *   ...
 * }));
 * await assertFails(db.collection('timeEntries').add({ ... })); // Workers cannot create time entries
 */
export function createWorkerAuth(companyId: string, uid?: string): AuthContext {
  return {
    uid: uid || `worker-${companyId}`,
    token: {
      company_id: companyId,
      role: 'worker',
      email: `worker@${companyId}.test`,
    },
  };
}

/**
 * Creates an unauthenticated context (null).
 *
 * Used to test that unauthenticated users are denied access to all resources.
 *
 * @returns null (unauthenticated)
 *
 * @example
 * const unauthDb = testEnv.unauthenticatedContext();
 * await assertFails(unauthDb.firestore().collection('jobs').doc('job-1').get());
 */
export function createUnauthenticatedContext(): null {
  return null;
}

/**
 * Gets an authenticated Firestore database instance for testing.
 *
 * Wraps the testEnv.authenticatedContext() and testEnv.unauthenticatedContext()
 * methods for cleaner test code.
 *
 * @param testEnv Firestore rules test environment
 * @param auth Authentication context or null for unauthenticated
 * @returns Firestore context for making database calls
 *
 * @example
 * const adminAuth = createAdminAuth('company-a');
 * const db = getAuthenticatedDb(testEnv, adminAuth);
 * await assertSucceeds(db.firestore().collection('jobs').doc('job-1').get());
 *
 * @example
 * const unauthDb = getAuthenticatedDb(testEnv, null);
 * await assertFails(unauthDb.firestore().collection('jobs').doc('job-1').get());
 */
export function getAuthenticatedDb(
  testEnv: RulesTestContext,
  auth: AuthContext | null
): any {
  if (!auth) {
    return testEnv.unauthenticatedContext();
  }
  return testEnv.authenticatedContext(auth.uid, auth.token);
}

/**
 * Standard test company IDs for multi-tenant testing.
 * Use these constants for consistency across test files.
 */
export const TEST_COMPANIES = {
  A: 'company-a',
  B: 'company-b',
  C: 'company-c',
} as const;

/**
 * Standard test user IDs for role-based testing.
 * Pre-configured UIDs that match the createXAuth() defaults.
 */
export const TEST_USERS = {
  ADMIN_A: 'admin-company-a',
  MANAGER_A: 'manager-company-a',
  STAFF_A: 'staff-company-a',
  WORKER_A: 'worker-company-a',

  ADMIN_B: 'admin-company-b',
  MANAGER_B: 'manager-company-b',
  STAFF_B: 'staff-company-b',
  WORKER_B: 'worker-company-b',
} as const;

/**
 * Creates a batch of authentication contexts for testing cross-company isolation.
 *
 * @param companyA First company ID
 * @param companyB Second company ID
 * @returns Object with auth contexts for both companies
 *
 * @example
 * const { adminA, adminB, staffA, staffB } = createMultiTenantContexts('company-a', 'company-b');
 *
 * // Test company A admin cannot read company B data
 * const dbA = getAuthenticatedDb(testEnv, adminA);
 * await assertFails(dbA.firestore().collection('jobs').doc('job-in-company-b').get());
 */
export function createMultiTenantContexts(
  companyA: string = TEST_COMPANIES.A,
  companyB: string = TEST_COMPANIES.B
) {
  return {
    adminA: createAdminAuth(companyA),
    managerA: createManagerAuth(companyA),
    staffA: createStaffAuth(companyA),
    workerA: createWorkerAuth(companyA),

    adminB: createAdminAuth(companyB),
    managerB: createManagerAuth(companyB),
    staffB: createStaffAuth(companyB),
    workerB: createWorkerAuth(companyB),

    unauth: createUnauthenticatedContext(),
  };
}

/**
 * Type guard to check if an auth context has a specific role.
 *
 * @param auth Authentication context
 * @param role Role to check
 * @returns True if auth context has the specified role
 *
 * @example
 * const auth = createAdminAuth('company-a');
 * if (hasRole(auth, 'admin')) {
 *   // Do admin-specific test
 * }
 */
export function hasRole(
  auth: AuthContext,
  role: 'admin' | 'manager' | 'staff' | 'worker'
): boolean {
  return auth.token.role === role;
}

/**
 * Type guard to check if an auth context belongs to a specific company.
 *
 * @param auth Authentication context
 * @param companyId Company ID to check
 * @returns True if auth context belongs to the specified company
 *
 * @example
 * const auth = createAdminAuth('company-a');
 * if (belongsToCompany(auth, 'company-a')) {
 *   // Do company-specific test
 * }
 */
export function belongsToCompany(auth: AuthContext, companyId: string): boolean {
  return auth.token.company_id === companyId;
}
