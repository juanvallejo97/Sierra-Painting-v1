# Navigation QA Checklist

## Purpose
This checklist ensures all navigation flows, logout functionality, route guards, and accessibility features work correctly after the Ship-Today UI Overhaul implementation.

---

## Pre-Testing Setup

### Environment
- [ ] Testing on debug build: `flutter run`
- [ ] Testing on release build: `flutter run --release`
- [ ] Testing on physical device (not just emulator)
- [ ] Firebase Auth configured correctly
- [ ] Test users created with proper roles:
  - [ ] Admin user
  - [ ] Worker user
  - [ ] User with no role assigned (optional)

### Test Data
- [ ] At least 1 active job
- [ ] At least 1 time entry
- [ ] At least 1 invoice
- [ ] At least 1 estimate

---

## 1. Admin Logout Flow

### Admin Drawer Logout (Primary Test)
**Route:** Any admin screen → Open drawer → Tap "Sign Out"

- [ ] **Step 1:** Login as admin user
- [ ] **Step 2:** Navigate to `/admin/home`
- [ ] **Step 3:** Open drawer (tap hamburger menu)
- [ ] **Step 4:** Tap "Sign Out" button (red text at bottom)
- [ ] **Step 5:** Logout confirmation dialog appears
- [ ] **Step 6:** Tap "Cancel" → Dialog dismisses, still logged in ✓
- [ ] **Step 7:** Tap "Sign Out" again → Tap "Confirm"
- [ ] **Expected:** User signed out ≤2s, redirected to `/login`
- [ ] **Verify:** Cannot navigate back to admin screens
- [ ] **Verify:** Login required to access admin features again
- [ ] **Console:** No errors in debug console

**Screen Reader Test (Optional):**
- [ ] Enable TalkBack (Android) or VoiceOver (iOS)
- [ ] Navigate to "Sign Out" button
- [ ] **Expected:** Announces "Sign Out, button, Sign out of your account and return to login screen"

---

## 2. Worker Logout Flow

### Settings Screen Logout
**Route:** `/worker/home` → Settings tab → Tap "Sign Out"

- [ ] **Step 1:** Login as worker user
- [ ] **Step 2:** Navigate to `/worker/home` (Time tab)
- [ ] **Step 3:** Tap "Settings" tab in bottom navigation
- [ ] **Step 4:** Scroll to bottom, tap "Sign Out" button (red text)
- [ ] **Step 5:** Logout confirmation dialog appears
- [ ] **Step 6:** Tap "Cancel" → Dialog dismisses, still logged in ✓
- [ ] **Step 7:** Tap "Sign Out" again → Tap "Confirm"
- [ ] **Expected:** User signed out ≤2s, redirected to `/login`
- [ ] **Verify:** Cannot navigate back to worker screens
- [ ] **Verify:** Login required to access worker features again
- [ ] **Console:** No errors in debug console

**Screen Reader Test (Optional):**
- [ ] Enable TalkBack (Android) or VoiceOver (iOS)
- [ ] Navigate to "Sign Out" button
- [ ] **Expected:** Announces "Sign Out, button, Sign out of your account and return to login screen"

---

## 3. Admin Navigation Flows

### Drawer Navigation
**Route:** Any admin screen → Open drawer → Navigate between screens

- [ ] **Home** → Tap "Home" → Navigates to `/admin/home` ✓
- [ ] **Time Review** → Tap "Time Review" → Navigates to `/admin/review` ✓
- [ ] **Jobs** → Tap "Jobs" → Navigates to `/jobs` ✓
- [ ] **Estimates** → Tap "Estimates" → Navigates to `/estimates` ✓
- [ ] **Invoices** → Tap "Invoices" → Navigates to `/invoices` ✓
- [ ] **Settings** → Tap "Settings" → Navigates to `/settings` ✓

**Visual Feedback:**
- [ ] Selected item highlighted with primary color
- [ ] Selected item text bold
- [ ] Selected item background tinted
- [ ] Drawer closes after navigation

