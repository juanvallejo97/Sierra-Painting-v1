# Telemetry & Logging Guide

This guide documents structured logging, analytics, and performance monitoring in the Sierra Painting app.

## Table of Contents

1. [Structured Logging](#structured-logging)
2. [Performance Monitoring](#performance-monitoring)
3. [Error Tracking](#error-tracking)
4. [Analytics Events](#analytics-events)
5. [Request ID Propagation](#request-id-propagation)

---

## Structured Logging

### TelemetryService

Location: `lib/core/telemetry/telemetry_service.dart`

The `TelemetryService` provides centralized logging with standard fields:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/telemetry/telemetry_service.dart';

// In your widget or service
final telemetry = ref.read(telemetryServiceProvider);

telemetry.logEvent('CLOCK_IN', {
  'entity': 'timeEntry',
  'jobId': jobId,
  'userId': userId,
  'timestamp': DateTime.now().toIso8601String(),
});
```

### Standard Log Fields

Every log event should include:

- **entity**: The type of entity (e.g., 'timeEntry', 'invoice', 'estimate')
- **action**: The action performed (e.g., 'CREATED', 'UPDATED', 'DELETED')
- **actorUid**: User ID of the person performing the action
- **orgId**: Organization ID (for multi-tenant apps)
- **requestId**: Unique ID for correlation (automatically added)
- **timestamp**: ISO 8601 timestamp (automatically added)

### Example Log Events

#### Clock In
```dart
telemetry.logEvent('CLOCK_IN', {
  'entity': 'timeEntry',
  'action': 'CREATED',
  'actorUid': userId,
  'jobId': jobId,
  'location': {'lat': lat, 'lng': lng},
  'method': 'manual', // or 'nfc', 'qr'
});
```

#### Invoice Created
```dart
telemetry.logEvent('INVOICE_CREATED', {
  'entity': 'invoice',
  'action': 'CREATED',
  'actorUid': userId,
  'invoiceId': invoiceId,
  'customerId': customerId,
  'amount': totalAmount,
  'lineItemCount': items.length,
});
```

#### Sync Operation
```dart
telemetry.logEvent('SYNC_COMPLETED', {
  'entity': 'syncQueue',
  'action': 'SYNCED',
  'itemsSynced': syncedCount,
  'syncDuration': duration.inMilliseconds,
  'failedItems': failedCount,
  'queueSize': remainingCount,
});
```

---

## Performance Monitoring

### PerformanceMonitor

Location: `lib/core/telemetry/performance_monitor.dart`

Track performance metrics for critical operations:

```dart
import 'package:sierra_painting/core/telemetry/performance_monitor.dart';

// Start a trace
final stopTrace = telemetry.startTrace('load_invoices');

try {
  // Perform operation
  final invoices = await api.getInvoices();
  
  // Record success
  telemetry.recordMetric('invoices_loaded', invoices.length);
} finally {
  // Stop trace
  stopTrace();
}
```

### Performance Targets

From `docs/perf-playbook-fe.md`:

| Metric | P50 Target | P95 Target |
|--------|-----------|-----------|
| Frame rate | 60fps | 60fps |
| Frame build time | < 8ms | < 16ms |
| Screen render | < 300ms | < 500ms |
| Network action | < 100ms | < 200ms |
| App startup (cold) | < 2s | < 3s |

### Custom Metrics

```dart
// Record frame times
telemetry.recordMetric('frame_build_time_ms', buildTimeMs);

// Record screen load time
final stopwatch = Stopwatch()..start();
await loadScreen();
stopwatch.stop();
telemetry.recordMetric('screen_load_time_ms', stopwatch.elapsedMilliseconds);

// Record network request time
final start = DateTime.now();
await apiCall();
final duration = DateTime.now().difference(start);
telemetry.recordMetric('api_call_duration_ms', duration.inMilliseconds);
```

---

## Error Tracking

### Logging Errors

```dart
try {
  await riskyOperation();
} catch (error, stackTrace) {
  telemetry.logError(
    error,
    stackTrace: stackTrace,
    context: {
      'operation': 'clock_in',
      'userId': userId,
      'jobId': jobId,
    },
  );
  
  // Show user-friendly error
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Failed to clock in. Please try again.')),
  );
}
```

### Error Context

Always include context to help debug:

- What was the user trying to do?
- What was the app state?
- What were the input parameters?
- Was the device online?

```dart
telemetry.logError(
  error,
  stackTrace: stackTrace,
  context: {
    'screen': 'timeclock',
    'action': 'clock_in',
    'userId': userId,
    'isOnline': await connectivity.checkConnectivity(),
    'queueSize': queueService.pendingCount,
    'timestamp': DateTime.now().toIso8601String(),
  },
);
```

---

## Analytics Events

### User Actions

Track key user actions for product analytics:

```dart
// Screen view
telemetry.trackScreenView('invoices', screenClass: 'InvoicesScreen');

// Feature usage
telemetry.logEvent('FEATURE_USED', {
  'feature': 'export_pdf',
  'screen': 'invoices',
  'userId': userId,
});

// User engagement
telemetry.logEvent('SESSION_DURATION', {
  'durationMinutes': sessionDuration.inMinutes,
  'screensVisited': screensVisited.length,
  'actionsPerformed': actionCount,
});
```

### Conversion Events

Track business-critical conversions:

```dart
// Invoice sent
telemetry.logEvent('INVOICE_SENT', {
  'invoiceId': invoiceId,
  'amount': amount,
  'method': 'email', // or 'sms', 'printed'
  'customerId': customerId,
});

// Payment received
telemetry.logEvent('PAYMENT_RECEIVED', {
  'invoiceId': invoiceId,
  'amount': amount,
  'method': 'stripe', // or 'cash', 'check'
  'paidAt': DateTime.now().toIso8601String(),
});
```

---

## Request ID Propagation

### Purpose

Request IDs allow you to trace a single user action through:
- Client logs
- Network requests
- Server-side functions
- Database operations

### How It Works

```dart
// ApiClient automatically generates and propagates requestId
final client = ApiClient();
final result = await client.callFunction(
  'clockIn',
  data: {'userId': userId, 'jobId': jobId},
);

// requestId is included in:
// 1. Client logs
// 2. HTTP headers (X-Request-ID)
// 3. Server logs
// 4. Error reports
```

### Viewing Correlation

#### Client Side
```dart
// TelemetryService automatically includes requestId
telemetry.logEvent('CLOCK_IN_STARTED', {
  'userId': userId,
  // requestId added automatically
});
```

#### Server Side
```typescript
// functions/src/lib/ops/logger.ts
import { log } from './ops';

export const clockIn = onCall(async (request) => {
  const requestId = getOrCreateRequestId(request);
  
  log.info('Clock in started', {
    requestId,
    userId: request.auth?.uid,
    data: request.data,
  });
  
  // ... perform operation
});
```

#### Finding Logs

In Cloud Logging, filter by requestId:
```
jsonPayload.requestId="req_abc123xyz"
```

This will show:
- Client-side event log
- API call log
- Server function execution log
- Database operation log
- Any errors encountered

---

## Best Practices

### 1. Log Liberally, Filter Later

```dart
// Good: Log important state changes
telemetry.logEvent('SYNC_STARTED', {
  'queueSize': queueSize,
  'isOnline': isOnline,
});

await performSync();

telemetry.logEvent('SYNC_COMPLETED', {
  'itemsSynced': syncedCount,
  'duration': duration.inMilliseconds,
});
```

### 2. Use Consistent Event Names

Use SCREAMING_SNAKE_CASE for event names:
- `CLOCK_IN`
- `INVOICE_CREATED`
- `PAYMENT_RECEIVED`
- `SYNC_FAILED`

### 3. Include Context

```dart
// Bad: Not enough context
telemetry.logEvent('ERROR', {'message': 'Failed'});

// Good: Full context
telemetry.logError(
  error,
  context: {
    'operation': 'create_invoice',
    'userId': userId,
    'customerId': customerId,
    'amount': amount,
    'isOnline': isOnline,
  },
);
```

### 4. Don't Log PII

```dart
// Bad: Logging sensitive data
telemetry.logEvent('USER_CREATED', {
  'email': email, // PII!
  'phone': phone, // PII!
  'ssn': ssn, // Definitely PII!
});

// Good: Hash or omit PII
telemetry.logEvent('USER_CREATED', {
  'userIdHash': sha256(userId),
  'accountType': accountType,
});
```

### 5. Measure Performance

```dart
// Track slow operations
if (duration.inMilliseconds > 1000) {
  telemetry.logEvent('SLOW_OPERATION', {
    'operation': 'load_invoices',
    'duration': duration.inMilliseconds,
    'itemCount': invoices.length,
  });
}
```

---

## Monitoring Dashboard

### Key Metrics to Track

1. **Error Rate**: Errors per 1000 requests
2. **Sync Success Rate**: Successful syncs / total sync attempts
3. **Performance P95**: 95th percentile latency
4. **Crash-Free Rate**: % of sessions without crashes
5. **Queue Size**: Average pending operations

### Alerts

Set up alerts for:
- Error rate > 1%
- Sync success rate < 95%
- P95 latency > 500ms
- Crash rate > 0.1%
- Queue size > 50 items

---

## Example: Complete Flow

```dart
class TimeclockService {
  final TelemetryService _telemetry;
  final ApiClient _api;
  final QueueService _queue;
  
  Future<void> clockIn(String userId, String jobId) async {
    final requestId = uuid.v4();
    _telemetry.setRequestId(requestId);
    
    // Start performance trace
    final stopTrace = _telemetry.startTrace('clock_in');
    
    try {
      // Log start
      _telemetry.logEvent('CLOCK_IN_STARTED', {
        'entity': 'timeEntry',
        'userId': userId,
        'jobId': jobId,
      });
      
      // Perform operation
      final result = await _api.callFunction(
        'clockIn',
        data: {'userId': userId, 'jobId': jobId},
        requestId: requestId,
      );
      
      // Log success
      _telemetry.logEvent('CLOCK_IN_COMPLETED', {
        'entity': 'timeEntry',
        'userId': userId,
        'jobId': jobId,
        'timeEntryId': result['id'],
      });
      
      // Record metric
      _telemetry.recordMetric('clock_in_success', 1);
      
    } catch (error, stackTrace) {
      // Log error with full context
      _telemetry.logError(
        error,
        stackTrace: stackTrace,
        context: {
          'operation': 'clock_in',
          'userId': userId,
          'jobId': jobId,
          'requestId': requestId,
        },
      );
      
      // Record failure metric
      _telemetry.recordMetric('clock_in_failure', 1);
      
      rethrow;
    } finally {
      // Stop trace
      stopTrace();
    }
  }
}
```

---

## Tools & Resources

### Firebase Tools
- **Firebase Console**: View analytics and crashlytics
- **Cloud Logging**: Query structured logs
- **Performance Monitoring**: Track performance metrics

### Local Development
- **Flutter DevTools**: Timeline, memory, network inspector
- **Debug Logging**: Use `debugPrint()` for verbose logs

### Testing
- **Mock Telemetry**: Use mock service for unit tests
- **Verify Logs**: Check logs in integration tests

---

**Last Updated**: 2025-10-03  
**See Also**:
- `lib/core/telemetry/telemetry_service.dart`
- `lib/core/telemetry/performance_monitor.dart`
- `lib/core/telemetry/error_tracker.dart`
- `lib/core/network/api_client.dart`
