# Patch Playbook Execution Status

**Date Started**: 2025-10-09
**Last Updated**: 2025-10-09
**Branch**: feat/auth-foundation-day1

---

## ✅ P0 - CRITICAL (Completed)

### 1. ✅ Secrets: .env Bundling Prevention
**Status**: FIXED
**Commits**: `49dddde`, `c8a4f2e` (new CI guard)

**Completed Actions**:
- ✅ Removed `.env` from pubspec.yaml assets
- ✅ Created CI guard workflow (`.github/workflows/guard-env.yml`)
- ✅ Verified .gitignore blocks `.env`
- ✅ Added security warnings in pubspec.yaml comments

**Verification**:
- ✅ No existing build artifacts found (Windows dev environment)
- ✅ CI guard will prevent future bundling
- ⚠️  **ACTION REQUIRED**: If ANY builds were ever deployed with `.env` bundled:
  1. Check distribution channels (Play Store, App Store, Firebase Hosting)
  2. Rotate ALL credentials immediately
  3. Document in `docs/SECURITY_INCIDENTS.md`

**Acceptance Criteria**:
- [x] CI guard passes on this branch
- [x] `.env` not in pubspec.yaml assets
- [x] `.env` in .gitignore
- [ ] **Manual check**: Verify no deployed builds contain .env (if deployed)

---

### 2. ✅ Firestore Composite Indexes
**Status**: FIXED
**Commit**: `c8a4f2e`

**Completed Actions**:
- ✅ Created 11 composite indexes in `firestore.indexes.json`
- ✅ Covers all major query patterns:
  - Jobs (company + status + date, company + assignedCrew + date)
  - Estimates (company + status + date, company + date)
  - Invoices (company + status + date, company + date)
  - Timeclock entries (user + date, company + user + date)
  - Audit logs (company + timestamp, action + timestamp)
  - Users (company + role)

**Next Steps**:
```bash
# Deploy indexes to Firebase
firebase deploy --only firestore:indexes --project sierra-painting-staging
firebase deploy --only firestore:indexes --project sierra-painting-prod

# Monitor index build status
# Firebase Console → Firestore → Indexes
```

**Acceptance Criteria**:
- [x] Indexes defined in firestore.indexes.json
- [ ] **Manual**: Deploy to staging
- [ ] **Manual**: Run all app query paths, verify no "index required" errors
- [ ] **Manual**: Deploy to production

---

## 🟠 P1 - HIGH PRIORITY (In Progress)

### 3. ✅ Implement Telemetry
**Status**: COMPLETED
**Priority**: HIGH
**Time Taken**: 2 hours

**Completed Actions**:
- ✅ Implemented `TelemetryService.initialize()` with Crashlytics, Analytics, Performance
- ✅ Added `FlutterError.onError` and `PlatformDispatcher.instance.onError` handlers
- ✅ Implemented `logEvent()` with Firebase Analytics integration
- ✅ Implemented `logError()` with context enrichment for Crashlytics
- ✅ Implemented `trackScreenView()` for screen tracking
- ✅ Implemented `startTrace()` and `stopTrace()` for Performance Monitoring
- ✅ Implemented `setUserProperties()` for Analytics
- ✅ Implemented `recordMetric()` for custom metrics
- ✅ Implemented `ErrorTracker.setUserContext()` with Crashlytics user ID
- ✅ Implemented `ErrorTracker.clearUserContext()` for logout
- ✅ Implemented `ErrorTracker.recordError()` with Crashlytics integration
- ✅ Implemented `ErrorTracker.recordMessage()` with Crashlytics logging
- ✅ Implemented `ErrorTracker.setCustomKey()` with Crashlytics custom keys
- ✅ Added web platform detection (Crashlytics not supported on web)

**Files Modified**:
- `lib/core/telemetry/telemetry_service.dart` - All TODOs implemented
- `lib/core/telemetry/error_tracker.dart` - All TODOs implemented

**Acceptance Criteria**:
- [x] Crashlytics initialization complete with error handlers
- [x] User context (uid, email, orgId) attached via custom keys
- [x] Performance trace API implemented (startTrace/stopTrace)
- [x] Analytics screen tracking and events implemented
- [ ] **Manual**: Test error appears in Crashlytics dashboard (requires deployment)
- [ ] **Manual**: Verify traces in Performance Monitoring (requires deployment)

---

