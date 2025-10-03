/**
 * Firebase Client Configuration
 * 
 * Initializes Firebase client SDK for browser-side usage.
 * Used for authentication and client-side Firestore access.
 * 
 * Usage:
 *   import { auth, db } from '@/lib/firebase/client';
 */

import { initializeApp, getApps, FirebaseApp } from 'firebase/app';
import { getAuth, connectAuthEmulator, Auth } from 'firebase/auth';
import { getFirestore, connectFirestoreEmulator, Firestore } from 'firebase/firestore';
import { getStorage, connectStorageEmulator, FirebaseStorage } from 'firebase/storage';
import { env } from '@/lib/config/env';

/**
 * Firebase client configuration
 */
const firebaseConfig = {
  apiKey: env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: env.NEXT_PUBLIC_FIREBASE_APP_ID,
};

/**
 * Initialize Firebase app
 * Returns existing app if already initialized
 */
function initializeFirebaseApp(): FirebaseApp {
  const apps = getApps();
  if (apps.length > 0) {
    return apps[0]!;
  }
  return initializeApp(firebaseConfig);
}

/**
 * Firebase app instance
 */
export const app = initializeFirebaseApp();

/**
 * Firebase Auth instance
 */
export const auth: Auth = getAuth(app);

/**
 * Firestore instance
 */
export const db: Firestore = getFirestore(app);

/**
 * Firebase Storage instance
 */
export const storage: FirebaseStorage = getStorage(app);

/**
 * Connect to emulators in development
 * Only runs once, subsequent calls are ignored
 */
if (typeof window !== 'undefined' && env.NEXT_PUBLIC_APP_URL.includes('localhost')) {
  // Check if emulators are already connected
  // @ts-expect-error - Accessing private property for emulator check
  if (!auth._config?.emulator) {
    try {
      // Parse emulator hosts from environment
      const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
      const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
      const storageHost = process.env.FIREBASE_STORAGE_EMULATOR_HOST || '127.0.0.1:9199';

      // Connect to emulators
      connectAuthEmulator(auth, `http://${authHost}`, { disableWarnings: true });
      
      const [firestoreHostname, firestorePort] = firestoreHost.split(':');
      connectFirestoreEmulator(db, firestoreHostname!, parseInt(firestorePort!, 10));
      
      const [storageHostname, storagePort] = storageHost.split(':');
      connectStorageEmulator(storage, storageHostname!, parseInt(storagePort!, 10));

      console.log('🔧 Connected to Firebase emulators');
    } catch (error) {
      console.warn('⚠️ Failed to connect to Firebase emulators:', error);
    }
  }
}

/**
 * Firebase error codes that can be handled
 */
export const FirebaseErrorCode = {
  // Auth errors
  INVALID_EMAIL: 'auth/invalid-email',
  USER_DISABLED: 'auth/user-disabled',
  USER_NOT_FOUND: 'auth/user-not-found',
  WRONG_PASSWORD: 'auth/wrong-password',
  EMAIL_ALREADY_IN_USE: 'auth/email-already-in-use',
  WEAK_PASSWORD: 'auth/weak-password',
  TOO_MANY_REQUESTS: 'auth/too-many-requests',
  NETWORK_REQUEST_FAILED: 'auth/network-request-failed',
  POPUP_CLOSED_BY_USER: 'auth/popup-closed-by-user',
  EXPIRED_TOKEN: 'auth/id-token-expired',
  INVALID_TOKEN: 'auth/invalid-id-token',

  // Firestore errors
  PERMISSION_DENIED: 'permission-denied',
  NOT_FOUND: 'not-found',
  ALREADY_EXISTS: 'already-exists',
  RESOURCE_EXHAUSTED: 'resource-exhausted',
  FAILED_PRECONDITION: 'failed-precondition',
  ABORTED: 'aborted',
  OUT_OF_RANGE: 'out-of-range',
  UNIMPLEMENTED: 'unimplemented',
  INTERNAL: 'internal',
  UNAVAILABLE: 'unavailable',
  DATA_LOSS: 'data-loss',
  UNAUTHENTICATED: 'unauthenticated',
} as const;

/**
 * Get user-friendly error message from Firebase error
 */
export function getFirebaseErrorMessage(error: unknown): string {
  if (typeof error !== 'object' || error === null) {
    return 'An unexpected error occurred';
  }

  const firebaseError = error as { code?: string; message?: string };

  switch (firebaseError.code) {
    case FirebaseErrorCode.INVALID_EMAIL:
      return 'Invalid email address';
    case FirebaseErrorCode.USER_DISABLED:
      return 'This account has been disabled';
    case FirebaseErrorCode.USER_NOT_FOUND:
      return 'No account found with this email';
    case FirebaseErrorCode.WRONG_PASSWORD:
      return 'Incorrect password';
    case FirebaseErrorCode.EMAIL_ALREADY_IN_USE:
      return 'An account with this email already exists';
    case FirebaseErrorCode.WEAK_PASSWORD:
      return 'Password is too weak. Use at least 6 characters';
    case FirebaseErrorCode.TOO_MANY_REQUESTS:
      return 'Too many failed attempts. Please try again later';
    case FirebaseErrorCode.NETWORK_REQUEST_FAILED:
      return 'Network error. Please check your connection';
    case FirebaseErrorCode.POPUP_CLOSED_BY_USER:
      return 'Sign-in cancelled';
    case FirebaseErrorCode.EXPIRED_TOKEN:
      return 'Session expired. Please sign in again';
    case FirebaseErrorCode.INVALID_TOKEN:
      return 'Invalid session. Please sign in again';
    case FirebaseErrorCode.PERMISSION_DENIED:
      return 'Permission denied';
    case FirebaseErrorCode.NOT_FOUND:
      return 'Resource not found';
    case FirebaseErrorCode.UNAUTHENTICATED:
      return 'Authentication required';
    default:
      return firebaseError.message || 'An error occurred';
  }
}
