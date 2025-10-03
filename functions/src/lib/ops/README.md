# Ops Library

The Ops Library provides operational utilities for Sierra Painting Cloud Functions, including structured logging, feature flags, distributed tracing, and resilient HTTP client.

## Features

- **Structured Logging**: JSON-formatted logs with context propagation
- **Feature Flags**: Runtime configuration backed by Firestore
- **Distributed Tracing**: OpenTelemetry integration with Cloud Trace
- **HTTP Client**: Resilient HTTP client with retries and exponential backoff

## Installation

Dependencies are already included in `package.json`. To install:

```bash
cd functions
npm install
```

## Quick Start

### Structured Logging

```typescript
import { log, getOrCreateRequestId } from './lib/ops';

export const myFunction = functions.https.onCall(async (data, context) => {
  const requestId = getOrCreateRequestId(context.rawRequest?.headers);
  const logger = log.child({ requestId, userId: context.auth?.uid });
  
  logger.info('operation_started', { entityId: data.id });
  
  try {
    // ... do work ...
    logger.info('operation_completed', { entityId: data.id });
  } catch (error) {
    logger.error('operation_failed', error as Error);
    throw error;
  }
});
```

### Feature Flags

```typescript
import { getFlag } from './lib/ops';

const cacheEnabled = await getFlag('cache.localHotset', false);
if (cacheEnabled) {
  // Use cache
}

const sampleRate = await getFlag('tracing.sample', 1.0);
```

### Distributed Tracing

```typescript
import { withSpan, startChildSpan } from './lib/ops';

export const myFunction = functions.https.onCall(async (data, context) => {
  return withSpan('myFunction', async (span) => {
    span.setAttribute('userId', context.auth?.uid);
    
    // Child span for database operation
    const dbSpan = startChildSpan('firestore_query');
    const result = await db.collection('items').doc(data.id).get();
    dbSpan.end();
    
    return result.data();
  });
});
```

### HTTP Client

```typescript
import { httpClient } from './lib/ops';

const response = await httpClient.post('https://api.stripe.com/v1/charges', {
  body: JSON.stringify({ amount: 1000 }),
  headers: { 'Content-Type': 'application/json' },
  timeout: 5000,  // 5-second timeout
  retries: 3,     // Up to 3 retries
});

const data = response.json();
```

## Initialization

### Initialize Feature Flags

Deploy the initialization function:

```bash
firebase deploy --only functions:initializeFlags
```

Then call it once (from Firebase Console or via API) to create the `config/flags` document with default values.

## Documentation

- [Feature Flags Guide](../../../docs/ops/feature-flags.md) - Complete guide on using and managing feature flags
- [Observability Guide](../../../docs/ops/observability.md) - Logging conventions, trace fields, and dashboard queries
- [Runbooks](../../../docs/ops/runbooks/README.md) - Operational procedures and troubleshooting

## Testing

Unit tests are included for all modules:

```bash
cd functions
npm test
```

## API Reference

### Logger

- `log.child(context)` - Create child logger with additional context
- `log.info(message, data)` - Log at INFO level
- `log.warn(message, data)` - Log at WARN level
- `log.error(message, error)` - Log at ERROR level
- `log.debug(message, data)` - Log at DEBUG level
- `log.perf(operation, latencyMs, data)` - Log performance metrics
- `getOrCreateRequestId(headers)` - Extract or generate request ID

### Feature Flags

- `getFlag(name, defaultValue)` - Get feature flag value (boolean, number, or string)
- `initializeFlags()` - Initialize flags document with defaults
- `clearFlagCache()` - Clear in-memory cache (useful for testing)

### Distributed Tracing

- `initializeTracer()` - Initialize OpenTelemetry tracer (called automatically)
- `withSpan(name, fn)` - Execute function within a trace span
- `startChildSpan(name)` - Start a child span (must call `.end()`)
- `getCurrentSpan()` - Get the current active span
- `setSpanAttribute(key, value)` - Set attribute on current span
- `recordSpanException(error)` - Record exception in current span

### HTTP Client

- `httpClient.get(url, options)` - Make GET request
- `httpClient.post(url, options)` - Make POST request
- `httpClient.put(url, options)` - Make PUT request
- `httpClient.delete(url, options)` - Make DELETE request

Options:
- `timeout` - Request timeout in milliseconds (default: 10000)
- `retries` - Number of retries on failure (default: 3)
- `body` - Request body
- `headers` - Request headers

## Architecture

```
functions/src/lib/ops/
├── index.ts           # Barrel export
├── logger.ts          # Structured logging
├── flags.ts           # Feature flags
├── tracing.ts         # Distributed tracing
├── httpClient.ts      # HTTP client with retries
└── __tests__/         # Unit tests
    ├── logger.test.ts
    ├── flags.test.ts
    └── httpClient.test.ts
```

## Performance Impact

- **Logging**: <1ms overhead per log entry
- **Feature Flags**: 1 Firestore read per 30 seconds (cached)
- **Tracing**: <5ms overhead per request (sampling configurable)
- **HTTP Client**: Transparent retry logic with exponential backoff

## Dependencies

- `@opentelemetry/api` - OpenTelemetry API
- `@opentelemetry/sdk-trace-node` - Node.js tracing SDK
- `@google-cloud/opentelemetry-cloud-trace-exporter` - Cloud Trace exporter
- `node-fetch` - HTTP client

## Integration Example

See `functions/src/index.ts` for integration examples in `clockIn` and `markPaymentPaid` functions.

## Support

For issues or questions:
1. Check the [documentation](../../../docs/ops/)
2. Review unit tests for usage examples
3. Open an issue in the repository

## License

MIT