### 4. ✅ Wire Invoice/Estimate Create Actions
**Status**: COMPLETED
**Priority**: HIGH
**Time Taken**: 2.5 hours

**Completed Actions**:
- ✅ Created `Invoice` domain model with status enum, line items, Firestore serialization
- ✅ Created `Estimate` domain model with status enum, line items, Firestore serialization
- ✅ Created `InvoiceRepository` with full CRUD operations and pagination
- ✅ Created `EstimateRepository` with full CRUD operations and pagination
- ✅ Wired "Create Invoice" button in `invoices_screen.dart` with companyId from custom claims
- ✅ Wired "Create Estimate" button in `estimates_screen.dart` with companyId from custom claims
- ✅ Added proper error handling with SnackBar feedback
- ✅ Added authentication checks before creating documents
- ✅ Used Result pattern for type-safe error handling

**Files Created**:
- `lib/features/invoices/domain/invoice.dart` - Domain model
- `lib/features/invoices/data/invoice_repository.dart` - Repository layer
- `lib/features/estimates/domain/estimate.dart` - Domain model
- `lib/features/estimates/data/estimate_repository.dart` - Repository layer

**Files Modified**:
- `lib/features/invoices/presentation/invoices_screen.dart` - Wired create action
- `lib/features/estimates/presentation/estimates_screen.dart` - Wired create action

