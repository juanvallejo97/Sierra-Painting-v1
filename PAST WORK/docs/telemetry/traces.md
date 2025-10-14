# Performance Traces Schema

## Overview

Performance traces measure latency and duration of critical operations. Traces are sent to Firebase Performance Monitoring.

## Naming Convention

- Use forward slash paths: `feature/operation`
- Suffix with `_ms` for millisecond metrics
- Use descriptive names: `timeclock/clock_in_decision_ms`

## Trace Types

| Trace Name | Description | Target (p95) |
|------------|-------------|--------------|
| `timeclock/clock_in_decision_ms` | Full clock-in flow (location + validation + write) | ≤2000ms |
| `timeclock/clock_out_decision_ms` | Full clock-out flow | ≤2000ms |
| `timeclock/location_acquisition_ms` | Time to get GPS location | ≤1000ms |
| `timeclock/function_roundtrip_ms` | Network + function execution time | ≤600ms |
| `admin/review_load_ms` | Admin Review screen data load | ≤1000ms |
| `admin/bulk_approve_ms` | Bulk approve operation | ≤2000ms |
| `invoice/create_from_time_ms` | Invoice creation from time entries | ≤5000ms |
| `app/boot_ms` | App initialization to first frame | ≤3000ms |

## Timeclock Traces

### `timeclock/clock_in_decision_ms`

**Description**: Measures end-to-end clock-in latency from button tap to success/failure.

**Start Point**: User taps "Clock In" button

**End Point**: Success message shown OR error message shown

**Custom Attributes**:
| Attribute | Type | Description |
|-----------|------|-------------|
| `has_location_permission` | boolean | Whether permission already granted |
| `gps_accuracy_m` | number | GPS accuracy (rounded to 10m) |
| `distance_bucket` | string | Distance bucket (`within`, `10-50m`, `50-100m`, `>100m`) |
| `result` | string | Outcome (`success`, `geofence_fail`, `accuracy_fail`, `network_fail`) |

**Implementation**:
```dart
final trace = FirebasePerformance.instance.newTrace('timeclock/clock_in_decision_ms');
await trace.start();

try {
  // Clock-in logic here
  await _handleClockIn();

  trace.putAttribute('result', 'success');
} catch (e) {
  trace.putAttribute('result', _categorizeError(e));
} finally {
  await trace.stop();
}
```

### `timeclock/clock_out_decision_ms`

**Description**: Measures clock-out latency.

**Start Point**: User taps "Clock Out" button

**End Point**: Success/warning/error message shown

**Custom Attributes**:
| Attribute | Type | Description |
|-----------|------|-------------|
| `within_geofence` | boolean | Whether within geofence at clock-out |
| `shift_duration_hours` | number | Shift duration (rounded to 0.5h) |
| `result` | string | Outcome (`success`, `success_with_warning`, `fail`) |

### `timeclock/location_acquisition_ms`

**Description**: Measures GPS lock time.

**Start Point**: Call to `Geolocator.getCurrentPosition()`

**End Point**: Location returned OR timeout

**Custom Attributes**:
| Attribute | Type | Description |
|-----------|------|-------------|
| `accuracy_m` | number | Final accuracy (rounded to 10m) |
| `timeout` | boolean | Whether timed out |
| `signal_type` | string | Signal source (`gps`, `wifi`, `network`) |

### `timeclock/function_roundtrip_ms`

**Description**: Measures network + Cloud Function execution time.

**Start Point**: HTTPS call to `clockIn` or `clockOut` function

**End Point**: Response received

**Custom Attributes**:
| Attribute | Type | Description |
|-----------|------|-------------|
| `function_name` | string | Function called (`clockIn`, `clockOut`) |
| `success` | boolean | Whether call succeeded |
| `retry_count` | number | Number of retries (if retried) |

## Admin Review Traces

### `admin/review_load_ms`

**Description**: Measures Admin Review data loading time.

**Start Point**: Navigate to Admin Review screen

**End Point**: Data rendered in UI

