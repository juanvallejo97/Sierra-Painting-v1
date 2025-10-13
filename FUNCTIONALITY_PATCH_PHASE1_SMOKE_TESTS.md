# Functionality Patch Phase 1 - Smoke Test Checklist

**Date:** 2025-10-12
**Branch:** `feat/functionality-patch-phase1` (recommended)
**Status:** Ready for testing
**Scope:** Web, Android, iOS (iOS requires config fix first)

---

## ✅ Pre-Test Setup

### Environment Setup

- [ ] Firebase staging project selected: `sierra-painting-staging`
  ```bash
  firebase use staging
  firebase projects:list  # Verify staging is selected
  ```

- [ ] Functions deployed to staging (if needed):
  ```bash
  cd functions && npm run build && cd ..
  firebase deploy --only functions --project sierra-painting-staging
  ```

- [ ] Test user credentials ready (see TEST_CREDENTIALS.md)
  - **Worker:** test-worker@sierrapainting.com
  - **Admin:** test-admin@sierrapainting.com

- [ ] Test job assigned to worker with active geofence:
  - Job ID: `test-job-001`
  - Location: 37.7749 N, -122.4194 W (San Francisco)
  - Radius: 100m
  - Assignment active: true

### iOS-Specific Setup (REQUIRED BEFORE iOS TESTS)

- [ ] **BLOCKER:** Complete iOS Firebase config fix
  - See: `IOS_FIREBASE_CONFIG_FIX.md`
  - Verify: `grep projectId lib/firebase_options.dart | grep ios`
  - Expected: `projectId: 'sierra-painting-staging'`

---

## 🧪 Test Suite 1: Location & Permissions (P1)

### Test 1.1: Location Permission Primer (First-Time User)

**Platform:** Web, Android, iOS

**Steps:**
1. Fresh app install (or clear app data)
2. Sign in as test-worker@sierrapainting.com
3. Navigate to Worker Dashboard
4. Tap "Clock In" button

**Expected:**
- [ ] LocationPermissionPrimer dialog appears
- [ ] Dialog shows friendly explanation and privacy note
- [ ] "Enable Location" button (primary action)
- [ ] "Not Now" button (secondary action)

**Verify:**
- [ ] Dialog UI is clean and centered
- [ ] Text is readable and friendly
- [ ] No system permission dialog shown yet

---

### Test 1.2: System Permission Request

**Platform:** Web (browser prompt), Android (OS dialog), iOS (OS dialog)

**Steps:**
1. Continue from Test 1.1
2. Tap "Enable Location" in primer
3. Handle system permission dialog

**Expected (Web):**
- [ ] Browser asks "Allow location access?"
- [ ] Options: "Allow" / "Block"

**Expected (Android/iOS):**
- [ ] OS permission dialog appears
- [ ] Options: "Allow While Using App" / "Deny"

**Verify:**
- [ ] Primer dialog closes before system dialog shows
- [ ] System dialog text is standard OS message

---

### Test 1.3: Permission Granted - Location Acquired

**Platform:** Web, Android, iOS

**Steps:**
1. Continue from Test 1.2
2. Grant location permission
3. Wait for GPS fix

**Expected:**
- [ ] Loading spinner shows on Clock In button
- [ ] No errors or crashes
- [ ] Location obtained within 15 seconds (outdoors)
- [ ] Clock In proceeds to next step

**Verify:**
- [ ] Debug logs show: "Location obtained - lat: X.XXXX, lng: X.XXXX, accuracy: Xm"
- [ ] Accuracy is <50m (if outdoors)
- [ ] No timeout errors

---

### Test 1.4: GPS Accuracy Warning (Poor Signal)

**Platform:** Web, Android, iOS

**Scenario:** Indoor location or poor GPS

**Steps:**
1. Move indoors (away from windows)
2. Attempt Clock In
3. Wait for location acquisition (fallback chain)

**Expected:**
- [ ] GPSAccuracyWarningDialog appears if accuracy >50m
- [ ] Shows current accuracy value (e.g., "125m")
- [ ] Shows stabilization tip based on accuracy range
- [ ] "Try Again" button (primary)
- [ ] "Cancel" button (secondary)

**Verify:**
- [ ] Tip is contextual:
  - 50-100m: "Move to an open area..."
  - 100-200m: "Step outside or near a window..."
  - >200m: "Go outside and wait 10-30 seconds..."
- [ ] User can cancel or retry

---

### Test 1.5: Location Fallback Chain

**Platform:** Web, Android, iOS

**Scenario:** Test multi-stage fallback

**Steps:**
1. Clock In from indoor location
2. Observe location acquisition attempts

