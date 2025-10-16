/**
 * Performance Monitoring Middleware
 *
 * PURPOSE:
 * Wrap Cloud Functions with performance monitoring, custom traces, and SLO tracking.
 * Provides automatic latency measurement, error tracking, and custom attributes.
 *
 * FEATURES:
 * - Automatic latency measurement for all functions
 * - Custom traces with OpenTelemetry
 * - SLO breach detection (p95 latency targets)
 * - Error rate tracking
 * - Custom attributes (companyId, userId, operation type)
 * - Cloud Logging integration
 *
 * USAGE:
 * export const myFunction = onCall(
 *   withPerformanceMonitoring(
 *     'myFunction',
 *     async (req) => { ... },
 *     { sloTarget: 2000 } // p95 latency target in ms
 *   )
 * );
 */

import * as functions from 'firebase-functions';
import { CallableRequest } from 'firebase-functions/v2/https';
import { trace } from '@opentelemetry/api';

/**
 * Performance monitoring options
 */
export interface PerformanceOptions {
  sloTarget?: number; // p95 latency target in milliseconds
  slowThreshold?: number; // Log warning if latency exceeds this (default: 75% of SLO)
  traceAttributes?: Record<string, string | number>; // Custom attributes
  enableDetailedLogging?: boolean; // Log every invocation (default: false)
}

/**
 * Performance metrics for a function invocation
 */
export interface PerformanceMetrics {
  functionName: string;
  startTime: number;
  endTime: number;
  durationMs: number;
  success: boolean;
  error?: string;
  userId?: string;
  companyId?: string;
  attributes?: Record<string, string | number>;
}

/**
 * Global metrics store (in-memory, for p95 calculation)
 */
const metricsStore: Map<string, number[]> = new Map();
const MAX_SAMPLES = 1000; // Keep last 1000 samples per function

/**
 * Add latency sample to metrics store
 */
function addLatencySample(functionName: string, durationMs: number): void {
  if (!metricsStore.has(functionName)) {
    metricsStore.set(functionName, []);
  }

  const samples = metricsStore.get(functionName)!;
  samples.push(durationMs);

  // Keep only last MAX_SAMPLES
  if (samples.length > MAX_SAMPLES) {
    samples.shift();
  }
}

/**
 * Calculate p95 latency for a function
 */
export function getP95Latency(functionName: string): number | null {
  const samples = metricsStore.get(functionName);
  if (!samples || samples.length === 0) {
    return null;
  }

  const sorted = [...samples].sort((a, b) => a - b);
  const p95Index = Math.floor(sorted.length * 0.95);
  return sorted[p95Index];
}

/**
 * Get current metrics for a function
 */
export function getFunctionMetrics(functionName: string): {
  sampleCount: number;
  p50: number | null;
  p95: number | null;
  p99: number | null;
  avg: number | null;
} {
  const samples = metricsStore.get(functionName);
  if (!samples || samples.length === 0) {
    return { sampleCount: 0, p50: null, p95: null, p99: null, avg: null };
  }

  const sorted = [...samples].sort((a, b) => a - b);
  const p50Index = Math.floor(sorted.length * 0.5);
  const p95Index = Math.floor(sorted.length * 0.95);
  const p99Index = Math.floor(sorted.length * 0.99);
  const avg = sorted.reduce((sum, val) => sum + val, 0) / sorted.length;

  return {
    sampleCount: sorted.length,
    p50: sorted[p50Index],
    p95: sorted[p95Index],
    p99: sorted[p99Index],
    avg: Math.round(avg),
  };
}

/**
 * Wrap callable Cloud Function with performance monitoring
 */
