/**
 * Environment Configuration
 * 
 * Type-safe environment variable access with validation.
 * Fails fast on missing required variables at startup.
 * 
 * Usage:
 *   import { env } from '@/lib/config/env';
 *   const apiKey = env.NEXT_PUBLIC_FIREBASE_API_KEY;
 */

import { z } from 'zod';

/**
 * Client Environment Schema (NEXT_PUBLIC_* variables)
 * These are exposed to the browser
 */
const clientEnvSchema = z.object({
  NEXT_PUBLIC_APP_URL: z.string().url().default('http://localhost:3000'),
  NEXT_PUBLIC_FIREBASE_PROJECT_ID: z.string().min(1),
  NEXT_PUBLIC_FIREBASE_API_KEY: z.string().min(1),
  NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN: z.string().min(1),
  NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET: z.string().min(1),
  NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID: z.string().min(1),
  NEXT_PUBLIC_FIREBASE_APP_ID: z.string().min(1),
  NEXT_PUBLIC_GA_MEASUREMENT_ID: z.string().optional(),
});

/**
 * Server Environment Schema
 * These are only available server-side
 */
const serverEnvSchema = z.object({
  NODE_ENV: z.enum(['development', 'staging', 'production']).default('development'),
  
  // Firebase Admin
  FIREBASE_ADMIN_SERVICE_ACCOUNT: z.string().optional(),
  FIREBASE_ADMIN_PROJECT_ID: z.string().optional(),
  FIREBASE_ADMIN_CLIENT_EMAIL: z.string().email().optional(),
  FIREBASE_ADMIN_PRIVATE_KEY: z.string().optional(),
  
  // Firebase Emulators
  USE_FIREBASE_EMULATORS: z
    .string()
    .optional()
    .default('false')
    .transform((val) => val === 'true'),
  FIREBASE_AUTH_EMULATOR_HOST: z.string().optional(),
  FIRESTORE_EMULATOR_HOST: z.string().optional(),
  FIREBASE_STORAGE_EMULATOR_HOST: z.string().optional(),
  
  // API Configuration
  API_TIMEOUT_MS: z.coerce.number().positive().default(30000),
  API_MAX_RETRIES: z.coerce.number().int().nonnegative().default(3),
  API_RETRY_DELAY_MS: z.coerce.number().positive().default(1000),
  
  // Session Configuration
  SESSION_COOKIE_NAME: z.string().default('__session'),
  SESSION_COOKIE_MAX_AGE: z.coerce.number().positive().default(1209600), // 14 days
  CSRF_SECRET: z.string().min(32).default('change-this-in-production-use-random-string'),
  
  // Caching
  SWR_REVALIDATE_INTERVAL: z.coerce.number().positive().default(300),
  ISR_REVALIDATE_JOBS: z.coerce.number().positive().default(60),
  ISR_REVALIDATE_INVOICES: z.coerce.number().positive().default(300),
  
  // Observability
  ENABLE_LOGGING: z
    .string()
    .optional()
    .default('true')
    .transform((val) => val === 'true'),
  LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
  ENABLE_PERFORMANCE_MONITORING: z
    .string()
    .optional()
    .default('true')
    .transform((val) => val === 'true'),
  TRACE_SAMPLE_RATE: z.coerce.number().min(0).max(1).default(1.0),
  
  // Development
  ANALYZE: z
    .string()
    .optional()
    .default('false')
    .transform((val) => val === 'true'),
  NEXT_TELEMETRY_DISABLED: z.coerce.number().optional(),
});

/**
 * Combined environment schema
 */
const envSchema = clientEnvSchema.merge(serverEnvSchema);

type ClientEnv = z.infer<typeof clientEnvSchema>;
type ServerEnv = z.infer<typeof serverEnvSchema>;
type FullEnv = ClientEnv & ServerEnv;

/**
 * Validate and parse environment variables
 */
function parseEnv(): ClientEnv | FullEnv {
  // In browser, only client env vars are available
  if (typeof window !== 'undefined') {
    const parsed = clientEnvSchema.safeParse({
      NEXT_PUBLIC_APP_URL: process.env.NEXT_PUBLIC_APP_URL,
      NEXT_PUBLIC_FIREBASE_PROJECT_ID: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
      NEXT_PUBLIC_FIREBASE_API_KEY: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
      NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
      NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
      NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
      NEXT_PUBLIC_FIREBASE_APP_ID: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
      NEXT_PUBLIC_GA_MEASUREMENT_ID: process.env.NEXT_PUBLIC_GA_MEASUREMENT_ID,
    });

    if (!parsed.success) {
      console.error('❌ Invalid client environment variables:', parsed.error.flatten().fieldErrors);
      throw new Error('Invalid client environment variables');
    }

    return parsed.data;
  }

  // On server, all env vars are available
  const parsed = envSchema.safeParse(process.env);

  if (!parsed.success) {
    console.error('❌ Invalid environment variables:', parsed.error.flatten().fieldErrors);
    throw new Error('Invalid environment variables');
  }

  return parsed.data;
}

/**
 * Type-safe environment variables
 * 
 * Validated at module load time, fails fast if invalid
 */
export const env = parseEnv();

/**
 * Environment type (inferred from schema)
 */
export type Env = FullEnv;

/**
 * Check if running in development (server-side only)
 */
export const isDevelopment = typeof window === 'undefined' && (env as FullEnv).NODE_ENV === 'development';

/**
 * Check if running in staging (server-side only)
 */
export const isStaging = typeof window === 'undefined' && (env as FullEnv).NODE_ENV === 'staging';

/**
 * Check if running in production (server-side only)
 */
export const isProduction = typeof window === 'undefined' && (env as FullEnv).NODE_ENV === 'production';

/**
 * Check if running on server
 */
export const isServer = typeof window === 'undefined';

/**
 * Check if running in browser
 */
export const isBrowser = typeof window !== 'undefined';

