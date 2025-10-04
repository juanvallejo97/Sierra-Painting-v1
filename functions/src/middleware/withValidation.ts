/**
 * Centralized Validation Middleware for Cloud Functions
 * 
 * PURPOSE:
 * Provides a unified wrapper for callable Cloud Functions that enforces:
 * - Authentication (context.auth?.uid)
 * - App Check verification (context.app?.token)
 * - Input validation (Zod schema)
 * - Standardized error mapping (400, 401, 403)
 * - Structured logging with requestId, uid, and version
 * 
 * RESPONSIBILITIES:
 * - Verify user authentication
 * - Verify App Check token (if enabled)
 * - Validate and parse input data against provided schema
 * - Map errors to appropriate HTTP status codes
 * - Log all requests with structured context
 * - Return typed, validated payload to handler
 * 
 * USAGE:
 * ```typescript
 * import { withValidation } from './middleware/withValidation';
 * import { TimeInSchema } from './schemas';
 * 
 * export const clockIn = withValidation(TimeInSchema, {
 *   requireAuth: true,
 *   requireAppCheck: true,
 *   requireAdmin: false,
 * })(async (data, context) => {
 *   // data is now typed and validated
 *   // context includes auth and app
 *   const { jobId, at, geo } = data;
 *   // ... function logic
 *   return { success: true, entryId: '...' };
 * });
 * ```
 * 
 * ERROR MAPPING:
 * - 400 (invalid-argument): Schema validation failed
 * - 401 (unauthenticated): Missing or invalid auth token
 * - 403 (permission-denied): Missing App Check token or insufficient permissions
 * 
 * LOGGING:
 * - Logs include: requestId, uid, version, latencyMs
 * - Validation errors are logged at WARN level
 * - Internal errors are logged at ERROR level
 * - Success is logged at INFO level
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { z } from 'zod';
import { log, getOrCreateRequestId } from '../lib/ops';
import { getDeploymentConfig } from '../config/deployment';

// ============================================================
// TYPES
// ============================================================

export interface ValidationOptions {
  /**
   * Require user to be authenticated (context.auth exists)
   * @default true
   */
  requireAuth?: boolean;

  /**
   * Require App Check token (context.app exists)
   * @default true
   */
  requireAppCheck?: boolean;

  /**
   * Require user to have admin role
   * @default false
   */
  requireAdmin?: boolean;

  /**
   * Custom role check function
   */
  requireRole?: (role: string) => boolean;

  /**
   * Version string for logging
   * @default "2.0.0-refactor"
   */
  version?: string;

  /**
   * Function name for deployment config lookup
   * If not provided, deployment config will use defaults
   */
  functionName?: string;
}

export type ValidatedHandler<TInput, TOutput> = (
  data: TInput,
  context: functions.https.CallableContext & {
    auth: NonNullable<functions.https.CallableContext['auth']>;
    requestId: string;
  }
) => Promise<TOutput>;

// ============================================================
// MAIN MIDDLEWARE FUNCTION
// ============================================================

/**
 * Creates a validated callable Cloud Function with auth and App Check guards
 * 
 * @param schema - Zod schema for input validation
 * @param options - Validation options (auth, app check, role requirements)
 * @returns Higher-order function that wraps the handler
 */