**Custom Attributes**:
| Attribute | Type | Description |
|-----------|------|-------------|
| `exception_filter` | string | Filter selected (`geofence`, `12h`, etc.) |
| `entry_count` | number | Number of entries loaded |
| `has_cache` | boolean | Whether loaded from cache |

**Target**: p95 ≤ 1000ms

### `admin/bulk_approve_ms`

**Description**: Measures bulk approve operation duration.

**Start Point**: User taps "Approve" on selected entries

**End Point**: Success message shown and list refreshed

**Custom Attributes**:
| Attribute | Type | Description |
|-----------|------|-------------|
| `entry_count` | number | Number of entries approved |
| `batch_count` | number | Number of Firestore batches (if >500 entries) |

**Target**: p95 ≤ 2000ms for ≤100 entries

## Invoicing Traces

### `invoice/create_from_time_ms`

**Description**: Measures invoice creation latency.

**Start Point**: User taps "Create Invoice" in dialog

**End Point**: Success message and invoice ID returned

**Custom Attributes**:
| Attribute | Type | Description |
|-----------|------|-------------|
| `entry_count` | number | Number of time entries |
| `total_hours` | number | Total hours (rounded to 0.1h) |
| `validation_ms` | number | Time spent validating entries |
| `write_ms` | number | Time spent in batch write |

**Target**: p95 ≤ 5000ms for 100 entries

## App Lifecycle Traces

### `app/boot_ms`

**Description**: Measures app cold start time.

**Start Point**: `main()` entry

**End Point**: First frame rendered (home/dashboard screen)

**Custom Attributes**:
| Attribute | Type | Description |
|-----------|------|-------------|
| `cold_start` | boolean | Whether cold start (vs warm) |
| `network_available` | boolean | Whether network available |
| `auth_state` | string | Auth state (`signed_in`, `signed_out`) |

**Target**: p95 ≤ 3000ms

## Custom Metrics

In addition to traces, record these custom metrics:

| Metric Name | Type | Description |
|-------------|------|-------------|
| `clock_in_success_rate` | percentage | Clock-in attempts that succeed (target: >95%) |
| `geofence_false_positive_rate` | percentage | Valid clock-ins denied by geofence (target: <1%) |
| `offline_queue_size` | gauge | Number of operations pending sync |
| `admin_review_exceptions_count` | gauge | Number of entries needing review |

## Implementation Notes

### Starting Traces

```dart
// Start trace
final trace = FirebasePerformance.instance.newTrace('timeclock/clock_in_decision_ms');
await trace.start();

// Add custom attributes
trace.putAttribute('has_location_permission', 'true');
trace.putAttribute('result', 'success');

// Stop trace
await trace.stop();
```

### Metric Bucketing

To reduce cardinality, bucket continuous values:

- **Distance**: `within`, `10-50m`, `50-100m`, `>100m`
- **Accuracy**: Round to nearest 10m
- **Duration**: Round to nearest 0.5h

### Sampling

- Sample 100% of traces in staging
- Sample 10-20% of traces in production (adjust based on volume)
- Always trace errors (100% sampling)

### Crashlytics Integration

Set custom keys for debugging:

```dart
FirebaseCrashlytics.instance.setCustomKey('company_id', companyId);
FirebaseCrashlytics.instance.setCustomKey('role', userRole);
FirebaseCrashlytics.instance.setCustomKey('app_stage', 'staging');
```

## SLO Monitoring

Monitor these traces against SLO targets:

| Trace | SLO (p95) | Alert Threshold |
|-------|-----------|-----------------|
| `timeclock/clock_in_decision_ms` | ≤2000ms | >3000ms |
| `timeclock/function_roundtrip_ms` | ≤600ms | >1000ms |
| `admin/review_load_ms` | ≤1000ms | >2000ms |
| `invoice/create_from_time_ms` | ≤5000ms | >8000ms |

## Dashboard Links

- **Firebase Performance**: https://console.firebase.google.com/project/sierra-painting-staging/performance
- **Custom Traces**: Filter by trace name prefix (`timeclock/`, `admin/`, `invoice/`)
- **Crashlytics**: https://console.firebase.google.com/project/sierra-painting-staging/crashlytics
