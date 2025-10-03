/**
 * Feature Flag Service for Sierra Painting Cloud Functions
 * 
 * PURPOSE:
 * Provides runtime feature flag management backed by Firestore configuration.
 * Enables gradual rollout, A/B testing, and safe feature deployment.
 * 
 * RESPONSIBILITIES:
 * - Retrieve feature flags from Firestore config/flags document
 * - Cache flags in-memory for 30 seconds to reduce Firestore reads
 * - Provide type-safe flag access with sensible defaults
 * - Support various flag types (boolean, number, string)
 * 
 * USAGE:
 * ```typescript
 * import { getFlag } from './lib/ops';
 * 
 * const cacheEnabled = await getFlag('cache.localHotset', false);
 * if (cacheEnabled) {
 *   // Use cache
 * }
 * ```
 * 
 * STORAGE:
 * Flags are stored in Firestore at: config/flags
 * Document structure:
 * ```
 * {
 *   "cache.localHotset": { enabled: false, type: "boolean" },
 *   "bundles.enable": { enabled: false, type: "boolean" },
 *   "tracing.sample": { enabled: true, value: 1.0, type: "number" },
 *   "hedge.external": { enabled: false, type: "boolean" },
 *   "canary.cohortPercent": { enabled: true, value: 0, type: "number" }
 * }
 * ```
 * 
 * PERFORMANCE NOTES:
 * - Flags are cached in-memory for 30 seconds
 * - Only 1 Firestore read per 30 seconds per instance
 * - Cache is shared across function invocations in same instance
 * 
 * CONVENTIONS:
 * - Flag names use dot notation (cache.localHotset, tracing.sample)
 * - Boolean flags default to false for safety
 * - Numeric flags have explicit defaults
 */

import * as admin from 'firebase-admin';
import { log } from './logger';

// ============================================================
// TYPES
// ============================================================

export interface FlagConfig {
  enabled: boolean;
  value?: unknown;
  type: 'boolean' | 'number' | 'string';
  description?: string;
}

export interface FlagsDocument {
  [key: string]: FlagConfig;
}

// ============================================================
// CACHE
// ============================================================

interface CacheEntry {
  flags: FlagsDocument;
  timestamp: number;
}

let flagCache: CacheEntry | null = null;
const CACHE_TTL_MS = 30 * 1000; // 30 seconds

// ============================================================
// FLAG RETRIEVAL
// ============================================================

/**
 * Get a boolean feature flag value
 * 
 * @param flagName - Flag name (e.g., 'cache.localHotset')
 * @param defaultValue - Default value if flag not found
 * @returns Boolean flag value
 */
export async function getFlag(flagName: string, defaultValue: boolean): Promise<boolean>;

/**
 * Get a numeric feature flag value
 * 
 * @param flagName - Flag name (e.g., 'tracing.sample')
 * @param defaultValue - Default value if flag not found
 * @returns Numeric flag value
 */
export async function getFlag(flagName: string, defaultValue: number): Promise<number>;

/**
 * Get a string feature flag value
 * 
 * @param flagName - Flag name (e.g., 'feature.mode')
 * @param defaultValue - Default value if flag not found
 * @returns String flag value
 */
export async function getFlag(flagName: string, defaultValue: string): Promise<string>;

/**
 * Implementation of getFlag
 */
export async function getFlag<T extends boolean | number | string>(
  flagName: string,
  defaultValue: T
): Promise<T> {
  try {
    const flags = await getFlags();
    const flag = flags[flagName];

    if (!flag) {
      log.debug('flag_not_found', { flagName, defaultValue });
      return defaultValue;
    }

    if (!flag.enabled) {
      log.debug('flag_disabled', { flagName, defaultValue });
      return defaultValue;
    }

    // Return the value or enabled status based on type
    if (typeof defaultValue === 'boolean') {
      return flag.enabled as T;
    } else if (typeof defaultValue === 'number') {
      return (flag.value !== undefined ? flag.value : defaultValue) as T;
    } else if (typeof defaultValue === 'string') {
      return (flag.value !== undefined ? String(flag.value) : defaultValue) as T;
    }

    return defaultValue;
  } catch (error) {
    log.error('flag_retrieval_error', error as Error);
    return defaultValue;
  }
}

/**
 * Get all feature flags from Firestore (with caching)
 * 
 * @returns All feature flags
 */
async function getFlags(): Promise<FlagsDocument> {
  // Check cache
  if (flagCache && Date.now() - flagCache.timestamp < CACHE_TTL_MS) {
    return flagCache.flags;
  }

  // Fetch from Firestore
  const db = admin.firestore();
  const flagsDoc = await db.collection('config').doc('flags').get();

  if (!flagsDoc.exists) {
    log.warn('flags_document_not_found', {
      message: 'config/flags document does not exist, using defaults',
    });
    
    // Initialize with defaults
    const defaultFlags = getDefaultFlags();
    await db.collection('config').doc('flags').set(defaultFlags);
    
    flagCache = {
      flags: defaultFlags,
      timestamp: Date.now(),
    };
    
    return defaultFlags;
  }

  const flags = flagsDoc.data() as FlagsDocument;
  
  // Update cache
  flagCache = {
    flags,
    timestamp: Date.now(),
  };

  return flags;
}

/**
 * Get default feature flags
 * 
 * @returns Default flags configuration
 */
function getDefaultFlags(): FlagsDocument {
  return {
    'cache.localHotset': {
      enabled: false,
      type: 'boolean',
      description: 'Enable in-process LRU cache for hot data',
    },
    'bundles.enable': {
      enabled: false,
      type: 'boolean',
      description: 'Enable Firestore bundles for bulk data loading',
    },
    'tracing.sample': {
      enabled: true,
      value: 1.0,
      type: 'number',
      description: 'Trace sampling rate (0.0 to 1.0)',
    },
    'hedge.external': {
      enabled: false,
      type: 'boolean',
      description: 'Enable request hedging for external API calls',
    },
    'canary.cohortPercent': {
      enabled: true,
      value: 0,
      type: 'number',
      description: 'Percentage of users in canary cohort (0-100)',
    },
  };
}

/**
 * Initialize feature flags (creates config/flags if not exists)
 * 
 * This should be called during deployment or setup.
 */
export async function initializeFlags(): Promise<void> {
  const db = admin.firestore();
  const flagsDoc = await db.collection('config').doc('flags').get();

  if (!flagsDoc.exists) {
    const defaultFlags = getDefaultFlags();
    await db.collection('config').doc('flags').set(defaultFlags);
    log.info('flags_initialized', { flags: Object.keys(defaultFlags) });
  } else {
    log.info('flags_already_initialized');
  }
}

/**
 * Clear flag cache (useful for testing)
 */
export function clearFlagCache(): void {
  flagCache = null;
}

// ============================================================
// EXPORTS
// ============================================================

export default {
  getFlag,
  initializeFlags,
  clearFlagCache,
};
