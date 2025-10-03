/**
 * Structured Logger for Sierra Painting Cloud Functions
 * 
 * PURPOSE:
 * Provides structured JSON logging with severity levels, context propagation,
 * and automatic performance metrics for Cloud Functions.
 * 
 * RESPONSIBILITIES:
 * - Emit structured JSON logs to Cloud Logging
 * - Propagate request context (requestId, userId, orgId)
 * - Track performance metrics automatically
 * - Support severity levels (debug, info, warn, error)
 * 
 * USAGE:
 * ```typescript
 * import { log } from './lib/ops';
 * 
 * const logger = log.child({ requestId: 'req_123', userId: 'user_456' });
 * logger.info('payment_marked_paid', {
 *   invoiceId: 'inv_789',
 *   amount: 15000,
 *   latencyMs: 245,
 * });
 * ```
 * 
 * PERFORMANCE NOTES:
 * - Logs are buffered by Cloud Functions runtime
 * - Structured logs are queryable in Cloud Logging
 * - Use log.perf() for automatic performance tracking
 * 
 * CONVENTIONS:
 * - Event names use snake_case (payment_created, invoice_sent)
 * - Field names use camelCase (userId, invoiceId, latencyMs)
 * - Always include entity context (userId, orgId, invoiceId)
 */

import * as functions from 'firebase-functions';

// ============================================================
// TYPES
// ============================================================

export type Severity = 'DEBUG' | 'INFO' | 'WARN' | 'ERROR';

export interface LogContext {
  requestId?: string;
  userId?: string;
  orgId?: string;
  [key: string]: unknown;
}

export interface LogEntry {
  severity: Severity;
  message: string;
  timestamp: string;
  context: LogContext;
  [key: string]: unknown;
}

// ============================================================
// LOGGER CLASS
// ============================================================

export class Logger {
  private context: LogContext;

  constructor(context: LogContext = {}) {
    this.context = context;
  }

  /**
   * Create a child logger with additional context
   * 
   * @param additionalContext - Additional context to merge
   * @returns New Logger instance with merged context
   */
  child(additionalContext: LogContext): Logger {
    return new Logger({
      ...this.context,
      ...additionalContext,
    });
  }

  /**
   * Log at DEBUG level
   * 
   * @param message - Event name or message
   * @param data - Additional structured data
   */
  debug(message: string, data?: Record<string, unknown>): void {
    this.emit('DEBUG', message, data);
  }

  /**
   * Log at INFO level
   * 
   * @param message - Event name or message
   * @param data - Additional structured data
   */
  info(message: string, data?: Record<string, unknown>): void {
    this.emit('INFO', message, data);
  }

  /**
   * Log at WARN level
   * 
   * @param message - Event name or message
   * @param data - Additional structured data
   */
  warn(message: string, data?: Record<string, unknown>): void {
    this.emit('WARN', message, data);
  }

  /**
   * Log at ERROR level
   * 
   * @param message - Event name or message
   * @param error - Error object or additional data
   */
  error(message: string, error?: Error | Record<string, unknown>): void {
    const data = error instanceof Error
      ? {
          error: error.message,
          stack: error.stack,
          name: error.name,
        }
      : error;
    
    this.emit('ERROR', message, data);
  }

  /**
   * Log performance metrics
   * 
   * @param operation - Operation name
   * @param latencyMs - Latency in milliseconds
   * @param data - Additional performance data (firestoreReads, firestoreWrites, etc.)
   */
  perf(operation: string, latencyMs: number, data?: Record<string, unknown>): void {
    this.info(`${operation}_performance`, {
      latencyMs,
      operation,
      ...data,
    });
  }

  /**
   * Emit structured log entry
   * 
   * @param severity - Log severity level
   * @param message - Event name or message
   * @param data - Additional structured data
   */
  private emit(severity: Severity, message: string, data?: Record<string, unknown>): void {
    const entry: LogEntry = {
      severity,
      message,
      timestamp: new Date().toISOString(),
      context: this.context,
      ...data,
    };

    // Use appropriate Firebase Functions logger method
    switch (severity) {
      case 'DEBUG':
        functions.logger.debug(message, entry);
        break;
      case 'INFO':
        functions.logger.info(message, entry);
        break;
      case 'WARN':
        functions.logger.warn(message, entry);
        break;
      case 'ERROR':
        functions.logger.error(message, entry);
        break;
    }
  }
}

// ============================================================
// HELPER FUNCTIONS
// ============================================================

/**
 * Extract or create request ID from HTTP request headers
 * 
 * @param headers - HTTP request headers
 * @returns Request ID (existing or newly generated)
 */
export function getOrCreateRequestId(headers?: Record<string, string | string[]> | null): string {
  if (!headers) {
    return generateRequestId();
  }

  // Check for existing request ID in common headers
  const existingId = headers['x-request-id'] || headers['X-Request-ID'];
  
  if (existingId) {
    return Array.isArray(existingId) ? existingId[0] : existingId;
  }

  return generateRequestId();
}

/**
 * Generate a unique request ID
 * 
 * @returns UUID-style request ID
 */
function generateRequestId(): string {
  return `req_${Date.now()}_${Math.random().toString(36).substring(2, 11)}`;
}

// ============================================================
// DEFAULT LOGGER INSTANCE
// ============================================================

export const log = new Logger();

// ============================================================
// EXPORTS
// ============================================================

export default {
  Logger,
  log,
  getOrCreateRequestId,
};
