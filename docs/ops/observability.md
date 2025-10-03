# Observability Guide

## Overview

This guide describes logging conventions, distributed tracing, and how to use Cloud Logging and Cloud Trace for Sierra Painting Cloud Functions.

## Structured Logging

### Log Format

All logs use structured JSON format for easy searching and filtering in Cloud Logging:

```typescript
{
  severity: 'INFO',
  message: 'payment_marked_paid',
  timestamp: '2024-01-15T10:30:00.000Z',
  context: {
    requestId: 'req_123',
    userId: 'user_456',
    orgId: 'org_789'
  },
  invoiceId: 'inv_abc',
  amount: 15000,
  latencyMs: 245,
  firestoreWrites: 3
}
```

### Using the Logger

```typescript
import { log, getOrCreateRequestId } from './lib/ops';

// Create child logger with request context
const requestId = getOrCreateRequestId(context.rawRequest?.headers);
const logger = log.child({ 
  requestId, 
  userId: context.auth?.uid,
  orgId: userData.orgId 
});

// Log events
logger.info('payment_initiated', { 
  invoiceId: 'inv_123', 
  amount: 15000 
});

// Log errors
logger.error('payment_failed', error);

// Log performance
const startTime = Date.now();
// ... do work ...
const latencyMs = Date.now() - startTime;
logger.perf('processPayment', latencyMs, {
  firestoreReads: 5,
  firestoreWrites: 2,
  externalApiCalls: 1
});
```

### Log Severity Levels

- **DEBUG**: Detailed debugging information (development only)
- **INFO**: Normal operational events (successful operations)
- **WARN**: Warning conditions (retries, degraded performance)
- **ERROR**: Error conditions (failed operations, exceptions)

### Field Naming Conventions

- Use camelCase: `userId`, `invoiceId`, `latencyMs`
- Include entity IDs: `invoiceId`, `paymentId`, `jobId`
- Include actor: `userId`, `actorUid`
- Include organization: `orgId`
- Include request tracing: `requestId`
- Include performance metrics: `latencyMs`, `firestoreReads`, `firestoreWrites`

### Standard Fields

Every log entry should include:

```typescript
{
  requestId: string,    // Unique request identifier
  userId?: string,      // Actor user ID
  orgId?: string,       // Organization ID
}
```

Performance logs should include:

```typescript
{
  latencyMs: number,           // Operation latency
  firestoreReads?: number,     // Firestore read operations
  firestoreWrites?: number,    // Firestore write operations
  externalApiCalls?: number,   // External API calls
}
```

## Distributed Tracing

### Using Traces

```typescript
import { withSpan, startChildSpan } from './lib/ops';

export const myFunction = functions.https.onCall(async (data, context) => {
  return withSpan('myFunction', async (span) => {
    // Add attributes to span
    span.setAttribute('userId', context.auth?.uid);
    span.setAttribute('invoiceId', data.invoiceId);
    
    // Create child span for database operation
    const dbSpan = startChildSpan('firestore_query');
    const invoice = await db.collection('invoices').doc(data.invoiceId).get();
    dbSpan.end();
    
    // Create child span for external API call
    const apiSpan = startChildSpan('stripe_api_call');
    const charge = await stripe.charges.create({ ... });
    apiSpan.end();
    
    return result;
  });
});
```

### Span Naming Conventions

- Use snake_case: `firestore_query`, `stripe_api_call`
- Be specific: `firestore_invoice_read`, not just `db_read`
- Group by operation type:
  - Database: `firestore_*`, `firestore_invoice_read`
  - External API: `stripe_*`, `sendgrid_*`
  - Internal logic: `calculate_total`, `validate_payment`

### Trace Attributes

Add searchable attributes to spans:

```typescript
span.setAttribute('userId', userId);
span.setAttribute('invoiceId', invoiceId);
span.setAttribute('amount', amount);
span.setAttribute('paymentMethod', method);
```

### Sampling

Tracing is controlled by the `tracing.sample` feature flag:

- `1.0`: Trace all requests (100%)
- `0.1`: Trace 10% of requests
- `0.0`: Disable tracing

Update via feature flags in Firestore.

## Cloud Logging Queries

### Find All Logs for a Request

