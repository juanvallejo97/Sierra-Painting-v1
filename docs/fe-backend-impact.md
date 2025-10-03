# Frontend-Backend Impact Matrix

> **Purpose**: Document all backend endpoints, their contracts, and frontend touchpoints for the Sierra Painting application.
>
> **Last Updated**: 2024
> 
> **Status**: Current (v2.0.0-refactor)

---

## Overview

This document maps all backend Cloud Functions to their frontend consumers, including:
- Endpoint definitions and schemas
- Request/response contracts
- Error handling requirements
- Feature flags
- Performance targets
- Frontend components affected

---

## Backend Endpoints

### 1. Authentication Triggers

#### `onUserCreate`
- **Type**: Auth Trigger
- **Trigger**: `firebase-functions.auth.user().onCreate`
- **Purpose**: Create user profile in Firestore on sign-up
- **Contract**: N/A (automatic trigger)
- **Frontend Impact**: 
  - `lib/features/auth/presentation/login_screen.dart` - User creation after sign-up
  - No explicit API call needed
- **Security**: Automatic via Firebase Auth
- **Performance Target**: < 1s
- **Feature Flag**: None

#### `onUserDelete`
- **Type**: Auth Trigger
- **Trigger**: `firebase-functions.auth.user().onDelete`
- **Purpose**: Clean up user data on account deletion
- **Contract**: N/A (automatic trigger)
- **Frontend Impact**: None (admin-triggered)
- **Security**: Automatic via Firebase Auth
- **Performance Target**: < 2s
- **Feature Flag**: None

---

### 2. Time Clock Functions

#### `clockIn`
- **Type**: Callable Function
- **Endpoint**: `functions.httpsCallable('clockIn')`
- **Purpose**: Clock in to a job with offline support and GPS
- **Security**: 
  - Authentication required
  - App Check enforced
  - Job assignment verification
  - Organization scoping
- **Request Schema**:
  ```typescript
  {
    jobId: string,          // Required: Job to clock into
    at: Timestamp,          // Required: Clock-in time
    clientId: string,       // Required: Idempotency key
    geo?: {                 // Optional: GPS location
      lat: number,
      lng: number
    }
  }
  ```
- **Response Schema**:
  ```typescript
  {
    success: boolean,
    entryId: string
  }
  ```
- **Error Codes**:
  - `unauthenticated`: User not logged in
  - `not-found`: Job not found or user profile missing
  - `permission-denied`: Not assigned to job or wrong organization
  - `failed-precondition`: Already clocked in to this job
  - `invalid-argument`: Invalid input data
- **Frontend Impact**:
  - `lib/features/timeclock/presentation/timeclock_screen.dart`
  - Offline queue via `lib/core/services/queue_service.dart`
- **Performance Target**: P95 < 200ms (warm), P95 < 2.5s (cold)
- **Feature Flag**: `feature_b1_clock_in_enabled`
- **Headers**:
  - `X-Request-Id`: Propagated for tracing (optional)
- **Idempotency**: Via `clientId` field (48-hour window)

**TODO**: Create `clockOut` function (similar contract)

---

### 3. Lead Management Functions

#### `createLead`
- **Type**: Callable Function
- **Endpoint**: `functions.httpsCallable('createLead')`
- **Purpose**: Submit lead from public website form
- **Security**:
  - App Check enforced
  - Captcha verification required
  - Rate limiting recommended
- **Request Schema**:
  ```typescript
  {
    name: string,           // Required: Customer name
    email: string,          // Required: Email address
    phone?: string,         // Optional: Phone number
    address: string,        // Required: Service address
    description: string,    // Required: Project description
    captchaToken: string    // Required: reCAPTCHA token
  }
  ```
- **Response Schema**:
  ```typescript
  {
    success: boolean,
    leadId: string
  }
  ```
- **Error Codes**:
  - `invalid-argument`: Invalid input or captcha failed
  - `resource-exhausted`: Rate limit exceeded
  - `internal`: Server error
- **Frontend Impact**:
  - `lib/features/website/presentation/lead_form_screen.dart` (TODO: implement)
  - Public web form (future Next.js app)
- **Performance Target**: P95 < 1.5s
- **Feature Flag**: None (always enabled for public)
- **Headers**:
  - `X-Request-Id`: Generated server-side

---

### 4. Payment Functions

#### `markPaidManual` (Primary)
- **Type**: Callable Function
- **Endpoint**: `functions.httpsCallable('markPaidManual')`
- **Purpose**: Mark invoice as paid (check/cash payment)
- **Security**:
  - Authentication required
  - Admin role required
  - Organization scoping
  - Audit trail created
- **Request Schema**:
  ```typescript
  {
    invoiceId: string,              // Required: Invoice ID
    method: 'check' | 'cash',       // Required: Payment method
    reference?: string,             // Optional: Check number
    note?: string,                  // Optional: Payment notes
    idempotencyKey?: string         // Optional: Custom idempotency key
  }
  ```