export function withPerformanceMonitoring<R = any>(
  functionName: string,
  handler: (req: CallableRequest) => Promise<R> | R,
  options: PerformanceOptions = {}
): (req: CallableRequest) => Promise<R> {
  const { sloTarget, slowThreshold, traceAttributes = {}, enableDetailedLogging = false } = options;

  const effectiveSlowThreshold = slowThreshold || (sloTarget ? sloTarget * 0.75 : 1000);

  return async (req: CallableRequest): Promise<R> => {
    const startTime = Date.now();
    const tracer = trace.getTracer(functionName);
    const span = tracer.startSpan(`function.${functionName}`);

    // Extract user context
    const userId = req.auth?.uid;
    const companyId = (req.auth?.token as any)?.company_id;

    // Set span attributes
    span.setAttribute('function.name', functionName);
    span.setAttribute('function.type', 'callable');
    if (userId) span.setAttribute('user.id', userId);
    if (companyId) span.setAttribute('company.id', companyId);

    // Add custom attributes
    Object.entries(traceAttributes).forEach(([key, value]) => {
      span.setAttribute(key, value);
    });

    let success = true;
    let error: string | undefined;

    try {
      // Execute handler
      const result = await handler(req);

      // Mark success
      span.setStatus({ code: 1 }); // OK

      return result;
    } catch (err: any) {
      success = false;
      error = err.message || 'Unknown error';

      // Mark error
      span.setStatus({ code: 2, message: error }); // ERROR
      span.recordException(err);

      // Log error
      functions.logger.error(`Function ${functionName} failed`, {
        error: error,
        userId,
        companyId,
        durationMs: Date.now() - startTime,
      });

      throw err;
    } finally {
      const endTime = Date.now();
      const durationMs = endTime - startTime;

      // Add duration to span
      span.setAttribute('function.duration_ms', durationMs);
      span.end();

      // Add to metrics store
      addLatencySample(functionName, durationMs);

      // Check SLO breach
      if (sloTarget && durationMs > sloTarget) {
        functions.logger.warn(`SLO breach: ${functionName} took ${durationMs}ms (target: ${sloTarget}ms)`, {
          functionName,
          durationMs,
          sloTarget,
          userId,
          companyId,
          breach: true,
        });
      } else if (durationMs > effectiveSlowThreshold) {
        // Log slow execution (but not SLO breach)
        functions.logger.info(`Slow execution: ${functionName} took ${durationMs}ms (threshold: ${effectiveSlowThreshold}ms)`, {
          functionName,
          durationMs,
          slowThreshold: effectiveSlowThreshold,
          userId,
          companyId,
        });
      }

      // Log every invocation if enabled
      if (enableDetailedLogging) {
        functions.logger.info(`Function ${functionName} completed`, {
          functionName,
          durationMs,
          success,
          error,
          userId,
          companyId,
        });
      }

      // Emit metrics
      const metrics: PerformanceMetrics = {
        functionName,
        startTime,
        endTime,
        durationMs,
        success,
        error,
        userId,
        companyId,
        attributes: traceAttributes,
      };

      // Log metrics in structured format (for Cloud Logging)
      functions.logger.info('performance_metric', metrics);
    }
  };
}

/**
 * Create a custom trace for a code block
 *
 * Usage:
 * await withTrace('fetch_company_data', async () => {
 *   return await db.collection('companies').doc(companyId).get();
 * });
 */
export async function withTrace<T>(
  traceName: string,
  fn: () => Promise<T>,
  attributes?: Record<string, string | number>
): Promise<T> {
  const tracer = trace.getTracer('custom_trace');
  const span = tracer.startSpan(traceName);

  // Set attributes
  if (attributes) {
    Object.entries(attributes).forEach(([key, value]) => {
      span.setAttribute(key, value);
    });
  }

  const startTime = Date.now();

  try {
    const result = await fn();
    span.setStatus({ code: 1 }); // OK
    return result;
  } catch (error: any) {
    span.setStatus({ code: 2, message: error.message }); // ERROR
    span.recordException(error);
    throw error;
  } finally {
    const durationMs = Date.now() - startTime;
    span.setAttribute('duration_ms', durationMs);
    span.end();

    functions.logger.debug(`Trace ${traceName} completed in ${durationMs}ms`, {
      traceName,
      durationMs,
      attributes,
    });
  }
}

/**
 * Measure execution time of a synchronous function
 */
export function measureTime<T>(fn: () => T): { result: T; durationMs: number } {
  const startTime = Date.now();
  const result = fn();
  const durationMs = Date.now() - startTime;
  return { result, durationMs };
}

/**
 * Measure execution time of an async function
 */
export async function measureTimeAsync<T>(fn: () => Promise<T>): Promise<{ result: T; durationMs: number }> {
  const startTime = Date.now();
  const result = await fn();
  const durationMs = Date.now() - startTime;
  return { result, durationMs };
}
