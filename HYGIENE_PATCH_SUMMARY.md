# Hygiene Patch Summary - Staging Readiness

**Date:** 2025-10-12
**Branch:** `hygiene/staging-readiness` (recommended)
**Status:** 🟢 **7/13 tasks complete**

---

## ✅ Completed Patches

### 1. **Android Build Configuration** ✅
**File:** `android/app/build.gradle`
**Issue:** Invalid/purged Gradle config blocked Android builds
**Fix:**
- Restored complete Gradle configuration
- Set minSdkVersion 21, compileSdkVersion 34, targetSdkVersion 34
- Enabled MultiDex, ProGuard, and Firebase plugins
- Configured debug signing (release signing commented for security)

**Commit:** `fix(android): restore valid build.gradle with SDK 34 and Firebase plugins`

---

### 2. **App Check Enabled for Staging** ✅
**Files:**
- `assets/config/public.env`
- `functions/.env.staging` (created)

**Issue:** Security vulnerability - App Check disabled in staging
**Fix:**
- Changed `ENABLE_APP_CHECK=false` → `true` in public.env
- Created `.env.staging` with `ENFORCE_APPCHECK=true` for Functions
- Added developer instructions for debug token registration

**Commit:** `fix(security): enable App Check for staging deployment`

---

### 3. **Asset Caching Headers** ✅
**File:** `firebase.json`
**Issue:** No cache headers → slow loads, wasted bandwidth
**Fix:**
- Added `no-cache` for `index.html` (always fresh)
- Added 1-year immutable cache for `*.js`, `*.css`, fonts, images
- Preserves existing security headers (CSP, X-Frame-Options, etc.)

**Commit:** `fix(web): add immutable asset caching headers to hosting config`

---

### 4. **Company Claims Helper** ✅
**File:** `lib/core/auth/company_claims.dart` (created)
**Issue:** Hardcoded test companyId prevented multi-tenancy
**Fix:**
- Created cached, timeout-guarded claims resolver
- 5-minute cache with SharedPreferences
- 3-second timeout with fallback to cache
- Includes Riverpod provider for easy integration

**Commit:** `feat(auth): add company claims helper with caching and timeout`

---

### 5. **Removed Hardcoded Company ID** ✅
**File:** `lib/features/timeclock/presentation/providers/timeclock_providers.dart`
**Issue:** `company = 'test-company-staging'` hardcoded in 2 locations
**Fix:**
- Replaced with `ref.watch(companyIdProvider.future)`
- Both `activeJobProvider` and `activeEntryProvider` updated
- Added null checks for missing claims

**Commit:** `fix(timeclock): remove hardcoded companyId, use claims-based lookup`

---

### 6. **Firestore Data Migration Script** ✅
**File:** `tools/migrate_timeEntries_to_time_entries.cjs` (created)
**Issue:** Collection name inconsistency blocked Clock In
**Fix:**
- Created migration script with dry-run mode
- Batch writes (500 docs per batch)
- Merge writes (preserves existing data)
- Safety checks and verbose logging

**Commit:** `chore(tools): add Firestore migration script for collection rename`

**Usage:**
```bash
# Dry run
node tools/migrate_timeEntries_to_time_entries.cjs --dry-run

# Execute
node tools/migrate_timeEntries_to_time_entries.cjs
```

---

### 7. **Collection Name Migration (Providers)** ✅
**File:** `lib/features/timeclock/presentation/providers/timeclock_providers.dart`
**Issue:** Queries used legacy `timeEntries`, `workerId`, `clockIn` fields
**Fix:**
- `timeEntries` → `time_entries` (4 locations)
- `workerId` → `userId` (4 locations)
- `clockIn` → `clockInAt` (3 locations)
- All queries now match canonical schema

**Commit:** `refactor(timeclock): migrate collection and field names to canonical schema`

---

## ⏳ Remaining Tasks

### 8. **iOS Firebase Config** ⚠️ **MANUAL STEP REQUIRED**
**File:** `lib/firebase_options.dart:63-70`
**Issue:** iOS points to dev project `to-do-app-ac602` instead of staging
**Fix Required:**
```bash
flutterfire configure \
  --project sierra-painting-staging \
  --platforms=ios \
  --ios-bundle-id com.sierrapainting.app
```

**Why manual?** Requires Firebase CLI auth and interactive project selection
**Status:** 🔴 **BLOCKS iOS DEPLOYMENT**

---

### 9. **Firestore Timeout Guards** ⚠️
**Files:** All Firestore queries in providers
**Issue:** No timeouts → silent hangs possible
**Fix Required:** Wrap all `.get()` calls with:
```dart
.timeout(const Duration(seconds: 10), onTimeout: () {
  throw TimeoutException('Firestore query timed out');
})
```

**Locations:**
- `timeclock_providers.dart:167` (assignments query)
- `timeclock_providers.dart:182` (job doc fetch)
- `timeclock_providers.dart:216` (time entries query)
- ...and ~15 more in other repositories

**Status:** 🟡 **HIGH PRIORITY**

---

### 10. **Stream Limits** ⚠️
**File:** `timeclock_providers.dart:36-46`
**Issue:** Unbounded stream on `time_entries` → memory leak
**Fix Required:**
- Current: No limit on `activeTimeEntryProvider` base query
- Add `.limit(100)` or tighter
- Auto-cancel polling streams after clock-out

