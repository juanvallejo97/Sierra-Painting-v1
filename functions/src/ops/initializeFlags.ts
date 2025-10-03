/**
 * Initialize Feature Flags
 * 
 * Callable function to initialize the config/flags document with default values.
 * Should be called once during initial deployment or can be called manually
 * to reset flags to defaults.
 * 
 * USAGE:
 * firebase deploy --only functions:initializeFlags
 * 
 * Then call from Firebase Console or via API:
 * POST https://us-central1-<project-id>.cloudfunctions.net/initializeFlags
 */

import * as functions from 'firebase-functions';
import { initializeFlags } from '../lib/ops';

export const initializeFlagsFunction = functions
  .runWith({
    enforceAppCheck: true,
    consumeAppCheckToken: true, // Prevent replay attacks
  })
  .https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  // App Check validation (defense in depth)
  if (!context.app) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'App Check validation failed'
    );
  }

  // Admin-only operation for security
  const admin = await import('firebase-admin');
  const db = admin.firestore();
  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  
  if (!userDoc.exists || userDoc.data()?.role !== 'admin') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can initialize feature flags'
    );
  }
  
  try {
    await initializeFlags();
    
    return {
      success: true,
      message: 'Feature flags initialized successfully',
    };
  } catch (error) {
    throw new functions.https.HttpsError(
      'internal',
      'Failed to initialize feature flags',
      error
    );
  }
});
