/**
 * Firebase Admin SDK Configuration (Server-Side Only)
 * 
 * DO NOT import this file in client-side code!
 * 
 * Initializes Firebase Admin SDK for server-side operations:
 * - Token verification
 * - User management
 * - Firestore admin access
 * 
 * Usage (server-side only):
 *   import { adminAuth, adminDb } from '@/lib/firebase/admin';
 */

import { initializeApp, getApps, cert, App } from 'firebase-admin/app';
import { getAuth, Auth } from 'firebase-admin/auth';
import { getFirestore, Firestore } from 'firebase-admin/firestore';

/**
 * Initialize Firebase Admin
 * 
 * Uses service account credentials from environment variables.
 * Falls back to Application Default Credentials in cloud environments.
 */
function initializeFirebaseAdmin(): App {
  // Return existing app if already initialized
  const apps = getApps();
  if (apps.length > 0) {
    return apps[0]!;
  }

  // Check for service account file path
  const serviceAccountPath = process.env.FIREBASE_ADMIN_SERVICE_ACCOUNT;
  
  // Check for individual credential fields
  const projectId = process.env.FIREBASE_ADMIN_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_ADMIN_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_ADMIN_PRIVATE_KEY;

  try {
    // Option 1: Use service account file
    if (serviceAccountPath) {
      console.log('🔑 Initializing Firebase Admin with service account file');
      // Dynamic require for service account (server-side only)
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      const serviceAccount = require(serviceAccountPath);
      
      return initializeApp({
        credential: cert(serviceAccount),
      });
    }

    // Option 2: Use individual credential fields
    if (projectId && clientEmail && privateKey) {
      console.log('🔑 Initializing Firebase Admin with credential fields');
      
      return initializeApp({
        credential: cert({
          projectId,
          clientEmail,
          privateKey: privateKey.replace(/\\n/g, '\n'), // Handle escaped newlines
        }),
      });
    }

    // Option 3: Use Application Default Credentials (Cloud Run, Cloud Functions, etc.)
    console.log('🔑 Initializing Firebase Admin with Application Default Credentials');
    return initializeApp();
  } catch (error) {
    console.error('❌ Failed to initialize Firebase Admin:', error);
    throw new Error('Failed to initialize Firebase Admin SDK');
  }
}

/**
 * Firebase Admin App instance
 */
export const adminApp = initializeFirebaseAdmin();

/**
 * Firebase Admin Auth instance
 */
export const adminAuth: Auth = getAuth(adminApp);

/**
 * Firebase Admin Firestore instance
 */
export const adminDb: Firestore = getFirestore(adminApp);

/**
 * Configure Firestore settings
 */
if (process.env.FIRESTORE_EMULATOR_HOST) {
  console.log(
    '🔧 Connecting to Firestore emulator:',
    process.env.FIRESTORE_EMULATOR_HOST
  );
  // Emulator connection is automatic via FIRESTORE_EMULATOR_HOST env var
}

/**
 * User role type (must match Firestore schema)
 */
export type UserRole = 'admin' | 'crew_lead' | 'crew';

/**
 * User document from Firestore
 */
export interface UserDocument {
  uid: string;
  email: string;
  displayName: string | null;
  photoURL: string | null;
  role: UserRole;
  orgId: string | null;
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
}

/**
 * Verify Firebase ID token and return user
 * 
 * @param idToken - Firebase ID token from client
 * @returns Decoded token with user info
 * @throws Error if token is invalid or expired
 */
export async function verifyIdToken(idToken: string) {
  try {
    const decodedToken = await adminAuth.verifyIdToken(idToken);
    return decodedToken;
  } catch (error) {
    console.error('❌ Token verification failed:', error);
    throw error;
  }
}

/**
 * Get user document from Firestore
 * 
 * @param uid - User ID
 * @returns User document or null if not found
 */
export async function getUserDocument(uid: string): Promise<UserDocument | null> {
  try {
    const userDoc = await adminDb.collection('users').doc(uid).get();
    
    if (!userDoc.exists) {
      return null;
    }

    return userDoc.data() as UserDocument;
  } catch (error) {
    console.error('❌ Failed to get user document:', error);
    throw error;
  }
}

/**
 * Check if user has required role
 * 
 * @param uid - User ID
 * @param requiredRole - Required role
 * @returns true if user has required role or higher
 */
export async function userHasRole(uid: string, requiredRole: UserRole): Promise<boolean> {
  const user = await getUserDocument(uid);
  
  if (!user) {
    return false;
  }

  // Role hierarchy: admin > crew_lead > crew
  const roleHierarchy: Record<UserRole, number> = {
    admin: 3,
    crew_lead: 2,
    crew: 1,
  };

  const userRoleLevel = roleHierarchy[user.role] || 0;
  const requiredRoleLevel = roleHierarchy[requiredRole] || 0;

  return userRoleLevel >= requiredRoleLevel;
}
