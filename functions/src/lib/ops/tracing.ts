/**
 * Distributed Tracing for Sierra Painting Cloud Functions
 * 
 * PURPOSE:
 * Provides OpenTelemetry-based distributed tracing for Cloud Functions.
 * Enables end-to-end request tracing and latency breakdown.
 * 
 * RESPONSIBILITIES:
 * - Initialize OpenTelemetry tracer with Cloud Trace exporter
 * - Create and manage trace spans for operations
 * - Support nested spans for hierarchical tracing
 * - Export traces to Google Cloud Trace
 * 
 * USAGE:
 * ```typescript
 * import { withSpan, startChildSpan } from './lib/ops';
 * 
 * export const myFunction = functions.https.onCall(async (data, context) => {
 *   return withSpan('myFunction', async (span) => {
 *     span.setAttribute('userId', context.auth?.uid);
 *     
 *     // Child span for database operation
 *     const dbSpan = startChildSpan('firestore_query');
 *     // ... query ...
 *     dbSpan.end();
 *     
 *     return result;
 *   });
 * });
 * ```
 * 
 * PERFORMANCE NOTES:
 * - Minimal overhead (<5ms per request)
 * - Sampling controlled via feature flag (tracing.sample)
 * - Traces exported asynchronously to Cloud Trace
 * 
 * CONVENTIONS:
 * - Span names use snake_case (firestore_query, stripe_api_call)
 * - Set attributes for searchable context (userId, invoiceId, etc.)
 */

import { trace, Span, SpanStatusCode, context } from '@opentelemetry/api';
import { NodeTracerProvider } from '@opentelemetry/sdk-trace-node';
import { BatchSpanProcessor } from '@opentelemetry/sdk-trace-base';
import { TraceExporter } from '@google-cloud/opentelemetry-cloud-trace-exporter';
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';
import { getFlag } from './flags';
import { log } from './logger';

// ============================================================
// TRACER INITIALIZATION
// ============================================================

let tracerInitialized = false;
const TRACER_NAME = 'sierra-painting-functions';

/**
 * Initialize OpenTelemetry tracer
 * 
 * Should be called once during function cold start.
 */
export function initializeTracer(): void {
  if (tracerInitialized) {
    return;
  }

  try {
    const provider = new NodeTracerProvider({
      resource: new Resource({
        [SemanticResourceAttributes.SERVICE_NAME]: TRACER_NAME,
        [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
      }),
    });

    // Use Cloud Trace exporter
    const exporter = new TraceExporter();
    provider.addSpanProcessor(new BatchSpanProcessor(exporter));

    // Register the provider
    provider.register();

    tracerInitialized = true;
    log.info('tracer_initialized', { serviceName: TRACER_NAME });
  } catch (error) {
    log.error('tracer_initialization_failed', error as Error);
  }
}

/**
 * Get the tracer instance
 * 
 * @returns Tracer instance
 */
function getTracer() {
  if (!tracerInitialized) {
    initializeTracer();
  }
  return trace.getTracer(TRACER_NAME);
}

// ============================================================
// SPAN HELPERS
// ============================================================

/**
 * Execute a function within a trace span
 * 
 * @param name - Span name
 * @param fn - Function to execute within the span
 * @returns Result of the function
 */
export async function withSpan<T>(
  name: string,
  fn: (span: Span) => Promise<T>
): Promise<T> {
  // Check if tracing is enabled via feature flag
  const sampleRate = await getFlag('tracing.sample', 1.0);
  
  if (sampleRate === 0 || Math.random() > sampleRate) {
    // Skip tracing based on sampling rate
    const noopSpan = trace.getSpan(context.active());
    if (noopSpan) {
      return fn(noopSpan);
    }
    // Create a minimal noop span
    return fn({
      end: () => {},
      setAttribute: () => {},
      setAttributes: () => {},
      setStatus: () => {},
      recordException: () => {},
      updateName: () => {},
    } as unknown as Span);
  }

  const tracer = getTracer();
  const span = tracer.startSpan(name);

  try {
    const result = await context.with(trace.setSpan(context.active(), span), () => fn(span));
    span.setStatus({ code: SpanStatusCode.OK });
    return result;
  } catch (error) {
    span.recordException(error as Error);
    span.setStatus({
      code: SpanStatusCode.ERROR,
      message: error instanceof Error ? error.message : 'Unknown error',
    });
    throw error;
  } finally {
    span.end();
  }
}

/**
 * Start a child span within the current trace context
 * 
 * Must be called within a withSpan context.
 * Remember to call span.end() when the operation completes.
 * 
 * @param name - Span name
 * @returns Span instance
 */
export function startChildSpan(name: string): Span {
  const tracer = getTracer();
  return tracer.startSpan(name);
}

/**
 * Get the current active span
 * 
 * @returns Current span or undefined
 */
export function getCurrentSpan(): Span | undefined {
  return trace.getSpan(context.active());
}

/**
 * Set an attribute on the current span
 * 
 * @param key - Attribute key
 * @param value - Attribute value
 */
export function setSpanAttribute(key: string, value: string | number | boolean): void {
  const span = getCurrentSpan();
  if (span) {
    span.setAttribute(key, value);
  }
}

/**
 * Record an exception in the current span
 * 
 * @param error - Error to record
 */
export function recordSpanException(error: Error): void {
  const span = getCurrentSpan();
  if (span) {
    span.recordException(error);
    span.setStatus({
      code: SpanStatusCode.ERROR,
      message: error.message,
    });
  }
}

// ============================================================
// EXPORTS
// ============================================================

export default {
  initializeTracer,
  withSpan,
  startChildSpan,
  getCurrentSpan,
  setSpanAttribute,
  recordSpanException,
};