**Expected Sequence:**
- [ ] **Stage 1:** High accuracy GPS (5s timeout)
  - May timeout indoors
- [ ] **Stage 2:** Last known position (if <60s old)
  - Uses cached location
- [ ] **Stage 3:** Balanced accuracy (10s timeout)
  - Final attempt with relaxed accuracy

**Verify:**
- [ ] Debug logs show fallback attempts
- [ ] Location acquired within 15s total
- [ ] No crashes if all stages timeout

---

### Test 1.6: Permission Denied (Soft)

**Platform:** Web, Android, iOS

**Steps:**
1. Fresh app, clear permissions
2. Clock In → primer appears
3. Tap "Enable Location"
4. **Deny** in system dialog

**Expected:**
- [ ] SnackBar appears: "Location permission is required to clock in."
- [ ] Red background
- [ ] Button returns to enabled state
- [ ] No crash

**Verify:**
- [ ] User can retry immediately
- [ ] Next attempt shows primer again

---

### Test 1.7: Permission Denied Forever (Android/iOS)

**Platform:** Android, iOS

**Steps:**
1. Deny permission twice (Android) or select "Don't Ask Again" (iOS)
2. Attempt Clock In

**Expected:**
- [ ] PermissionDeniedForeverDialog appears
- [ ] Message: "Location permission is required..."
- [ ] "Open Settings" button (primary)
- [ ] "Cancel" button (secondary)

**Verify:**
- [ ] Tapping "Open Settings" opens device settings
- [ ] Can navigate to app permissions
- [ ] Granting permission allows Clock In

---

### Test 1.8: Location Services Disabled

**Platform:** Web, Android, iOS

**Steps:**
1. Disable GPS/Location Services in device settings
2. Attempt Clock In

**Expected:**
- [ ] SnackBar appears: "Location services are disabled. Please enable GPS..."
- [ ] Orange background
- [ ] Button returns to enabled state

**Verify:**
- [ ] No crash or infinite loading
- [ ] Enabling GPS in settings allows retry

---

## 🧪 Test Suite 2: Offline Queue (P2)

### Test 2.1: Network Disconnected During Clock In

**Platform:** Web, Android, iOS

**Steps:**
1. Sign in as test-worker
2. **Disconnect network** (airplane mode or WiFi off)
3. Attempt Clock In
4. Grant location permission (if needed)
5. Wait for operation to complete

**Expected:**
- [ ] SnackBar appears with orange background
- [ ] Message: "⏳ Clock in queued for sync. Will retry when connection is restored."
- [ ] Operation does NOT show as clocked in yet
- [ ] Button returns to enabled "Clock In" state

**Verify:**
- [ ] Debug logs show: "⏳ Clock In queued: ..."
- [ ] No crash or red error
- [ ] User understands operation is pending

---

### Test 2.2: Auto-Retry When Online

**Platform:** Web, Android, iOS

**Steps:**
1. Continue from Test 2.1 (Clock In queued)
2. **Reconnect network** (WiFi or cellular)
3. Wait 10-30 seconds

**Expected (Future Enhancement):**
- [ ] Background sync automatically retries
- [ ] Success notification appears (or silent success)
- [ ] Dashboard updates to "Currently Working"

**Note:** Current implementation queues operation but does NOT auto-retry yet (marked as TODO in offline_queue.dart). This test will pass when connectivity listener is implemented.

**Manual Verification:**
- [ ] Operation is stored in queue
- [ ] Can manually trigger via `offlineQueue.replayWhenOnline()`

---

### Test 2.3: Timeout During Clock In

**Platform:** Web, Android, iOS

**Steps:**
1. Sign in as test-worker
2. Simulate slow network (Chrome DevTools → Network → Slow 3G)
3. Attempt Clock In
4. Wait >30 seconds

**Expected:**
- [ ] After 30 seconds, timeout exception occurs
- [ ] SnackBar appears: "Clock in request timed out. Please check your connection..."
- [ ] Red background (error)
- [ ] Operation is queued for offline sync
- [ ] Button returns to enabled state

**Verify:**
- [ ] Timeout is enforced (not infinite wait)
- [ ] User receives clear guidance
- [ ] Can retry immediately

---

### Test 2.4: Clock Out Offline Queueing

**Platform:** Web, Android, iOS

**Steps:**
1. Clock in successfully
2. **Disconnect network**
3. Attempt Clock Out
4. Grant location (should already be granted)

**Expected:**
- [ ] SnackBar appears: "⏳ Clock out queued for sync..."
- [ ] Orange background
- [ ] Still shows "Currently Working" (not clocked out yet)
- [ ] Button returns to enabled "Clock Out" state