export function withValidation<TInput, TOutput>(
  schema: z.ZodSchema<TInput>,
  options: ValidationOptions = {}
) {
  // Default options
  const {
    requireAuth = true,
    requireAppCheck = true,
    requireAdmin = false,
    requireRole,
    version = '2.0.0-refactor',
    functionName,
  } = options;

  return (handler: ValidatedHandler<TInput, TOutput>) => {
    // Get deployment config if functionName is provided
    const deploymentConfig = functionName ? getDeploymentConfig(functionName) : {};
    
    return functions
      .runWith({
        ...deploymentConfig,
        enforceAppCheck: requireAppCheck,
        consumeAppCheckToken: requireAppCheck, // Prevent replay attacks
      })
      .https.onCall(async (data: unknown, context: functions.https.CallableContext) => {
        const startTime = Date.now();
        
        // Generate or extract request ID
        const requestId = getOrCreateRequestId(
          context.rawRequest?.headers as Record<string, string | string[]> | undefined
        );

        // Create logger with base context
        const baseLogger = log.child({ 
          requestId, 
          version,
          functionName: handler.name || 'anonymous',
        });

        try {
          // ========================================
          // 1. PAYLOAD SIZE CHECK
          // ========================================
          
          // Limit payload size to 10MB (10 * 1024 * 1024 bytes)
          const MAX_PAYLOAD_SIZE = 10 * 1024 * 1024;
          const payloadSize = JSON.stringify(data).length;
          
          if (payloadSize > MAX_PAYLOAD_SIZE) {
            baseLogger.warn('request_payload_too_large', {
              payloadSize,
              maxSize: MAX_PAYLOAD_SIZE,
            });
            throw new functions.https.HttpsError(
              'invalid-argument',
              `Payload size (${payloadSize} bytes) exceeds maximum allowed size (${MAX_PAYLOAD_SIZE} bytes)`
            );
          }

          // ========================================
          // 2. AUTHENTICATION CHECK
          // ========================================
          
          if (requireAuth && !context.auth) {
            baseLogger.warn('request_unauthenticated', {
              reason: 'Missing auth context',
            });
            throw new functions.https.HttpsError(
              'unauthenticated',
              'User must be authenticated'
            );
          }

          // Add user context to logger if authenticated
          const userId = context.auth?.uid;
          const logger = userId 
            ? baseLogger.child({ userId })
            : baseLogger;

          // ========================================
          // 3. APP CHECK VERIFICATION
          // ========================================
          
          if (requireAppCheck && !context.app) {
            logger.warn('request_app_check_failed', {
              reason: 'Missing App Check token',
            });
            throw new functions.https.HttpsError(
              'failed-precondition',
              'App Check validation failed'
            );
          }

          // ========================================
          // 4. ROLE AUTHORIZATION CHECK
          // ========================================

          if ((requireAdmin || requireRole) && context.auth) {
            const db = admin.firestore();
            const userDoc = await db.collection('users').doc(context.auth.uid).get();

            if (!userDoc.exists) {
              logger.warn('request_user_not_found', {
                userId: context.auth.uid,
              });
              throw new functions.https.HttpsError(
                'not-found',
                'User profile not found'
              );
            }

            const userData = userDoc.data();
            const userRole = userData?.role as string | undefined;

            if (requireAdmin && userRole !== 'admin') {
              logger.warn('request_permission_denied', {
                reason: 'Admin role required',
                userRole,
              });
              throw new functions.https.HttpsError(
                'permission-denied',
                'User must be an admin'
              );
            }

            if (requireRole && !requireRole(userRole || '')) {
              logger.warn('request_permission_denied', {
                reason: 'Insufficient role',
                userRole,
              });
              throw new functions.https.HttpsError(
                'permission-denied',
                'Insufficient permissions'
              );
            }
          }

          // ========================================
          // 5. INPUT VALIDATION
          // ========================================

          let validatedData: TInput;
          try {
            validatedData = schema.parse(data);
            logger.debug('request_validated', {
              dataSize: JSON.stringify(data).length,
            });
          } catch (error: unknown) {
            if (error instanceof z.ZodError) {
              const errorDetails = error.errors.map(e => ({
                path: e.path.join('.'),
                message: e.message,
              }));
              
              logger.warn('request_validation_failed', {
                errors: errorDetails,
              });

              throw new functions.https.HttpsError(
                'invalid-argument',
                `Validation failed: ${errorDetails.map(e => `${e.path}: ${e.message}`).join('; ')}`
              );
            }

            // Unknown error during validation
            logger.error('request_validation_error', error as Error);
            throw new functions.https.HttpsError(
              'invalid-argument',
              'Invalid request data'
            );
          }

          // ========================================
          // 6. EXECUTE HANDLER
          // ========================================

          logger.info('request_processing', {
            authenticated: !!context.auth,
            appCheckValid: !!context.app,
          });

          // Create enhanced context with guaranteed auth and requestId
          const enhancedContext = {
            ...context,
            auth: context.auth!,
            requestId,
          };

          const result = await handler(validatedData, enhancedContext);

          // ========================================
          // 7. SUCCESS LOGGING
          // ========================================

          const latencyMs = Date.now() - startTime;
          logger.perf(handler.name || 'function', latencyMs);
          logger.info('request_success', {
            latencyMs,
          });

          return result;

        } catch (error: unknown) {
          // ========================================
          // 8. ERROR HANDLING
          // ========================================

          const latencyMs = Date.now() - startTime;

          // If already an HttpsError, log and rethrow
          if (error instanceof functions.https.HttpsError) {
            baseLogger.warn('request_failed', {
              errorCode: error.code,
              errorMessage: error.message,
              latencyMs,
            });
            throw error;
          }

          // Unknown error - log and wrap
          baseLogger.error('request_error', error as Error);
          throw new functions.https.HttpsError(
            'internal',
            'An internal error occurred'
          );
        }
      });
  };
}

// ============================================================
// CONVENIENCE EXPORTS
// ============================================================

/**
 * Validation preset for public endpoints (no auth required)
 */
export const publicEndpoint = (options: Partial<ValidationOptions> = {}) => ({
  requireAuth: false,
  requireAppCheck: true,
  ...options,
});

/**
 * Validation preset for authenticated endpoints
 */
export const authenticatedEndpoint = (options: Partial<ValidationOptions> = {}) => ({
  requireAuth: true,
  requireAppCheck: true,
  ...options,
});

/**
 * Validation preset for admin-only endpoints
 */
export const adminEndpoint = (options: Partial<ValidationOptions> = {}) => ({
  requireAuth: true,
  requireAppCheck: true,
  requireAdmin: true,
  ...options,
});
