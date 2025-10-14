# MVP Integration Checklist — Geofenced Timeclock + Invoicing

**Status**: Ready for final integration and canary deployment
**Target**: Release Candidate 1 (mvp-rc1)

## ✅ Core Implementation Complete

### Timeclock — Geofence-Enforced Time Tracking

#### Backend (Cloud Functions)
- [x] `clockIn()` — Transactional, idempotent, adaptive geofence (75-250m)
- [x] `clockOut()` — Transactional, soft-failure on geofence miss, exception tagging
- [x] `editTimeEntry()` — Admin callable with overlap detection & audit trail
- [x] `autoClockOut()` — Scheduled function (every 15 min), 12h cap, idempotent
- [x] **Input validation**: lat/lng bounds, accuracy 0-2000m, clientEventId ≤64 chars
- [x] **Assignment windows**: Enforces startDate/endDate at clock-in
- [x] **Error codes**: Consistent HttpsError codes (unauthenticated, permission-denied, failed-precondition, invalid-argument)
- [x] **Audit fields**: radiusUsedM, accuracyAtInM, distanceAtInM, distanceAtOutM, geoOkIn, geoOkOut

#### Security Rules
- [x] `timeEntries`: Function-write only (`allow write: if false`)
- [x] `clockEvents`: Workers create own, append-only (no updates/deletes)
- [x] `assignments`: Admin/Manager CRUD, workers read own
- [x] `jobs`: Admin/Manager create/update, Admin delete
- [x] **Invoiced immutability**: timeEntries with invoiceId are immutable (enforced server-side)

#### Firestore Indexes
- [x] Active shift lookup: `companyId + userId + clockOutAt ASC`
- [x] Timesheet view: `companyId + userId + clockInAt DESC`
- [x] Job detail: `companyId + jobId + clockInAt DESC`
- [x] Assignments: `companyId + userId + active`, `companyId + jobId + active`
- [x] Clock events: `companyId + userId + createdAt DESC`

#### Domain Models
- [x] `TimeEntry` — Backward-compatible field parsing (clockIn/clockInAt, geoOk/geoOkIn)
- [x] `Job` — Top-level lat/lng/radiusM fields for functions
- [x] `Assignment` — startDate/endDate window fields
- [x] `CompanySettings` — timezone (IANA string) for timesheet grouping

#### Dart Interfaces
- [x] `TimeclockApi` — clockIn/clockOut with structured requests/responses
- [x] `TimeclockApiImpl` — Firebase Callable implementation with error mapping
- [x] `ClockAttemptResult` — Structured result with success/error/userMessage

### Invoicing — Time-to-Invoice Integration

#### Backend (Cloud Functions)
- [x] `createInvoiceFromTime()` — Atomic batch write (invoice + lock entries)
  - Validates all entries approved, not invoiced, closed
  - Aggregates hours, creates line item
  - Locks entries with invoiceId
  - Creates audit record
  - Max 100 entries per batch

#### Dart Interfaces
- [x] `BillingRepository` — Interface with createInvoiceFromTime, getInvoiceWithTimeEntries, unlockTimeEntries
- [x] `Money`, `CustomerRef`, `CreateInvoiceFromTimeRequest`, `InvoiceFromTimeResult` value objects

### Admin Features

#### UI Skeletons
- [x] `AdminReviewScreen` — Exception-first tabs (Outside Geofence, >12h, Auto Clock-Out, Overlapping, Disputed)
  - Summary stats card
  - Bulk selection & approval
  - Edit/approve/reject actions
  - Filter by date range, search by worker/job
- [x] `WorkerDashboardScreen` — Clock in/out with error handling skeleton
  - Error message mapping (geofence, assignment, GPS accuracy)
  - "Explain Issue" quick action for geofence errors
  - Warning display for clock-out outside geofence
- [x] `JobCreateScreen` — Geofence settings (environment type, custom radius)
- [x] `AssignmentPickerDialog` — Worker assignment with search/filters

### Feature Flags & Canary Support
- [x] `FeatureFlagsService` — Remote Config integration
- [x] Flags: `timeclockEnabled`, `adminReviewEnabled`, `invoiceFromTimeEnabled`
- [x] `testingAllowlist` — UID allowlist for canary testing
- [x] Admin always-enabled for testing/support

## 🧪 Testing

### Emulator Tests
- [x] `timekeeping-rules.test.ts` — 10 tests covering clockEvents and timeEntries security
- [x] `timeclock-advanced.test.ts` — Transactional, edit, invoiced, assignment windows
- [x] `timeclock_geofence_test.dart` — 8 integration tests covering all acceptance criteria

### Test Coverage
- [x] Clock in inside geofence ≤2s ✓
- [x] Clock in outside geofence returns clear error ✓
- [x] Idempotency: same clientEventId returns same entry ✓
- [x] Cannot clock in without assignment ✓
- [x] Cannot clock in twice simultaneously ✓
- [x] Clock out inside/outside geofence ✓
- [x] Transactional clock-out prevents double writes ✓
- [x] Invoiced entries immutable ✓

### Commands to Run
```bash
# Rules tests
firebase emulators:exec --only firestore -- \
  npm --prefix functions test -- --testPathPattern=timekeeping-rules

# Advanced tests
firebase emulators:exec --only firestore -- \
  npm --prefix functions test -- --testPathPattern=timeclock-advanced

# Integration tests
flutter test integration_test/timeclock_geofence_test.dart \
  --dart-define=USE_EMULATORS=true

# Widget tests
flutter test test/ --concurrency=1
```

