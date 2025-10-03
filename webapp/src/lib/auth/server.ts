/**
 * Server-side authentication helpers
 * 
 * These functions run server-side only and provide:
 * - Token verification
 * - User session management
 * - Role-based access control
 * 
 * Usage in Server Components:
 *   import { getUser, requireAuth, requireRole } from '@/lib/auth/server';
 *   
 *   const user = await getUser();
 *   if (!user) redirect('/web/login');
 */

import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import {
  verifyIdToken,
  getUserDocument,
  userHasRole,
  UserRole,
} from '@/lib/firebase/admin';

const SESSION_COOKIE_NAME = process.env.SESSION_COOKIE_NAME || '__session';

/**
 * Session user type (combines Auth + Firestore data)
 */
export interface SessionUser {
  uid: string;
  email: string;
  displayName: string | null;
  photoURL: string | null;
  role: UserRole;
  orgId: string | null;
  emailVerified: boolean;
}

/**
 * Get session token from cookies
 * 
 * @returns Session token or null if not found
 */
function getSessionToken(): string | null {
  const cookieStore = cookies();
  const sessionCookie = cookieStore.get(SESSION_COOKIE_NAME);
  return sessionCookie?.value || null;
}

/**
 * Get current user from session (server-side only)
 * 
 * Verifies the session token and fetches user data from Firestore.
 * Returns null if no valid session exists.
 * 
 * @returns User object or null
 */
export async function getUser(): Promise<SessionUser | null> {
  try {
    const token = getSessionToken();
    
    if (!token) {
      return null;
    }

    // Verify token
    const decodedToken = await verifyIdToken(token);
    
    // Get user document from Firestore
    const userDoc = await getUserDocument(decodedToken.uid);
    
    if (!userDoc) {
      console.warn('⚠️ User token valid but no Firestore document found');
      return null;
    }

    // Combine auth and Firestore data
    return {
      uid: decodedToken.uid,
      email: decodedToken.email || userDoc.email,
      displayName: userDoc.displayName,
      photoURL: userDoc.photoURL,
      role: userDoc.role,
      orgId: userDoc.orgId,
      emailVerified: decodedToken.email_verified || false,
    };
  } catch (error) {
    console.error('❌ Failed to get user session:', error);
    return null;
  }
}

/**
 * Require authentication (redirect if not authenticated)
 * 
 * Use in Server Components or Server Actions to ensure user is logged in.
 * Redirects to login page if not authenticated.
 * 
 * @param redirectTo - Path to redirect to after login (optional)
 * @returns Authenticated user
 * @throws Redirects to login if not authenticated
 */
export async function requireAuth(redirectTo?: string): Promise<SessionUser> {
  const user = await getUser();
  
  if (!user) {
    const loginUrl = redirectTo
      ? `/web/login?redirect=${encodeURIComponent(redirectTo)}`
      : '/web/login';
    redirect(loginUrl);
  }
  
  return user;
}

/**
 * Require specific role (redirect if insufficient permissions)
 * 
 * Use in Server Components or Server Actions to enforce role-based access.
 * Redirects to appropriate page if user doesn't have required role.
 * 
 * @param role - Required role
 * @param redirectTo - Path to redirect to if insufficient permissions (optional)
 * @returns Authenticated user with required role
 * @throws Redirects if not authenticated or insufficient permissions
 */
export async function requireRole(
  role: UserRole,
  redirectTo?: string
): Promise<SessionUser> {
  const user = await requireAuth(redirectTo);
  
  const hasRole = await userHasRole(user.uid, role);
  
  if (!hasRole) {
    console.warn(`⚠️ User ${user.uid} attempted to access ${role}-only resource`);
    redirect(redirectTo || '/web/unauthorized');
  }
  
  return user;
}

/**
 * Check if current user has required role (no redirect)
 * 
 * @param role - Required role
 * @returns true if user has required role, false otherwise
 */
export async function hasRole(role: UserRole): Promise<boolean> {
  const user = await getUser();
  
  if (!user) {
    return false;
  }
  
  return await userHasRole(user.uid, role);
}

/**
 * Get user or throw error (for API routes)
 * 
 * Use in API routes where you want to return 401 instead of redirecting.
 * 
 * @returns Authenticated user
 * @throws Error if not authenticated
 */
export async function getUserOrThrow(): Promise<SessionUser> {
  const user = await getUser();
  
  if (!user) {
    throw new Error('Unauthenticated');
  }
  
  return user;
}