**Verify:**
- [ ] Clock Out is queued separately from Clock In
- [ ] Includes clientEventId for deduplication

---

## 🧪 Test Suite 3: Server Idempotency (P3)

### Test 3.1: Duplicate Clock In (Same clientEventId)

**Platform:** Web, Android, iOS

**Scenario:** Simulate network retry with same eventId

**Steps:**
1. Clock In successfully (note the entry ID)
2. Extract clientEventId from debug logs
3. **Manually call clockIn callable again** with same clientEventId (Firebase console or test script)

**Expected:**
- [ ] Server returns existing entry ID (idempotent response)
- [ ] Debug logs show: "Idempotent replay detected"
- [ ] No duplicate time entry created
- [ ] HTTP 200 with {id: "existing-entry-id", ok: true}

**Verify (Firestore Console):**
- [ ] Only ONE time_entries document with that clientEventId
- [ ] Document unchanged after retry

---

### Test 3.2: Prevent Double Clock-In (Active Entry Check)

**Platform:** Web, Android, iOS

**Steps:**
1. Clock In to Job A successfully
2. Immediately attempt to Clock In to Job B (different clientEventId)

**Expected:**
- [ ] Second Clock In fails
- [ ] SnackBar appears: "You are already clocked in to a job. Clock out first."
- [ ] Red background
- [ ] No second time entry created

**Verify (Firestore Console):**
- [ ] Only ONE active time_entries document (clockOutAt == null)
- [ ] companyId and userId match
- [ ] Server transaction prevented race condition

---

### Test 3.3: Clock Out Idempotency

**Platform:** Web, Android, iOS

**Steps:**
1. Clock In successfully
2. Clock Out successfully (note clientEventId)
3. **Manually call clockOut** again with same clockOutClientEventId

**Expected:**
- [ ] Server returns success (idempotent response)
- [ ] No error thrown
- [ ] clockOutAt timestamp unchanged
- [ ] HTTP 200 with {ok: true}

**Verify (Firestore Console):**
- [ ] time_entries document has ONE clockOutAt timestamp
- [ ] clockOutClientEventId field matches
- [ ] No duplicate or overwrite

---

### Test 3.4: Concurrent Clock In Requests (Race Condition)

**Platform:** Web, Android, iOS (requires automation script)

**Scenario:** Test transaction atomicity

**Steps:**
1. Write test script that sends TWO clockIn requests simultaneously
2. Use different clientEventIds but same userId/companyId
3. Both requests should arrive within ~50ms of each other

**Expected:**
- [ ] ONE request succeeds (creates entry)
- [ ] ONE request fails with "Already clocked in to a job"
- [ ] Transaction ensures only one entry created

**Verification (Firestore Console):**
- [ ] Exactly ONE active time_entries document
- [ ] No orphaned or conflicting entries

---

## 🧪 Test Suite 4: Error Handling & UX (P4)

### Test 4.1: Friendly Error Messages

**Platform:** Web, Android, iOS

**Test Various Error Conditions:**

| Condition | Expected SnackBar Message | Color |
|-----------|---------------------------|-------|
| Outside geofence (150m) | "You are 150.0m from the job site. Move closer to clock in." | Red |
| GPS accuracy too low (75m) | "GPS signal is too weak. Move to an open area and try again." | Red |
| Not assigned to job | "You are not assigned to this job. Contact your manager." | Red |
| Already clocked in | "You are already clocked in to a job. Clock out first." | Red |
| Assignment not active | "This job assignment is not active yet. Contact your manager." | Red |
| Assignment expired | "This job assignment has ended. Contact your manager." | Red |
| Unauthenticated | "Please sign in to use the timeclock." | Red |
| Network offline | "⏳ Clock in queued for sync. Will retry when connection is restored." | Orange |
| Timeout (>30s) | "Clock in request timed out. Please check your connection and try again." | Red |

**Verify:**
- [ ] All messages are user-friendly (no technical jargon)
- [ ] Distance values are extracted and displayed
- [ ] Suggestions are actionable ("Move closer", "Contact manager", etc.)
- [ ] Colors match severity (Red = error, Orange = warning/pending)

---

### Test 4.2: UI Debouncing (Prevent Double-Tap)

**Platform:** Web, Android, iOS

**Steps:**
1. Clock In button enabled
2. **Rapidly tap "Clock In" 5 times in <1 second**
3. Observe behavior

**Expected:**
- [ ] Button shows loading spinner immediately
- [ ] Button is **disabled** during processing
- [ ] Only ONE Clock In request is sent
- [ ] No duplicate entries
- [ ] Button returns to enabled after completion

