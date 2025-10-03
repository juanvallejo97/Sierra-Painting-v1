/**
 * Ops Library - Barrel Export
 * 
 * Provides centralized access to operational utilities:
 * - Logger: Structured logging with context propagation
 * - Flags: Feature flag management with Firestore backend
 * - Tracing: OpenTelemetry distributed tracing
 * - HttpClient: Resilient HTTP client with retries
 */

// Logger
export {
  Logger,
  log,
  getOrCreateRequestId,
  type Severity,
  type LogContext,
  type LogEntry,
} from './logger';

// Feature Flags
export {
  getFlag,
  initializeFlags,
  clearFlagCache,
  type FlagConfig,
  type FlagsDocument,
} from './flags';

// Distributed Tracing
export {
  initializeTracer,
  withSpan,
  startChildSpan,
  getCurrentSpan,
  setSpanAttribute,
  recordSpanException,
} from './tracing';

// HTTP Client
export {
  httpClient,
  get,
  post,
  put,
  del,
  type HttpClientOptions,
  type HttpResponse,
} from './httpClient';