- **Response Schema**:
  ```typescript
  {
    success: boolean,
    paymentId: string
  }
  ```
- **Error Codes**:
  - `unauthenticated`: User not logged in
  - `permission-denied`: Not admin
  - `not-found`: Invoice not found
  - `failed-precondition`: Invoice already paid
  - `invalid-argument`: Invalid input
- **Frontend Impact**:
  - `lib/features/invoices/presentation/invoices_screen.dart`
  - Admin panel payment marking
- **Performance Target**: P95 < 300ms
- **Feature Flag**: `feature_c3_mark_paid_enabled`
- **Idempotency**: Via `idempotencyKey` field or auto-generated

#### `markPaymentPaid` (Legacy)
- **Type**: Callable Function
- **Status**: Legacy - prefer `markPaidManual`
- **Contract**: Same as `markPaidManual`
- **Frontend Impact**: Same as `markPaidManual`
- **Note**: Maintained for backward compatibility

#### `stripeWebhook`
- **Type**: HTTP Function
- **Endpoint**: `POST /stripeWebhook`
- **Purpose**: Handle Stripe webhook events
- **Security**:
  - Stripe signature verification
  - No authentication (webhook)
- **Frontend Impact**: None (backend-to-backend)
- **Performance Target**: P95 < 500ms
- **Feature Flag**: `feature_c5_stripe_checkout_enabled`

---

### 5. Utility Functions

#### `healthCheck`
- **Type**: HTTP Function
- **Endpoint**: `GET /healthCheck`
- **Purpose**: Health check for monitoring
- **Security**: None (public)
- **Response Schema**:
  ```typescript
  {
    status: 'ok',
    timestamp: string,
    version: string
  }
  ```
- **Frontend Impact**: None
- **Performance Target**: < 50ms

#### `initializeFlags`
- **Type**: Callable Function
- **Endpoint**: `functions.httpsCallable('initializeFlags')`
- **Purpose**: Initialize feature flags in Firestore
- **Security**: Admin only
- **Frontend Impact**: None (admin utility)
- **Feature Flag**: None

---

## Firestore Collections (Direct Access)

These collections are accessed directly by the Flutter app via Firestore SDK:

### `users`
- **Purpose**: User profiles and roles
- **Frontend Access**: Read via auth provider
- **Security Rules**: User can read own profile, admin can read all
- **Fields**:
  ```typescript
  {
    uid: string,
    email: string,
    displayName: string | null,
    photoURL: string | null,
    role: 'admin' | 'crew_lead' | 'crew',
    orgId: string | null,
    createdAt: Timestamp,
    updatedAt: Timestamp
  }
  ```
- **Frontend Impact**: 
  - `lib/core/providers/auth_provider.dart`
  - RBAC routing decisions

### `jobs`
- **Purpose**: Job information and assignments
- **Frontend Access**: Read via queries
- **Security Rules**: Org-scoped
- **Subcollections**: `timeEntries`
- **Frontend Impact**:
  - `lib/features/timeclock/presentation/timeclock_screen.dart`

### `estimates`
- **Purpose**: Customer estimates
- **Frontend Access**: Read/Write
- **Security Rules**: Org-scoped
- **Frontend Impact**:
  - `lib/features/estimates/presentation/estimates_screen.dart`

### `invoices`
- **Purpose**: Customer invoices
- **Frontend Access**: Read/Write (limited)
- **Security Rules**: 
  - Cannot write `paid`, `paidAt` fields (server-only)
  - Org-scoped
- **Frontend Impact**:
  - `lib/features/invoices/presentation/invoices_screen.dart`

### `payments`
- **Purpose**: Payment records
- **Frontend Access**: Read only
- **Security Rules**: Admin read, server write
- **Frontend Impact**:
  - Payment history viewing

### `activity_logs`
- **Purpose**: Audit trail
- **Frontend Access**: Read only (admin)
- **Security Rules**: Admin read, server write
- **Frontend Impact**:
  - `lib/features/admin/presentation/admin_screen.dart`

---

## Error Handling Requirements

### Frontend Error Mapping

All Cloud Functions use Firebase callable error codes. Frontend should handle:

1. **Authentication Errors** (`unauthenticated`)
   - Action: Redirect to login
   - UI: Show "Session expired" message

2. **Permission Errors** (`permission-denied`)
   - Action: Show error message
   - UI: "You don't have permission to perform this action"

3. **Not Found Errors** (`not-found`)
   - Action: Show error message
   - UI: "Resource not found"

4. **Validation Errors** (`invalid-argument`)
   - Action: Highlight form fields
   - UI: Show validation error messages