**Screen Reader Test (Optional):**
- [ ] Each drawer item announces: "{Title}, button, Navigate to {Title}"
- [ ] Selected state announced for current screen

---

## 4. Worker Navigation Flows

### Bottom Navigation
**Route:** Any worker screen → Tap bottom nav tabs

- [ ] **Time** → Tap "Time" → Navigates to `/worker/home` ✓
- [ ] **History** → Tap "History" → Navigates to `/worker/history` ✓
- [ ] **Settings** → Tap "Settings" → Navigates to `/settings` ✓

**Visual Feedback:**
- [ ] Selected tab highlighted with primary color
- [ ] Selected tab icon colored
- [ ] Unselected tabs grayed out

**Screen Reader Test (Optional):**
- [ ] Time tab announces: "Clock In/Out" tooltip
- [ ] History tab announces: "Timesheet History" tooltip
- [ ] Settings tab announces: "Settings" tooltip

---

## 5. Route Coverage

### Auth Routes
- [ ] **/** → Shows LoginScreen ✓
- [ ] **/login** → Shows LoginScreen ✓
- [ ] **/signup** → Shows SignUpScreen ✓
- [ ] **/forgot** → Shows ForgotPasswordScreen ✓

### Admin Routes
- [ ] **/admin/home** → Shows AdminHomeScreen ✓
- [ ] **/admin/review** → Shows AdminReviewScreen ✓

### Worker Routes
- [ ] **/worker/home** → Shows WorkerDashboardScreen ✓
- [ ] **/worker/history** → Shows WorkerHistoryScreen ✓
- [ ] **/timeclock** → Shows WorkerDashboardScreen (alias) ✓

### Shared Routes
- [ ] **/jobs** → Shows JobsScreen ✓
- [ ] **/jobs/create** → Shows JobCreateScreen ✓
- [ ] **/jobs/{jobId}** → Shows JobDetailScreen ✓
- [ ] **/invoices** → Shows InvoicesScreen ✓
- [ ] **/invoices/create** → Shows InvoiceCreateScreen ✓
- [ ] **/invoices/{invoiceId}** → Shows InvoiceDetailScreen ✓
- [ ] **/estimates** → Shows EstimatesScreen ✓
- [ ] **/estimates/create** → Shows EstimateCreateScreen ✓
- [ ] **/estimates/{estimateId}** → Shows EstimateDetailScreen ✓
- [ ] **/settings** → Shows SettingsScreen ✓
- [ ] **/settings/privacy** → Shows PrivacyScreen ✓

---

## 6. Dashboard & Route Guards

### Dashboard Routing (Role-Based)
**Test Admin User:**
- [ ] Navigate to `/dashboard`
- [ ] **Expected:** Shows loading spinner briefly
- [ ] **Expected:** Redirects to `/admin/home` ≤2s
- [ ] **Console:** No errors

**Test Worker User:**
- [ ] Navigate to `/dashboard`
- [ ] **Expected:** Shows loading spinner briefly
- [ ] **Expected:** Redirects to `/worker/home` ≤2s
- [ ] **Console:** No errors

### Unknown Route Fallback
**Test with Valid User:**
- [ ] Navigate to `/unknown-route-12345`
- [ ] **Expected:** Redirects to DashboardScreen
- [ ] **Expected:** DashboardScreen routes to role home
- [ ] Total time: ≤2s
- [ ] **Console:** No errors

**Test with No Role User (Optional):**
- [ ] Navigate to `/dashboard` with user that has no role claim
- [ ] **Expected:** Shows "No Role Assigned" screen
- [ ] **Expected:** "Refresh Claims" button visible
- [ ] **Expected:** "Back to Login" button visible
- [ ] Tap "Refresh Claims" → Re-fetches claims ✓
- [ ] Tap "Back to Login" → Signs out and redirects to `/login` ✓