## 📋 Pre-Deployment Verification

### Manual Smoke Test (Emulators)
```bash
# 1. Start emulators
firebase emulators:start

# 2. Run app against emulators
flutter run --dart-define=USE_EMULATOR=true

# 3. Test sequence:
# - Clock in inside geofence → Success in <2s
# - Clock out inside geofence → Success with no warning
# - Clock in outside geofence → Clear error with distance
# - Clock out outside geofence → Success with warning, entry flagged
# - Attempt clock in before assignment start → Clear error
# - Admin Review → Exceptions tab shows flagged entry
# - Edit entry → Creates audit record
# - Create invoice from time → Locks entries
```

### Staging Deployment
```bash
# 1. Deploy to staging
firebase use staging
npm --prefix functions run build
firebase deploy --only firestore:rules,firestore:indexes,functions

# 2. Verify
# - Functions listed: clockIn, clockOut, editTimeEntry, autoClockOut, createInvoiceFromTime
# - Indexes created successfully
# - Rules deployed

# 3. Smoke test on staging
# - Android device against staging
# - Web app against staging
# - Verify Admin Review shows exceptions
```

## 🚀 Canary Rollout Plan

### Phase 1: Functions + Rules to Prod (Feature Flags OFF)
```bash
firebase use production
npm --prefix functions run build
firebase deploy --only functions,firestore:rules,firestore:indexes
```

**Remote Config (Firebase Console):**
```json
{
  "timeclock_enabled": false,
  "admin_review_enabled": false,
  "invoice_from_time_enabled": false,
  "testing_allowlist": "uid1,uid2,uid3"
}
```

### Phase 2: Enable for Admins + Testers (24-48h)
**Update Remote Config:**
```json
{
  "timeclock_enabled": true,
  "admin_review_enabled": true,
  "invoice_from_time_enabled": true,
  "testing_allowlist": "tester_uid1,tester_uid2"
}
```

**Monitor SLOs:**
- Functions p95 ≤ 600ms
- Clock-in success (inside geofence) ≤ 2s end-to-end
- Crash-free sessions ≥ 99%
- Out-of-geofence false-positive rate < 1%

### Phase 3: Full Rollout (If SLOs Green)
**Update Remote Config:**
```json
{
  "timeclock_enabled": true,
  "admin_review_enabled": true,
  "invoice_from_time_enabled": true,
  "testing_allowlist": ""
}
```

### Rollback Plan
**Instant (No Redeployment):**
```json
{
  "timeclock_enabled": false,
  "admin_review_enabled": false,
  "invoice_from_time_enabled": false
}
```

**Full Rollback (If Needed):**
```bash
# Revert to previous functions deployment
firebase functions:delete clockIn clockOut editTimeEntry autoClockOut createInvoiceFromTime
# Deploy previous known-good version
git checkout <previous-tag>
firebase deploy --only functions
```

## 🔍 Acceptance Gates — Final Verification

### Timeclock
- [ ] Inside geofence → success in ≤2s
- [ ] Outside geofence → clear error with distance
- [ ] Idempotent (retry returns same entry)
- [ ] No overlap (admin edit detects and tags)
- [ ] One active shift per user (transactional guard)
- [ ] Auto clock-out caps at 12h, never double-processes
- [ ] Assignment windows enforced

### Security
- [ ] Clients cannot mutate timeEntries (function-only)
- [ ] Invoiced entries immutable from clients
- [ ] Cross-tenant reads/writes denied
- [ ] Admin edits create audit trail

### Invoicing
- [ ] Create invoice from 100 entries in ≤5s
- [ ] Entries lock atomically (all or nothing)
- [ ] Double-invoicing prevented
- [ ] Editing invoice doesn't mutate timeEntries

### UX
- [ ] Worker dashboard: single giant CTA, clear errors
- [ ] Geofence error shows distance + "Explain Issue" button
- [ ] Clock-out warning visible when outside geofence
- [ ] Admin Review: exceptions first, bulk approve works

### Ops
- [ ] Functions p95 ≤ 600ms (staging + canary)
- [ ] Auto clock-out scheduled job runs without errors
- [ ] Crashlytics shows <1% crash rate

## 📝 Known Limitations (Month 2 Items)
- GPS accuracy prime (permission prompt) not yet implemented
- Dispute dialog not yet connected to backend
- Offline sync banner not yet implemented
- Geohash for long-term location storage (TTL) not yet implemented
- Weekly audit report for force-edits not yet implemented

## 📚 Documentation
- [ ] README: 90-second emulator setup guide
- [ ] ADR: Timekeeping model (event → function → entry)
- [ ] Support macros: GPS accuracy, geofence, assignment window errors
- [ ] CHANGELOG: MVP-RC1 entry

## 🎯 Final Sign-Off

**Ready for RC1 when:**
- [x] All ✅ items above complete
- [ ] Emulator tests green
- [ ] Staging smoke test passes
- [ ] Feature flags configured in Remote Config
- [ ] Canary allowlist populated
- [ ] Rollback plan tested

**Approval:**
- [ ] Tech Lead reviewed integration checklist
- [ ] Product confirmed acceptance gates
- [ ] Ops confirmed monitoring setup

---

**Last Updated**: 2025-01-11
**Version**: MVP-RC1
**Branch**: `release/mvp-rc1`
