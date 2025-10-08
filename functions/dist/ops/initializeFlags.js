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
import { z } from 'zod';
import { withValidation, adminEndpoint } from '../middleware/withValidation';
import { initializeFlags } from '../lib/ops';
// Empty schema - no input required
const InitializeFlagsSchema = z.object({}).strict();
export const initializeFlagsFunction = withValidation(InitializeFlagsSchema, adminEndpoint({ /* functionName?: 'initializeFlags' */}))(async () => {
    await initializeFlags();
    return {
        success: true,
        message: 'Feature flags initialized successfully',
    };
});