**Verify:**
- [ ] `_isProcessing` flag prevents multiple requests
- [ ] Debug logs show only ONE "Clock In started" message
- [ ] No race conditions

---

### Test 4.3: Success Feedback (Haptic + Visual)

**Platform:** Web, Android, iOS

**Steps:**
1. Clock In successfully
2. Observe feedback

**Expected:**
- [ ] SnackBar appears with green background
- [ ] Message: "✓ Clocked in successfully (ID: xxx)"
- [ ] Entry ID is displayed
- [ ] Duration: 2 seconds
- [ ] **Haptic feedback** (mobile only - subtle vibration)

**Verify:**
- [ ] User receives clear confirmation
- [ ] ID can be used for support tickets
- [ ] Feedback disappears automatically

---

### Test 4.4: Warning vs Error (Clock Out Geofence)

**Platform:** Web, Android, iOS

**Steps:**
1. Clock In at job site (within geofence)
2. Move 150m away from job site
3. Attempt Clock Out

**Expected:**
- [ ] Clock Out **succeeds** (not blocked)
- [ ] SnackBar appears with **orange** background
- [ ] Message: "⚠ Clocked out outside geofence (150.0m from job site). Entry flagged for review."
- [ ] Duration: 5 seconds (longer for warning)
- [ ] Entry is flagged with `exceptionTags: ["geofence_out"]`

**Verify:**
- [ ] User can always clock out (not trapped)
- [ ] Admin can review flagged entries later
- [ ] Warning color distinguishes from error

---

## 🧪 Test Suite 5: Cross-Platform Parity

### Test 5.1: Web - Desktop Browser

**Platform:** Web (Chrome, Firefox, Safari)

**Steps:**
1. Open https://sierra-painting-staging.web.app in desktop browser
2. Run Test Suites 1-4 above
3. Verify all features work

**Expected:**
- [ ] Location permission uses browser prompt ("Allow location access?")
- [ ] All dialogs render correctly
- [ ] SnackBars appear at bottom of screen
- [ ] No responsive layout issues
- [ ] Debug logs appear in browser console

---

### Test 5.2: Android - Physical Device

**Platform:** Android (API 30+)

**Steps:**
1. Build APK: `flutter build apk --release --dart-define=FLAVOR=staging`
2. Install on physical Android device
3. Run Test Suites 1-4 above
4. Test background/foreground transitions

**Expected:**
- [ ] Location permission uses OS dialog
- [ ] GPS acquires location faster outdoors
- [ ] Offline queue persists through app restart
- [ ] No crashes or ANRs

**Additional Android Tests:**
- [ ] Lock screen → unlock → resume Clock In flow
- [ ] Rotate device during Clock In (no state loss)
- [ ] Notification permission handling (if any)

---

### Test 5.3: iOS - Physical Device (After Config Fix)

**Platform:** iOS 15+

**Prerequisite:** ✅ Complete IOS_FIREBASE_CONFIG_FIX.md

**Steps:**
1. Build IPA: `flutter build ios --release --dart-define=FLAVOR=staging`
2. Install on physical iOS device (or TestFlight)
3. Run Test Suites 1-4 above
4. Test iOS-specific behaviors

**Expected:**
- [ ] Location permission uses iOS system dialog
- [ ] "Allow While Using App" vs "Allow Once" options
- [ ] Background location NOT requested (not needed)
- [ ] Writes to **sierra-painting-staging** Firestore

**Verify (Firestore Console):**
- [ ] time_entries documents appear from iOS deviceId
- [ ] companyId matches staging
- [ ] No data appears in dev project

---

## 🧪 Test Suite 6: End-to-End Scenarios

### Scenario A: Full Day Worker Flow

**Platform:** All

**Steps:**
1. Worker arrives at job site (Monday 8:00 AM)
2. Opens app → Clock In
   - Grants location permission
   - GPS acquired (15m accuracy)
   - Within geofence (50m from center)
3. Works for 4 hours
4. Lunch break → Clock Out at 12:00 PM
   - Still within geofence
5. Returns → Clock In at 1:00 PM
6. Works for 4 more hours
7. End of day → Clock Out at 5:00 PM

**Expected:**
- [ ] TWO time_entries documents created
- [ ] Entry 1: 8:00 AM - 12:00 PM (4h)
- [ ] Entry 2: 1:00 PM - 5:00 PM (4h)
- [ ] Dashboard shows "8.0h" total for today
- [ ] "2 Job Sites" (if same job counts once)
- [ ] No errors or warnings

---

### Scenario B: Poor GPS, Offline, Then Success

**Platform:** All