**Status:** 🟡 **MEDIUM PRIORITY**

---

### 11. **Firestore Rules Tests in CI** ⚠️
**File:** `.github/workflows/ci.yml`
**Issue:** No Rules validation in PR checks → regressions possible
**Fix Required:** Add step:
```yaml
- name: Test Firestore Rules
  working-directory: functions
  run: firebase emulators:exec "npm run test:rules"
```

**Status:** 🟡 **MEDIUM PRIORITY**

---

### 12. **Staging Deployment Workflow** ⚠️
**File:** `.github/workflows/staging.yml` (create)
**Issue:** Manual staging deploys error-prone
**Fix Required:** Create automated workflow triggered by push to `staging` branch
**Template:** See execution brief Section G

**Status:** 🟡 **MEDIUM PRIORITY**

---

### 13. **Collection Name Migration (Remaining Files)** ⚠️
**Files:** 42 more Dart files (from grep results)
**Issue:** Providers migrated, but other services/repositories still use legacy names
**Fix Required:** Global find/replace:
- `timeEntries` → `time_entries`
- `workerId` → `userId` (where applicable)
- `clockIn` → `clockInAt` (where applicable)

**Files:**
- `lib/core/offline/sync_service.dart`
- `lib/core/services/timeclock_service.dart`
- `lib/core/models/time_entry.dart`
- `lib/features/timeclock/data/*.dart`
- `lib/features/admin/data/*.dart`
- ...and ~37 more

**Status:** 🟡 **HIGH PRIORITY**

---

## 🚀 Deployment Checklist

### Pre-Deploy (Staging)

- [x] Android build.gradle restored
- [x] App Check enabled
- [x] Asset caching configured
- [x] Hardcoded companyId removed
- [x] Company claims helper created
- [x] Collection migration script created
- [x] Providers migrated to canonical names
- [ ] **iOS Firebase config updated** 🔴 **BLOCKER**
- [ ] Firestore timeout guards added
- [ ] Remaining 42 files migrated to canonical names
- [ ] Firestore data migrated (`node tools/migrate_timeEntries_to_time_entries.cjs`)
- [ ] All tests passing (`flutter test --concurrency=1`)
- [ ] Functions build successful (`npm --prefix functions run build`)

### Deploy Steps

1. **Run migration script:**
   ```bash
   # Dry run first
   node tools/migrate_timeEntries_to_time_entries.cjs --dry-run

   # Execute
   GOOGLE_APPLICATION_CREDENTIALS=path/to/staging-key.json \
   node tools/migrate_timeEntries_to_time_entries.cjs
   ```

2. **Fix iOS config:**
   ```bash
   flutterfire configure --project sierra-painting-staging --platforms=ios
   ```

3. **Deploy to staging:**
   ```bash
   firebase use staging
   flutter build web --dart-define=FLAVOR=staging
   npm --prefix functions run build
   firebase deploy --only hosting,functions,firestore:rules,firestore:indexes
   ```

4. **Verify:**
   ```bash
   # Web smoke test
   open https://sierra-painting-staging.web.app

   # Android
   flutter run -d <device> --dart-define=USE_EMULATOR=false

   # iOS
   flutter run -d <ios-device> --dart-define=USE_EMULATOR=false
   ```

---

## 📋 Verification Commands

Run these to verify the patch:

```bash
# 1. No hardcoded test company
! grep -r "test-company-staging" lib/ --include="*.dart"

# 2. App Check enabled
grep "ENABLE_APP_CHECK=true" assets/config/public.env

# 3. Cache headers present
grep "immutable" firebase.json

# 4. Android build valid
grep "minSdkVersion" android/app/build.gradle

# 5. Company claims helper exists
test -f lib/core/auth/company_claims.dart

# 6. Migration script exists
test -f tools/migrate_timeEntries_to_time_entries.cjs

# 7. Providers use canonical names
grep -r "collection('time_entries')" lib/features/timeclock/presentation/providers/

# 8. All tests pass
flutter test --concurrency=1

# 9. Functions build
cd functions && npm run typecheck && npm run build && cd ..
```

---

## 🐛 Known Issues

1. **iOS config mismatch** - Points to dev project (manual fix required)
2. **No timeout guards** - Queries can hang silently
3. **Incomplete migration** - 42 more files need canonical names
4. **No Rules tests in CI** - Regressions not caught automatically
5. **84+ TODO markers** - Technical debt to triage

---

## 📚 Related Documentation

- **Audit Report:** See terminal output for full analysis
- **Execution Brief:** Provided by user with detailed patches
- **Schema Docs:** `docs/schemas/time_entry.md`, `docs/schemas/job.md`
- **Bug Report:** `COMPREHENSIVE_BUG_REPORT.md`

---

## 👥 Manual Review Needed

1. **iOS Firebase configuration** - Requires Firebase CLI access
2. **Firestore data migration** - Verify counts match before/after
3. **Remaining Dart file migration** - 42 files to review and update
4. **Timeout values** - Confirm 10s is appropriate for all queries
5. **Stream limits** - Determine appropriate limits per use case

---

**Generated:** 2025-10-12
**By:** Claude Code Hygiene Patch Tool
**Next Action:** Complete remaining tasks 8-13, then run verification checklist