5. **Rate Limiting** (`resource-exhausted`)
   - Action: Exponential backoff retry
   - UI: "Too many requests, please try again"

6. **Server Errors** (`internal`, `unknown`)
   - Action: Retry with exponential backoff
   - UI: "Something went wrong, please try again"

---

## RequestId Propagation

### Backend Implementation
- All Cloud Functions use `getOrCreateRequestId()` from `lib/ops/logger.ts`
- RequestId is extracted from `X-Request-Id` header or generated
- Propagated through all logs and traces

### Frontend Requirements
1. Generate unique requestId for each API call (using `uuid` package)
2. Include in headers: `{ 'X-Request-Id': requestId }`
3. Store requestId in error context for debugging
4. Display in error UI for support tickets

**Implementation needed**: Create HTTP interceptor for Firestore callable functions

---

## Performance Targets Summary

| Endpoint | P95 Target (Warm) | P95 Target (Cold) | Notes |
|----------|-------------------|-------------------|-------|
| `clockIn` | < 200ms | < 2.5s | Critical path |
| `createLead` | < 500ms | < 1.5s | Public-facing |
| `markPaidManual` | < 300ms | < 1s | Admin only |
| `stripeWebhook` | < 500ms | < 1s | External service |
| `healthCheck` | < 50ms | < 50ms | Monitoring |
| Firestore reads | < 100ms | N/A | With cache |
| Firestore writes | < 200ms | N/A | With offline queue |

---

## Feature Flags

All feature flags are managed via Firebase Remote Config:

| Flag | Default | Purpose | Frontend Component |
|------|---------|---------|-------------------|
| `feature_b1_clock_in_enabled` | `true` | Enable clock-in | `timeclock_screen.dart` |
| `feature_b2_clock_out_enabled` | `true` | Enable clock-out | `timeclock_screen.dart` |
| `feature_b3_jobs_today_enabled` | `true` | Show jobs list | `timeclock_screen.dart` |
| `feature_c1_create_quote_enabled` | `false` | Create estimates | `estimates_screen.dart` |
| `feature_c3_mark_paid_enabled` | `false` | Manual payments | `invoices_screen.dart` |
| `feature_c5_stripe_checkout_enabled` | `false` | Stripe payments | `invoices_screen.dart` |
| `offline_mode_enabled` | `true` | Offline queue | `queue_service.dart` |
| `gps_tracking_enabled` | `true` | GPS on clock-in | `timeclock_screen.dart` |

**Frontend Implementation**: Check flag before showing UI or making API calls

---

## API Call Flow

### Typical Flow (e.g., Clock In)

```
Flutter App
  │
  ├─> Check feature flag (offline_mode_enabled)
  │
  ├─> Generate requestId (uuid)
  │
  ├─> Call functions.httpsCallable('clockIn')
  │     └─> Include requestId in context
  │
  ├─> [If offline] Queue in Hive
  │     └─> Retry on reconnect
  │
  └─> Handle response/error
        ├─> Success: Update UI
        ├─> Error: Show message & log
        └─> Store requestId for debugging
```

### Offline Queue Flow

```
User action → Queue in Hive → Network available? → Process queue → Update Firestore
                                       │
                                       No → Wait for network
```

---

## Migration Notes

### Recent Changes
- Added requestId propagation infrastructure
- Introduced structured logging with context
- Implemented distributed tracing with OpenTelemetry
- Added idempotency support for all write operations

### Upcoming Changes
- **TODO**: Implement `clockOut` function
- **TODO**: Create `createEstimatePdf` function
- **TODO**: Add Stripe payment flow functions
- **TODO**: Implement scheduled cleanup functions
- **TODO**: Add Firestore trigger functions

---

## Testing Requirements

### Contract Tests
1. Validate request/response schemas match TypeScript types
2. Test all error conditions return correct error codes
3. Verify idempotency behavior
4. Test organization scoping
5. Validate RBAC enforcement

### Integration Tests
1. End-to-end flow with Firebase emulators
2. Offline queue behavior
3. Network error handling
4. Concurrent request handling

---

## Support & Debugging

### Finding Issues
1. Search logs by `requestId` in Cloud Logging
2. Check distributed traces in Cloud Trace
3. Review activity logs in Firestore
4. Check error tracking (Crashlytics)

### Common Issues
1. **Idempotency errors**: Check if operation already processed
2. **Permission denied**: Verify user role and organization
3. **Validation errors**: Check Zod schema in `functions/src/lib/zodSchemas.ts`
4. **Timeouts**: Check function cold start time and optimize

---

## Related Documentation

- [Architecture Overview](./Architecture.md)
- [Feature Flags](./FEATURE_FLAGS.md)
- [Security Rules](../firestore.rules)
- [API Schemas](../functions/src/lib/zodSchemas.ts)
- [Ops Library](../functions/src/lib/ops/README.md)