**Steps:**
1. Worker in basement (poor GPS)
2. Attempts Clock In → GPS accuracy warning
3. Moves to open area
4. Retries Clock In
5. Network drops mid-request
6. Operation queued for offline sync
7. Network returns
8. (Future) Auto-retry succeeds

**Expected:**
- [ ] User sees friendly guidance at each step
- [ ] No panic or confusion
- [ ] Operation eventually completes
- [ ] Only ONE time entry created

---

### Scenario C: Concurrent Workers at Same Job

**Platform:** All

**Steps:**
1. Worker A clocks in to Job 123 at 8:00 AM
2. Worker B clocks in to Job 123 at 8:05 AM
3. Both work simultaneously
4. Worker A clocks out at 12:00 PM
5. Worker B continues until 1:00 PM

**Expected:**
- [ ] TWO separate time_entries documents
- [ ] No collision or overwrite
- [ ] Each entry has correct userId
- [ ] Transactions ensure atomicity

---

## ✅ Acceptance Criteria

All tests must pass on **at least 2 platforms** (Web + Android or Web + iOS).

### Core Functionality (P0 - Must Pass)

- [ ] Clock In with location permission flow works
- [ ] GPS accuracy fallback chain functions
- [ ] Clock Out completes successfully
- [ ] Offline queue enqueues failed operations
- [ ] Server prevents duplicate entries (idempotency)
- [ ] Server blocks double clock-ins (one open entry)
- [ ] Friendly error messages display correctly

### UX & Polish (P1 - Should Pass)

- [ ] Permission primer appears before system dialog
- [ ] GPS accuracy warning shows when signal is poor
- [ ] Success feedback is clear and immediate
- [ ] UI debouncing prevents double-tap
- [ ] Timeout enforced (30s) with clear message

### Cross-Platform (P2 - Nice to Have)

- [ ] Web works in Chrome, Firefox, Safari
- [ ] Android works on physical device (API 30+)
- [ ] iOS works after config fix (API 15+)

### Performance (P2 - Nice to Have)

- [ ] Location acquired within 15s (outdoors)
- [ ] Clock In completes within 5s (good connection)
- [ ] No UI freezes or jank
- [ ] App startup time <2s

---

## 🐛 Bug Reporting Template

If any test fails, report using this format:

```
**Test:** Test X.Y - [Test Name]
**Platform:** Web / Android / iOS
**Browser/Device:** Chrome 120 / Pixel 7 / iPhone 14
**Steps:**
1. ...
2. ...

**Expected:** ...
**Actual:** ...

**Logs:** (paste relevant debug logs)

**Screenshot:** (if applicable)

**Severity:** Critical / High / Medium / Low
```

---

## 📊 Test Results Template

```
## Smoke Test Results

**Date:** YYYY-MM-DD
**Tester:** [Your Name]
**Branch:** feat/functionality-patch-phase1
**Commit:** [git SHA]

### Test Suite 1: Location & Permissions
- Test 1.1: ✅ / ❌
- Test 1.2: ✅ / ❌
- Test 1.3: ✅ / ❌
- Test 1.4: ✅ / ❌
- Test 1.5: ✅ / ❌
- Test 1.6: ✅ / ❌
- Test 1.7: ✅ / ❌
- Test 1.8: ✅ / ❌

### Test Suite 2: Offline Queue
- Test 2.1: ✅ / ❌
- Test 2.2: ⚠️ (Not implemented yet - expected)
- Test 2.3: ✅ / ❌
- Test 2.4: ✅ / ❌

### Test Suite 3: Server Idempotency
- Test 3.1: ✅ / ❌
- Test 3.2: ✅ / ❌
- Test 3.3: ✅ / ❌
- Test 3.4: ⚠️ (Requires automation script)

### Test Suite 4: Error Handling
- Test 4.1: ✅ / ❌
- Test 4.2: ✅ / ❌
- Test 4.3: ✅ / ❌
- Test 4.4: ✅ / ❌

### Test Suite 5: Cross-Platform Parity
- Test 5.1 (Web): ✅ / ❌ / ⏸️
- Test 5.2 (Android): ✅ / ❌ / ⏸️
- Test 5.3 (iOS): ✅ / ❌ / 🔴 (Blocked by config fix)

### Test Suite 6: End-to-End
- Scenario A: ✅ / ❌
- Scenario B: ✅ / ❌
- Scenario C: ✅ / ❌

### Overall Status
- **Pass Rate:** X/Y tests passed (Z%)
- **Blockers:** [List any P0 failures]
- **Notes:** [Any observations]
```

---

**Generated:** 2025-10-12
**By:** Claude Code Functionality Patch Phase 1
**Status:** Ready for manual testing
