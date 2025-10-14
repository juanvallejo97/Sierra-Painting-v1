# 🧪 Manual Smoke Test Guide

**Purpose**: Verify login and admin routes work correctly after patch implementation
**Environment**: Web app served at **http://127.0.0.1:7000**
**Duration**: ~5 minutes

---

## ✅ Pre-Test Checklist

- [ ] Web server running: `http://127.0.0.1:7000`
- [ ] Browser ready (Chrome/Edge recommended)
- [ ] Test credentials available
- [ ] Firebase emulators running (optional for local test)

---

## 🎯 Test Scenarios

### **Test 1: Login Flow**

**Steps**:
1. Open browser → `http://127.0.0.1:7000`
2. Click "Login" or navigate to `/login`
3. Enter test credentials:
   - Email: `admin@test.com`
   - Password: `[your-test-password]`
4. Click "Sign In"

**Expected Results**:
- ✅ No console errors
- ✅ Successful authentication
- ✅ Redirect to dashboard or home screen
- ✅ User sees welcome message or dashboard content

**What to Check**:
- [ ] Login form renders correctly
- [ ] Email/password validation works
- [ ] Loading indicator appears during auth
- [ ] Success feedback displayed
- [ ] Navigation to next screen smooth

---

### **Test 2: Admin Home Screen**

**Steps**:
1. Navigate to `/admin/home`
2. Wait for page to load (max 3 seconds)
3. Observe stat cards
4. Click admin menu button (⋮)
5. Click "Refresh Token" button

**Expected Results**:
- ✅ Page loads without errors
- ✅ Stat cards render with data (or graceful 0 fallback)
- ✅ Admin menu opens on click
- ✅ Token refresh completes in <2 seconds
- ✅ Success message appears

**What to Check**:
- [ ] Stat cards show: Active Jobs, Pending Time Entries, This Week Hours
- [ ] Admin menu button visible in AppBar
- [ ] Token refresh button works
- [ ] No Firebase errors in console
- [ ] Analytics events logged (check console)

**Known Behavior**:
- If no data: Stat cards show "0" (graceful fallback)
- If claims missing: Auto-refresh happens once
- Analytics event: `admin_refresh_token` logged

---

### **Test 3: Admin Review Screen**

**Steps**:
1. Navigate to `/admin/review`
2. Wait for page to load
3. Check probe chip status indicators
4. Click "Refresh" button (circular arrow icon)
5. Click "Filter" button (funnel icon)
6. Observe time entries list

**Expected Results**:
- ✅ Page loads without errors
- ✅ Probe chips show status (OK/LOADING/ERROR)
- ✅ Refresh button triggers data reload
- ✅ Filter button opens dialog
- ✅ Time entries list renders (or empty state)

**What to Check**:
- [ ] AppBar has: Admin Menu, Refresh, Filter buttons
- [ ] Probe chips visible with status colors
- [ ] Category tabs render (All, Pending, Flagged, Approved)
- [ ] Summary stats card shows data
- [ ] Time entries load or show "No entries" message

**Probe Chip Colors**:
- 🟢 Green = OK (successful query)
- 🔵 Blue = LOADING
- 🔴 Red = ERROR
- 🟠 Orange = WARNING

---

### **Test 4: Navigation Flow**

**Steps**:
1. From Admin Home → click "Review" quick action
2. From Admin Review → click Admin Menu → "Home"
3. From Admin Home → click back button
4. Verify no navigation errors

**Expected Results**:
- ✅ All navigation smooth and error-free
- ✅ Routes resolve correctly
- ✅ No broken links
- ✅ Analytics tracks navigation (check console)

**What to Check**:
- [ ] Navigation buttons work
- [ ] Browser back/forward works
- [ ] URLs update correctly
- [ ] No 404 errors

---

## 🐛 Common Issues & Solutions

### **Issue 1: "No Firebase App Created"**
**Symptom**: Console error `[core/no-app]`
**Solution**: Ensure Firebase is initialized in `main.dart`
**Expected**: Should only appear in test mode (ignore if in tests)

### **Issue 2: "Claims Missing"**
**Symptom**: Stats show "0", token refresh triggered
**Solution**: Wait for auto-refresh (happens once)
**Expected**: Should resolve after 1-2 seconds

### **Issue 3: "Probe Chips Show ERROR"**
**Symptom**: Red chips in Admin Review
**Solution**: Check Firestore connection and user permissions
**Expected**: Turn green after successful query

### **Issue 4: "Login Redirect Fails"**
**Symptom**: Stays on login screen after successful auth
**Solution**: Check router configuration
**Expected**: Should redirect to `/` or `/dashboard`

---

## 📊 Success Criteria

### **Minimum Passing**:
- ✅ Login succeeds (no errors)
- ✅ Admin Home loads (stat cards render)
- ✅ Token refresh works (completes in <2s)
- ✅ Admin Review loads (no crashes)

### **Ideal Passing**:
- ✅ All 4 test scenarios pass
- ✅ No console errors
- ✅ All probe chips show green (OK)
- ✅ Navigation smooth throughout
- ✅ Analytics events logged correctly

---

## 🔍 What to Look For

### **Console (DevTools)**:
```
✅ GOOD:
[ℹ️ INFO] Firestore: Web - persistence DISABLED
[ℹ️ INFO] Token refreshed successfully
[AnalyticsRouteObserver] User navigated to: admin_home

❌ BAD:
[❌ ERROR] Token refresh failed
[core/no-app] No Firebase App '[DEFAULT]' has been created
Uncaught TypeError: Cannot read property...
```

### **Network Tab**:
- ✅ Firebase API calls succeed (200 status)
- ✅ No 404 errors for routes
- ✅ Analytics events sent

### **Visual Checks**:
- ✅ No blank screens
- ✅ Loading spinners appear/disappear appropriately
- ✅ Success messages shown
- ✅ UI elements aligned and styled correctly

---

## 📝 Test Results Template

**Date**: ___________
**Tester**: ___________
**Environment**: Web (http://127.0.0.1:7000)
**Browser**: ___________

| Test Scenario | Status | Notes |
|---------------|--------|-------|
| Login Flow | ☐ PASS ☐ FAIL | |
| Admin Home | ☐ PASS ☐ FAIL | |
| Admin Review | ☐ PASS ☐ FAIL | |
| Navigation | ☐ PASS ☐ FAIL | |

**Console Errors**:

**Visual Issues**:

**Performance Notes**:

**Overall Result**: ☐ PASS ☐ FAIL

---

## 🚀 Quick Start

```bash
# 1. Ensure web app is running
# (Should already be running on http://127.0.0.1:7000)

# 2. Open browser
start http://127.0.0.1:7000

# 3. Open DevTools (F12)

# 4. Follow test scenarios above

# 5. Record results
```

---

## ℹ️ Additional Notes

**Test Data**:
- If testing with Firebase emulators, use seed data from `tools/seed_fixtures.dart`
- If testing against production, use staging credentials

**Performance Benchmarks**:
- Login: <2 seconds
- Page load: <3 seconds
- Token refresh: <2 seconds
- Navigation: <1 second

**Known Limitations**:
- Worker Dashboard requires mobile device or GPS emulation (not tested here)
- Some features require specific Firebase setup
- Offline queue not testable in this smoke test

---

**Status**: Ready for manual testing
**Blocker**: None
**Priority**: Optional (all automated tests pass)
