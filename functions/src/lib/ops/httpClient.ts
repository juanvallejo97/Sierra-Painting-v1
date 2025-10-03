/**
 * HTTP Client with Retries and Timeout for Sierra Painting Cloud Functions
 * 
 * PURPOSE:
 * Provides a resilient HTTP client with automatic retries, timeouts,
 * exponential backoff, and distributed tracing integration.
 * 
 * RESPONSIBILITIES:
 * - Make HTTP requests with configurable timeouts
 * - Retry failed requests with exponential backoff + jitter
 * - Integrate with distributed tracing
 * - Handle transient failures gracefully
 * 
 * USAGE:
 * ```typescript
 * import { httpClient } from './lib/ops';
 * 
 * const response = await httpClient.post('https://api.stripe.com/v1/charges', {
 *   body: JSON.stringify({ amount: 1000 }),
 *   headers: { 'Content-Type': 'application/json' },
 *   timeout: 5000,  // 5-second timeout
 *   retries: 3,     // Up to 3 retries
 * });
 * ```
 * 
 * RETRY LOGIC:
 * - Retries on: 5xx, 429 (rate limit), 408 (timeout), network errors
 * - Exponential backoff: 1s, 2s, 4s (with jitter)
 * - Configurable retry count (default: 3)
 * 
 * PERFORMANCE NOTES:
 * - Default timeout: 10 seconds
 * - Automatic tracing of external calls
 * - Logs retry attempts for debugging
 */

import fetch, { RequestInit } from 'node-fetch';
import { startChildSpan } from './tracing';
import { log } from './logger';

// ============================================================
// TYPES
// ============================================================

export interface HttpClientOptions extends RequestInit {
  timeout?: number; // Timeout in milliseconds (default: 10000)
  retries?: number; // Number of retries (default: 3)
}

export interface HttpResponse {
  status: number;
  statusText: string;
  headers: Record<string, string>;
  body: string;
  json: <T = unknown>() => T;
}

// ============================================================
// HTTP CLIENT
// ============================================================

/**
 * Make an HTTP GET request
 * 
 * @param url - Request URL
 * @param options - Request options
 * @returns HTTP response
 */
export async function get(url: string, options: HttpClientOptions = {}): Promise<HttpResponse> {
  return request(url, { ...options, method: 'GET' });
}

/**
 * Make an HTTP POST request
 * 
 * @param url - Request URL
 * @param options - Request options
 * @returns HTTP response
 */
export async function post(url: string, options: HttpClientOptions = {}): Promise<HttpResponse> {
  return request(url, { ...options, method: 'POST' });
}

/**
 * Make an HTTP PUT request
 * 
 * @param url - Request URL
 * @param options - Request options
 * @returns HTTP response
 */
export async function put(url: string, options: HttpClientOptions = {}): Promise<HttpResponse> {
  return request(url, { ...options, method: 'PUT' });
}

/**
 * Make an HTTP DELETE request
 * 
 * @param url - Request URL
 * @param options - Request options
 * @returns HTTP response
 */
export async function del(url: string, options: HttpClientOptions = {}): Promise<HttpResponse> {
  return request(url, { ...options, method: 'DELETE' });
}

/**
 * Make an HTTP request with retries and timeout
 * 
 * @param url - Request URL
 * @param options - Request options
 * @returns HTTP response
 */
async function request(url: string, options: HttpClientOptions = {}): Promise<HttpResponse> {
  const {
    timeout = 10000,
    retries = 3,
    ...fetchOptions
  } = options;

  const span = startChildSpan(`http_${options.method?.toLowerCase() || 'get'}`);
  span.setAttribute('http.url', url);
  span.setAttribute('http.method', options.method || 'GET');

  let lastError: Error | null = null;
  let attempt = 0;

  while (attempt <= retries) {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), timeout);

      const response = await fetch(url, {
        ...fetchOptions,
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      span.setAttribute('http.status_code', response.status);

      // Check if we should retry
      if (shouldRetry(response.status) && attempt < retries) {
        log.warn('http_request_retry', {
          url,
          status: response.status,
          attempt: attempt + 1,
          maxRetries: retries,
        });

        await sleep(getBackoffDelay(attempt));
        attempt++;
        continue;
      }

      // Convert response to our format
      const body = await response.text();
      const httpResponse: HttpResponse = {
        status: response.status,
        statusText: response.statusText,
        headers: Object.fromEntries(response.headers.entries()),
        body,
        json: <T = unknown>() => JSON.parse(body) as T,
      };

      span.end();
      return httpResponse;
    } catch (error) {
      lastError = error as Error;

      // Check if error is retryable
      if (isRetryableError(error as Error) && attempt < retries) {
        log.warn('http_request_error_retry', {
          url,
          error: (error as Error).message,
          attempt: attempt + 1,
          maxRetries: retries,
        });

        await sleep(getBackoffDelay(attempt));
        attempt++;
        continue;
      }

      // Not retryable or out of retries
      span.recordException(error as Error);
      span.end();
      throw error;
    }
  }

  // Should never reach here, but TypeScript needs it
  span.end();
  throw lastError || new Error('Request failed after retries');
}

/**
 * Check if HTTP status code should trigger a retry
 * 
 * @param status - HTTP status code
 * @returns True if should retry
 */
function shouldRetry(status: number): boolean {
  // Retry on:
  // - 5xx (server errors)
  // - 429 (rate limit)
  // - 408 (request timeout)
  return status >= 500 || status === 429 || status === 408;
}

/**
 * Check if error is retryable
 * 
 * @param error - Error object
 * @returns True if should retry
 */
function isRetryableError(error: Error): boolean {
  // Retry on network errors, timeouts, etc.
  const retryableErrors = [
    'ECONNRESET',
    'ENOTFOUND',
    'ESOCKETTIMEDOUT',
    'ETIMEDOUT',
    'ECONNREFUSED',
    'EHOSTUNREACH',
    'EPIPE',
    'EAI_AGAIN',
  ];

  return retryableErrors.some(code => error.message.includes(code)) ||
         error.name === 'AbortError';
}

/**
 * Calculate backoff delay with jitter
 * 
 * @param attempt - Retry attempt number (0-indexed)
 * @returns Delay in milliseconds
 */
function getBackoffDelay(attempt: number): number {
  // Exponential backoff: 1s, 2s, 4s, 8s
  const baseDelay = Math.pow(2, attempt) * 1000;
  
  // Add jitter (±25%)
  const jitter = baseDelay * 0.25 * (Math.random() * 2 - 1);
  
  return Math.floor(baseDelay + jitter);
}

/**
 * Sleep for a given duration
 * 
 * @param ms - Duration in milliseconds
 * @returns Promise that resolves after delay
 */
function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// ============================================================
// EXPORTS
// ============================================================

export const httpClient = {
  get,
  post,
  put,
  delete: del,
  request,
};

export default httpClient;
