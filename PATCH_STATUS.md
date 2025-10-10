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

### 3. ⏳ Implement Telemetry
**Status**: PENDING
**Priority**: HIGH
**Estimate**: 2-3 hours

**TODOs to Implement**:
```dart
// lib/core/telemetry/telemetry_service.dart
- Initialize Firebase Crashlytics
- Initialize Firebase Analytics
- Initialize Firebase Performance Monitoring

// lib/core/telemetry/error_tracker.dart
- Set user context in Crashlytics
- Clear user context on logout
- Send errors to Crashlytics
```

**Acceptance Criteria**:
- [ ] Forced test error appears in Crashlytics dashboard
- [ ] User context (uid, email) attached to crash reports
- [ ] First-open trace in Performance Monitoring
- [ ] Primary screen renders tracked

---

### 4. ⏳ Wire Invoice/Estimate Create Actions
**Status**: PENDING
**Priority**: HIGH
**Estimate**: 3-4 hours

**Current Issue**:
```dart
// lib/features/invoices/presentation/invoices_screen.dart:67
onAction: null, // TODO: Wire to create invoice action

// lib/features/estimates/presentation/estimates_screen.dart:66
onAction: null, // TODO: Wire to create estimate action
```

**Tasks**:
- [ ] Create `InvoiceService` with `createInvoice()` method
- [ ] Create `EstimateService` with `createEstimate()` method
- [ ] Enforce RBAC (companyId + role checks via custom claims)
- [ ] Wire to UI buttons
- [ ] Navigate to detail screen after create
- [ ] Add Firestore security rule tests

**Acceptance Criteria**:
- [ ] "Create Invoice" button works, creates document, navigates to detail
- [ ] "Create Estimate" button works, creates document, navigates to detail
- [ ] Security rules tests pass (admin can create, crew cannot)

---

### 5. ⏳ Real Network Connectivity Check
**Status**: PENDING
**Priority**: HIGH
**Estimate**: 1-2 hours

**Current Issue**:
```dart
// lib/features/timeclock/data/timeclock_repository.dart:107
final online = isOnline ?? true; // TODO: Add network connectivity check
```

**Tasks**:
- [ ] Use `connectivity_plus` package (already in pubspec.yaml ✅)
- [ ] Create `NetworkStatus` service
- [ ] Add `isOnline()` async method
- [ ] Add `onlineStream` for reactive UI
- [ ] Update timeclock repository to use real check
- [ ] Add offline UI indicators

**Acceptance Criteria**:
- [ ] Toggle device network → UI shows offline badge
- [ ] Offline queue holds operations
- [ ] Operations retry on reconnect

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

### 8. ⏳ CI Test Timeouts
**Status**: PENDING
**Priority**: MEDIUM-HIGH
**Estimate**: 2 hours

**Issue**: `flutter test --coverage` timed out after 3 minutes

**Investigation Steps**:
```bash
# Run interactively to find culprit
flutter test -r expanded --concurrency=1 --timeout=2x

# Check specific test files
flutter test test/smoke_login_test.dart --timeout=30s
flutter test integration_test/app_boot_smoke_test.dart --timeout=30s
```

**Common Fixes**:
- [ ] Ensure all async tests await `pumpAndSettle()`
- [ ] Add `TestWidgetsFlutterBinding.ensureInitialized()` to test config
- [ ] Use `fakeAsync` for timer/stream tests
- [ ] Add explicit timeouts to hanging operations

**Acceptance Criteria**:
- [ ] All tests complete under 2 minutes
- [ ] Coverage file generated (`coverage/lcov.info`)
- [ ] CI test step succeeds

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
| **P1** | 6 | 0 | 0 | 6 ⏳ |
| **P2** | 5 | 0 | 0 | 5 |
| **P3** | 5 | 0 | 0 | 5 |
| **Total** | 18 | 2 (11%) | 0 | 16 (89%) |

---

## 🎯 Next Actions (Priority Order)

1. **Deploy Firestore indexes** to staging and production
2. **Verify no .env in deployed builds** (manual check if any exist)
3. **Implement telemetry** (Crashlytics + Analytics + Performance)
4. **Wire invoice/estimate create actions** (core functionality)
5. **Add network connectivity check** (offline mode fix)
6. **Write tests** for setUserRole Cloud Function
7. **Create security rules tests** (Firestore + Storage)
8. **Fix test timeouts** to enable coverage reporting

---

## 📝 Commits Created

| Commit | Description | Phase |
|--------|-------------|-------|
| `dbc575a` | Fix TypeScript errors in setUserRole | P0 (prep) |
| `49dddde` | Remove .env from pubspec.yaml assets | P0 #1 |
| `c8a4f2e` | Add CI guard + Firestore indexes | P0 #1 #2 |

---

## 🔗 References

- **DEBUGGING_REPORT.md** - Full analysis of 18 issues
- **SECURITY_QUICK_START.md** - Security actions checklist
- **SECURITY_MIGRATION_GUIDE.md** - Custom claims migration
- **CLAUDE.md** - Development commands

---

**Status**: P0 items complete ✅. Ready for P1 implementation.

**Next Session**: Start with telemetry implementation (highest P1 priority).