**Acceptance Criteria**:
- [x] Invoice domain model with Firestore serialization
- [x] Estimate domain model with Firestore serialization
- [x] InvoiceRepository with create, get, list, update operations
- [x] EstimateRepository with create, get, list, update operations
- [x] "Create Invoice" button functional with auth + companyId checks
- [x] "Create Estimate" button functional with auth + companyId checks
- [x] Proper error feedback via SnackBar
- [x] Follows existing architecture patterns (cf. TimeEntry/TimeclockRepository)
- [ ] **TODO**: Create invoice/estimate detail screens for navigation
- [ ] **TODO**: Create form dialogs for user input (currently creates sample data)
- [ ] **TODO**: Security rules tests (deferred to task #7)

---

### 5. ✅ Real Network Connectivity Check
**Status**: COMPLETED
**Priority**: HIGH
**Time Taken**: 1 hour

**Completed Actions**:
- ✅ Created `NetworkStatus` service using `connectivity_plus` package
- ✅ Implemented `isOnline()` async method with connectivity checking
- ✅ Implemented `onlineStream` broadcast stream for reactive UI
- ✅ Added connectivity type detection (WiFi, mobile, ethernet, etc.)
- ✅ Added helper methods: `isOnWifi()`, `isOnMobile()`, `isOnEthernet()`
- ✅ Updated `TimeclockRepository` to use `NetworkStatus` service
- ✅ Replaced hardcoded `isOnline ?? true` with real connectivity check
- ✅ Added `_checkConnectivity()` helper with graceful fallback
- ✅ Wired `NetworkStatus` into `timeclockRepositoryProvider`
- ✅ Added proper dispose cleanup for stream resources

**Files Created**:
- `lib/core/services/network_status.dart` - NetworkStatus service with providers

**Files Modified**:
- `lib/features/timeclock/data/timeclock_repository.dart` - Integrated NetworkStatus (line 111)

**Acceptance Criteria**:
- [x] NetworkStatus service created with connectivity_plus
- [x] isOnline() method returns real connectivity status
- [x] onlineStream provides reactive updates
- [x] TimeclockRepository uses real network check (no more hardcoded true)
- [x] Graceful fallback if NetworkStatus unavailable
- [x] Riverpod providers for NetworkStatus and online status stream
- [ ] **TODO**: Add offline UI indicators (e.g., SnackBar, banner)
- [ ] **TODO**: Wire onlineStream to trigger queue sync on reconnect

---

### 6. ⏳ Tests for setUserRole Cloud Function
**Status**: PENDING
**Priority**: HIGH
**Estimate**: 2 hours

**Files to Create**:
```
functions/src/auth/__tests__/setUserRole.test.ts
```

**Test Cases**:
- [ ] Happy path: Admin can set user role
- [ ] Deny: Non-admin cannot set role
- [ ] Validation: Invalid role rejected (Zod validation)
- [ ] Validation: Missing companyId rejected
- [ ] Audit log: Role change logged with performer
- [ ] Custom claims: Verified in token after update
- [ ] Firestore doc: Role updated for legacy compatibility

**Acceptance Criteria**:
- [ ] All tests pass locally
- [ ] CI runs tests and fails build on error
- [ ] Coverage report generated

---

### 7. ⏳ Security Rules Tests
**Status**: PENDING
**Priority**: HIGH
**Estimate**: 3-4 hours

**Files to Create/Update**:
```
firestore-tests/rules.spec.mjs
firestore-tests/storage-rules.spec.mjs
```

**Test Cases**:

**Firestore Rules**:
- [ ] Company isolation: User A cannot access Company B data
- [ ] Admin can create estimates
- [ ] Manager can create estimates
- [ ] Staff can create estimates
- [ ] Crew CANNOT create estimates
- [ ] Users can only update own timeclock entries
- [ ] Admins can update any data in their company

**Storage Rules**:
- [ ] Assigned crew can upload job photos
- [ ] Unassigned crew CANNOT upload job photos
- [ ] Admin can upload to any job
- [ ] File size limit enforced (10MB)
- [ ] File type validation (images only for photos)

**Acceptance Criteria**:
- [ ] `npm --prefix firestore-tests test` passes
- [ ] CI runs rules tests
- [ ] All security boundaries tested

---

### 8. ✅ CI Test Timeouts
**Status**: COMPLETED
**Priority**: MEDIUM-HIGH
**Time Taken**: 4 hours

**Issue**: `flutter test --coverage` timed out after 3 minutes; widget tests crashed with `[core/no-app]` error.

**Root Cause**:
- Crashlytics accessed before Firebase init in test mode
- Test harness attempted Firebase initialization causing platform channel errors
- Test detection (`isUnderTest`) wasn't reliable without `--dart-define` flag
- Pre-commit hook used incorrect `flutter format` command

**Completed Actions**:
- ✅ Created `lib/core/env/build_flags.dart` with enhanced test detection
- ✅ Guarded all Crashlytics access behind `isUnderTest` flag in `main.dart`
- ✅ Removed Firebase initialization from `test/test_harness.dart`
- ✅ Added `--dart-define=FLUTTER_TEST=true` to test runner scripts
- ✅ Fixed integration test arg passing in PowerShell (`cmd /c`)
- ✅ Stabilized `smoke_login_test.dart` (removed Firebase setup, used `pump` vs `pumpAndSettle`)
- ✅ Fixed pre-commit hook: `dart format` (not `flutter format`)
- ✅ Fixed `router_redirect_test.dart` (aligned with working auth test pattern)
- ✅ Created CI workflows: `tests.yml` and `guard-widget-tests.yml`
- ✅ Added Firebase emulator config with proper async handling

**Files Created**:
- `lib/core/env/build_flags.dart` - Test mode detection
- `lib/core/firebase_emulators.dart` - Emulator connection helper
- `scripts/run_test_local_temp.ps1` - Windows test runner with TEMP isolation
- `scripts/run_integration_with_emulators.ps1` - Integration test runner
- `.github/workflows/tests.yml` - CI test workflow with coverage gate
- `.github/workflows/guard-widget-tests.yml` - Prevents Firebase in widget tests
- `integration_test/bootstrap_test.dart` - Firebase emulator smoke test

**Files Modified**:
- `lib/main.dart` - Consolidated Crashlytics guards
- `test/flutter_test_config.dart` - Minimal harness (no Firebase)
- `test/test_harness.dart` - Removed Firebase init
- `test/smoke_login_test.dart` - Stabilized with pump() instead of pumpAndSettle()
- `test/widget/router_redirect_test.dart` - Fixed failing test
- `.husky/pre-commit` - Fixed format command
- `.gitignore` - Added test temp directories

**Results**:
- ✅ 68/68 widget tests passing (was 67/68 with [core/no-app] crashes)
- ✅ No platform channel errors in test mode
- ✅ Tests complete in <10 seconds (was timing out at 3+ minutes)
- ✅ Coverage file generates successfully
- ✅ Pre-commit hook works correctly

**Acceptance Criteria**:
- [x] All tests complete under 2 minutes
- [x] Coverage file generated (`coverage/lcov.info`)
- [x] CI test workflows created
- [x] Widget tests isolated from Firebase (no platform channels)
- [ ] **CI verification**: Awaiting push to verify workflows run successfully

---

## 🟡 P2 - MEDIUM PRIORITY (Not Started)

### 9. ⏳ Canonicalize Web Target
**Status**: PENDING
**Tasks**:
- [ ] Archive or delete `webapp/` (Next.js)
- [ ] Archive or delete `web_react/` (Vite)
- [ ] Document Flutter Web as canonical
- [ ] Add CI guard for deprecated paths

---

### 10. ⏳ Package.json Hygiene
**Status**: PENDING
**Tasks**:
- [ ] Remove `functions/functions/` nested package.json
- [ ] Consider npm workspaces
- [ ] Single `npm audit` at root

---

### 11. ⏳ Dart Imports + const Fixes
**Status**: PENDING
**Tasks**:
- [ ] Run `dart fix --apply`
- [ ] Create feature barrel exports
- [ ] Migrate imports to use barrels
- [ ] Add lint rules to enforce

---

### 12. ⏳ Increase Test Coverage to 60%+
**Status**: PENDING
**Current**: ~10%
**Target**: 60%+

---

### 13. ⏳ Mock UI Gating
**Status**: PENDING
**Tasks**:
- [ ] Gate mock routes behind `kReleaseMode == false`
- [ ] Replace `debugPrint` with logger
- [ ] Strip debug code from release builds

---

## 🟢 P3 - LOW PRIORITY (Backlog)

### 14-18. Various Technical Debt Items
**Status**: Backlog

---

## 📊 Overall Progress

| Phase | Items | Completed | In Progress | Pending |
|-------|-------|-----------|-------------|---------|
| **P0** | 2 | 2 ✅ | 0 | 0 |
| **P1** | 6 | 4 ✅ | 0 | 2 ⏳ |
| **P2** | 5 | 0 | 0 | 5 |
| **P3** | 5 | 0 | 0 | 5 |
| **Total** | 18 | 6 (33%) | 0 | 12 (67%) |

---

## 🎯 Next Actions (Priority Order)

1. **Deploy Firestore indexes** to staging and production
2. **Verify no .env in deployed builds** (manual check if any exist)
3. ~~**Implement telemetry**~~ ✅ COMPLETED (Task #3)
4. ~~**Wire invoice/estimate create actions**~~ ✅ COMPLETED (Task #4)
5. ~~**Add network connectivity check**~~ ✅ COMPLETED (Task #5)
6. **Write tests** for setUserRole Cloud Function (Task #6)
7. **Create security rules tests** (Firestore + Storage) (Task #7)
8. ~~**Fix test timeouts**~~ ✅ COMPLETED (Task #8)

---

## 📝 Commits Created

| Commit | Description | Phase |
|--------|-------------|-------|
| `dbc575a` | Fix TypeScript errors in setUserRole | P0 (prep) |
| `49dddde` | Remove .env from pubspec.yaml assets | P0 #1 |
| `c8a4f2e` | Add CI guard + Firestore indexes | P0 #1 #2 |
| `4c8464f` | Implement telemetry, invoice/estimate, network | P1 #3 #4 #5 |
| `f54c90d` | Resolve [core/no-app] error in widget tests | P1 #8 |
| `f02160c` | Fix router_redirect_test failure | P1 #8 |
| `b21c92a` | Add test temp directories to .gitignore | P1 #8 |
| `c9884bc` | Fix unawaited_futures in firebase_emulators | P1 #8 |
| `b228862` | Add CI workflows (tests + guard) | P1 #8 |
| `ca10068` | Add Firebase bootstrap integration test | P1 #8 |

---

## 🔗 References

- **DEBUGGING_REPORT.md** - Full analysis of 18 issues
- **SECURITY_QUICK_START.md** - Security actions checklist
- **SECURITY_MIGRATION_GUIDE.md** - Custom claims migration
- **CLAUDE.md** - Development commands

---

**Status**: P0 complete ✅ + P1 67% complete (4/6 tasks) ✅

**Completed This Session**:
- ✅ Task #3: Telemetry (Crashlytics + Analytics + Performance)
- ✅ Task #4: Invoice/Estimate creation with repositories
- ✅ Task #5: Network connectivity check
- ✅ Task #8: CI test timeouts and widget test isolation

**Remaining P1 Tasks**:
- ⏳ Task #6: Tests for setUserRole Cloud Function
- ⏳ Task #7: Security rules tests (Firestore + Storage)

**Next Session**: Implement Task #6 (setUserRole tests) and Task #7 (security rules tests).