**Test with Unknown Role User (Optional):**
- [ ] Navigate to `/dashboard` with user that has unknown role (e.g., "superuser")
- [ ] **Expected:** Shows "Unknown Role" screen
- [ ] **Expected:** Shows role name in error message
- [ ] **Expected:** "Back to Login" button visible
- [ ] Tap "Back to Login" → Signs out and redirects to `/login` ✓

---

## 7. Loading States

### Dashboard Loading State
- [ ] Navigate to `/dashboard` with network throttling enabled
- [ ] **Expected:** Visible `CircularProgressIndicator` appears
- [ ] **Expected:** No blank screen during loading
- [ ] **Expected:** Resolves to role home ≤2s (normal network)
- [ ] **Expected:** Resolves to role home ≤5s (slow network)

---

## 8. Deep Linking (Optional)

### Direct Navigation to Protected Routes
**Test while logged out:**
- [ ] Attempt to navigate directly to `/admin/home`
- [ ] **Expected:** Handles gracefully (doesn't crash)
- [ ] **Expected:** Redirects to login or shows error

**Test while logged in as worker:**
- [ ] Attempt to navigate directly to `/admin/home`
- [ ] **Expected:** Handles gracefully (doesn't crash)
- [ ] **Note:** Role guards not fully implemented yet

---

## 9. Navigation Stack Management

### Back Button Behavior After Logout
- [ ] Login as any user
- [ ] Navigate through several screens
- [ ] Logout via any method
- [ ] **Expected:** Redirected to `/login`
- [ ] Press back button (Android) or swipe back (iOS)
- [ ] **Expected:** Does NOT return to protected screens
- [ ] **Expected:** App exits or stays on login screen

### Drawer Navigation Stack
- [ ] Login as admin
- [ ] Navigate: Home → Jobs → Estimates → Invoices
- [ ] **Expected:** Each navigation replaces the route (no stack buildup)
- [ ] Press back button
- [ ] **Expected:** App exits (no history to go back to)

---

## 10. Accessibility

### Screen Reader Navigation (TalkBack/VoiceOver)
- [ ] Enable screen reader
- [ ] Navigate through admin drawer
- [ ] **Expected:** All items announced with labels and hints
- [ ] Navigate to logout button
- [ ] **Expected:** "Sign Out, button, Sign out of your account and return to login screen"
- [ ] Navigate through worker bottom nav
- [ ] **Expected:** Each tab announced with tooltip

### Tap Target Sizes
- [ ] Verify all navigation buttons ≥48x48 logical pixels
- [ ] Test on small screen device
- [ ] **Expected:** Easy to tap without precision

### Color Contrast
- [ ] Verify navigation text readable against background
- [ ] Test in light mode and dark mode (if supported)
- [ ] **Expected:** Meets WCAG AA standards (4.5:1 contrast ratio)

---

## 11. Performance

### Route Transition Speed (Release Build)
- [ ] Build in release mode: `flutter run --release`
- [ ] Navigate between admin screens
- [ ] **Expected:** Route transitions ≤500ms
- [ ] Navigate between worker screens
- [ ] **Expected:** Route transitions ≤500ms

### Logout Speed
- [ ] Time from tapping "Confirm" to seeing login screen
- [ ] **Expected:** ≤2 seconds
- [ ] **Console:** No performance warnings

---

## 12. Edge Cases

### Rapid Navigation
- [ ] Rapidly tap drawer items
- [ ] **Expected:** No crashes, no duplicate routes
- [ ] **Expected:** Final navigation completes successfully

### Rapid Logout
- [ ] Tap logout button rapidly
- [ ] **Expected:** Confirmation dialog appears once
- [ ] **Expected:** Logout completes once

### Network Interruption During Logout
- [ ] Enable airplane mode
- [ ] Attempt to logout
- [ ] **Expected:** Local sign out still works
- [ ] **Expected:** Redirects to login screen
- [ ] **Expected:** App doesn't hang

### Logout During Active Operation
- [ ] Start creating a new job
- [ ] Open drawer and logout
- [ ] **Expected:** Logout completes
- [ ] **Expected:** Unsaved work lost (acceptable)
- [ ] **Expected:** No crash

---

## 13. Automated Tests

### Router Smoke Tests
```bash
flutter test test/app/router_smoke_test.dart
```

- [ ] All tests pass ✓
- [ ] No timeout errors
- [ ] No assertion failures
- [ ] Test output shows all 10 test cases passing

**Expected Output:**
```
✓ Auth routes render without error
✓ Admin routes render without error
✓ Worker routes render without error
✓ Shared routes render without error
✓ Create routes render without error
✓ Timeclock route renders without error
✓ Unknown route falls back to DashboardScreen
✓ Dashboard route shows loading state then resolves
✓ Dashboard route handles no role error
✓ Dashboard route handles unknown role
```

### Full Test Suite
```bash
flutter test
```

- [ ] All tests pass ✓
- [ ] No new test failures introduced
- [ ] No broken tests due to widget type changes

---

## 14. Regression Testing

### Features NOT Modified (Should Still Work)
- [ ] Time clock functionality (clock in/out)
- [ ] Job creation and editing
- [ ] Invoice creation and editing
- [ ] Estimate creation and editing
- [ ] Permission requests (location, camera, etc.)
- [ ] Firebase connectivity
- [ ] Analytics logging

---

## 15. Documentation Review

### Code Documentation
- [ ] `UI_ROUTER_CHANGELOG.md` exists and is up-to-date
- [ ] `NAV_QA_CHECKLIST.md` exists (this file)
- [ ] Inline code comments added where appropriate
- [ ] Widget conversions documented

### Migration Guide
- [ ] Widget type changes documented
- [ ] Provider dependencies documented
- [ ] Rollback instructions clear

---

## Sign-Off

### QA Tester
- **Name:** _________________________
- **Date:** _________________________
- **Build:** _________________________
- **Device:** _________________________
- **OS Version:** _________________________

### Issues Found
| Issue # | Description | Severity | Status |
|---------|-------------|----------|--------|
|         |             |          |        |
|         |             |          |        |
|         |             |          |        |

### Final Approval
- [ ] All critical issues resolved
- [ ] All tests passing
- [ ] Ready for production deployment

**Approved By:** _________________________
**Date:** _________________________

---

## Notes

### Common Issues & Solutions

**Issue:** Logout button doesn't work
- **Check:** Console for errors
- **Check:** Widget is `ConsumerWidget` or `ConsumerStatefulWidget`
- **Check:** `ref.invalidate(userProfileProvider)` is called

**Issue:** Unknown route shows error screen
- **Check:** `_notFound` function returns `DashboardScreen`
- **Check:** User has valid role claim

**Issue:** Navigation drawer doesn't close
- **Check:** `Navigator.pop(context)` called before navigation
- **Check:** Drawer is not disabled

**Issue:** Screen reader not announcing properly
- **Check:** `Semantics` widget wrapping navigation items
- **Check:** `label` and `hint` properties set

---

## Appendix: Test User Setup

### Create Admin Test User
1. Sign up with email: `admin@test.com`
2. Set password: `TestAdmin123!`
3. Use Firebase Console to add custom claims:
   ```json
   {
     "role": "admin",
     "companyId": "test-company-id"
   }
   ```

### Create Worker Test User
1. Sign up with email: `worker@test.com`
2. Set password: `TestWorker123!`
3. Use Firebase Console to add custom claims:
   ```json
   {
     "role": "worker",
     "companyId": "test-company-id"
   }
   ```

### Create No-Role Test User (Optional)
1. Sign up with email: `norole@test.com`
2. Set password: `TestNoRole123!`
3. Do NOT add custom claims (leave as regular user)

---

**END OF CHECKLIST**
