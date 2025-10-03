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

export const initializeFlagsFunction = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  // This function should ideally be admin-only, but for initial setup
  // we'll allow any authenticated user. Add admin check if needed.
  
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