```
resource.type="cloud_function"
jsonPayload.context.requestId="req_123"
```

### Find All Errors

```
resource.type="cloud_function"
severity="ERROR"
timestamp>="2024-01-15T00:00:00Z"
```

### Find Performance Issues

```
resource.type="cloud_function"
jsonPayload.latencyMs>1000
timestamp>="2024-01-15T00:00:00Z"
```

### Find Specific Event

```
resource.type="cloud_function"
jsonPayload.message="payment_marked_paid"
timestamp>="2024-01-15T00:00:00Z"
```

### Find Operations by User

```
resource.type="cloud_function"
jsonPayload.context.userId="user_456"
timestamp>="2024-01-15T00:00:00Z"
```

### Find High Latency Operations

```
resource.type="cloud_function"
jsonPayload.latencyMs>2000
severity="INFO"
```

## Cloud Trace Queries

### View Traces in Console

1. Go to: https://console.cloud.google.com/traces
2. Select time range
3. Filter by: `sierra-painting-functions`

### Find Slow Traces

1. Sort by latency (descending)
2. Look for traces >1s
3. Examine span breakdown

### Find Error Traces

1. Filter by status: `Error`
2. Examine error details in spans
3. Correlate with logs using requestId

## Dashboard Setup

### Key Metrics to Monitor

1. **Error Rate**: Percentage of requests with errors
   ```
   count(severity="ERROR") / count(severity="INFO" OR severity="ERROR")
   ```

2. **P95 Latency**: 95th percentile latency
   ```
   percentile(jsonPayload.latencyMs, 95)
   ```

3. **P99 Latency**: 99th percentile latency
   ```
   percentile(jsonPayload.latencyMs, 99)
   ```

4. **Request Rate**: Requests per minute
   ```
   count(jsonPayload.message) / 60
   ```

5. **Firestore Operations**: Reads + Writes per request
   ```
   avg(jsonPayload.firestoreReads + jsonPayload.firestoreWrites)
   ```

### Suggested Alerts

1. **High Error Rate**: >5% errors in 5 minutes
2. **High Latency**: P95 latency >2s for 5 minutes
3. **Function Timeout**: Any function timeout errors
4. **Auth Errors**: >10 auth errors in 5 minutes

## Log Analysis Examples

### Analyze Performance by Operation

```
resource.type="cloud_function"
jsonPayload.operation=~".*"
| stats avg(jsonPayload.latencyMs) by jsonPayload.operation
```

### Identify Slow Firestore Queries

```
resource.type="cloud_function"
jsonPayload.firestoreReads>10
| stats count(), avg(jsonPayload.latencyMs) by jsonPayload.message
```

### Track Feature Flag Usage

```
resource.type="cloud_function"
jsonPayload.message="flag_checked"
| stats count() by jsonPayload.flagName, jsonPayload.flagValue
```

## Best Practices

### Logging

1. **Always include context**: requestId, userId, orgId
2. **Use event names**: payment_created, invoice_sent (not "Creating payment")
3. **Log performance metrics**: Track latency and resource usage
4. **Don't log PII**: No email, phone, credit card numbers
5. **Be consistent**: Use standard field names across functions

### Tracing

1. **Create spans for operations >100ms**: Database queries, API calls
2. **Add meaningful attributes**: userId, invoiceId, amount
3. **End spans promptly**: Use try/finally or withSpan helper
4. **Sample appropriately**: 100% in dev, 10-20% in production

### Monitoring

1. **Set up dashboards**: Monitor key metrics continuously
2. **Configure alerts**: Get notified of critical issues
3. **Review logs regularly**: Look for patterns and anomalies
4. **Correlate logs and traces**: Use requestId to connect them

## Troubleshooting

### Logs Not Appearing

- Check function is deployed
- Verify log level (DEBUG logs may be filtered)
- Check Cloud Logging filters

### Traces Not Appearing

- Verify `tracing.sample` flag is >0
- Check OpenTelemetry is initialized
- Wait a few minutes for trace export

### High Latency

1. Check span breakdown in traces
2. Identify slow operations
3. Look for N+1 queries
4. Check external API response times

## See Also

- [Feature Flags Guide](./feature-flags.md) - Runtime configuration
- [Runbooks](./runbooks/README.md) - Domain-specific operational guides
