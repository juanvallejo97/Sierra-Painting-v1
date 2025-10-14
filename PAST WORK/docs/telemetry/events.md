# Telemetry Events Schema

## Overview

Analytics events track user actions and outcomes for product insights and debugging. Events are sent to Firebase Analytics with structured parameters.

## Naming Convention

- Use snake_case for event names
- Prefix with feature area (e.g., `clock_`, `admin_`, `invoice_`)
- Suffix with action/outcome (e.g., `_attempt`, `_success`, `_fail`)

## Common Parameters

All events include these standard parameters:

| Parameter | Type | Description |
|-----------|------|-------------|
| `company_id` | string | Company ID (for segmentation) |
| `user_role` | string | User role (worker, admin, manager) |
| `app_stage` | string | Environment (staging, production) |
| `timestamp` | number | Unix timestamp (ms) |

## Timeclock Events

### `clock_in_attempt`

Fired when worker taps "Clock In" button (before location/validation).

| Parameter | Type | Description |
|-----------|------|-------------|
| `job_id` | string | Job ID |
| `assignment_id` | string | Assignment ID |
| `has_location` | boolean | Whether location permission granted |

### `clock_in_success`

Fired when clock-in succeeds after validation.

| Parameter | Type | Description |
|-----------|------|-------------|
| `job_id` | string | Job ID |
| `distance_m` | number | Distance from job site (meters) |
| `accuracy_m` | number | GPS accuracy (meters) |
| `within_geofence` | boolean | Whether within geofence radius |
| `response_time_ms` | number | Function round-trip time |

### `clock_in_fail`

Fired when clock-in fails validation.

| Parameter | Type | Description |
|-----------|------|-------------|
| `job_id` | string | Job ID |
| `reason` | string | Failure reason (`geofence`, `accuracy`, `assignment`, `network`) |
| `distance_m` | number | Distance from job site (if known) |
| `accuracy_m` | number | GPS accuracy (if known) |
| `error_code` | string | Function error code |
| `error_message` | string | User-facing error message |

### `clock_out_success`

Fired when clock-out succeeds.

| Parameter | Type | Description |
|-----------|------|-------------|
| `job_id` | string | Job ID |
| `time_entry_id` | string | Time entry ID |
| `duration_hours` | number | Shift duration (hours) |
| `distance_m` | number | Distance from job site at clock-out |
| `within_geofence` | boolean | Whether within geofence at clock-out |
| `has_warning` | boolean | Whether soft-failure warning shown |

### `clock_out_fail`

Fired when clock-out fails.

| Parameter | Type | Description |
|-----------|------|-------------|
| `reason` | string | Failure reason (`no_active_entry`, `network`) |
| `error_code` | string | Function error code |

### `geofence_explain_tapped`

Fired when worker taps "Explain Issue" on geofence error.

| Parameter | Type | Description |
|-----------|------|-------------|
| `job_id` | string | Job ID |
| `distance_m` | number | Distance from job site |
| `accuracy_m` | number | GPS accuracy |

## Admin Review Events

### `admin_review_loaded`

Fired when Admin Review screen loads.

| Parameter | Type | Description |
|-----------|------|-------------|
| `exception_filter` | string | Initial filter (`geofence`, `12h`, `overlap`, etc.) |
| `pending_count` | number | Total pending entries |
| `load_time_ms` | number | Time to load data |

### `admin_approve`

Fired when admin approves entry/entries.

| Parameter | Type | Description |
|-----------|------|-------------|
| `entry_count` | number | Number of entries approved (1 or bulk) |
| `is_bulk` | boolean | Whether bulk operation |
| `exception_types` | string[] | Exception types in approved entries |

### `admin_reject`

Fired when admin rejects entry/entries.

| Parameter | Type | Description |
|-----------|------|-------------|
| `entry_count` | number | Number of entries rejected |
| `is_bulk` | boolean | Whether bulk operation |
| `reason_length` | number | Character count of rejection reason |

### `admin_edit_entry`

Fired when admin edits time entry.

| Parameter | Type | Description |
|-----------|------|-------------|
| `time_entry_id` | string | Time entry ID |
| `fields_changed` | string[] | Fields edited (`clockInAt`, `clockOutAt`, `notes`) |
| `reason_length` | number | Character count of edit reason |
| `has_overlap` | boolean | Whether edit caused overlap |

## Invoicing Events

### `invoice_created_from_time`

Fired when invoice is successfully created from time entries.

| Parameter | Type | Description |
|-----------|------|-------------|
| `invoice_id` | string | Invoice ID |
| `entries_count` | number | Number of time entries included |
| `total_hours` | number | Total hours billed |
| `total_amount` | number | Total invoice amount (USD) |
| `hourly_rate` | number | Billing rate used |
| `creation_time_ms` | number | Time to create invoice |

### `invoice_creation_failed`

Fired when invoice creation fails.

| Parameter | Type | Description |
|-----------|------|-------------|
| `entries_count` | number | Number of entries attempted |
| `error_code` | string | Function error code |
| `error_message` | string | Error message |

## GPS & Location Events

### `location_permission_requested`

Fired when app requests location permission.

| Parameter | Type | Description |
|-----------|------|-------------|
| `trigger` | string | What triggered request (`clock_in`, `manual`) |
| `primer_shown` | boolean | Whether primer dialog shown first |

### `location_permission_granted`

Fired when user grants location permission.

| Parameter | Type | Description |
|-----------|------|-------------|
| `after_primer` | boolean | Whether primer was shown |

### `location_permission_denied`

Fired when user denies location permission.

| Parameter | Type | Description |
|-----------|------|-------------|
| `is_forever` | boolean | Whether permanently denied |
| `after_primer` | boolean | Whether primer was shown |

### `gps_accuracy_warning_shown`

Fired when GPS accuracy warning displayed.

| Parameter | Type | Description |
|-----------|------|-------------|
| `accuracy_m` | number | Current GPS accuracy (meters) |
| `threshold_m` | number | Required threshold (50m) |

## Offline & Sync Events

### `clock_operation_queued`

Fired when clock operation queued for offline sync.

| Parameter | Type | Description |
|-----------|------|-------------|
| `operation` | string | Operation type (`clock_in`, `clock_out`) |
| `job_id` | string | Job ID |
| `queue_size` | number | Number of items in queue after add |

### `sync_completed`

Fired when offline queue syncs successfully.

| Parameter | Type | Description |
|-----------|------|-------------|
| `operations_synced` | number | Number of operations synced |
| `sync_duration_ms` | number | Time to sync all operations |

### `sync_failed`

Fired when offline sync fails.

| Parameter | Type | Description |
|-----------|------|-------------|
| `operations_attempted` | number | Number of operations attempted |
| `operations_failed` | number | Number of operations that failed |
| `error_summary` | string | Summary of errors |

## Error Events

### `api_error`

Fired when API call fails unexpectedly.

| Parameter | Type | Description |
|-----------|------|-------------|
| `endpoint` | string | Function name (`clockIn`, `clockOut`, etc.) |
| `error_code` | string | Error code |
| `error_message` | string | Error message |
| `http_status` | number | HTTP status code (if applicable) |

## Usage Notes

- **Do NOT log PII**: Never include names, emails, phone numbers, or precise GPS coordinates
- **Log coordinates as distance**: Use distance from job site, not actual lat/lng
- **Batch events**: Use Analytics batching to reduce network calls
- **Test in dev**: Verify events fire correctly before deploying
- **Monitor SLOs**: Track `response_time_ms` for performance regression
