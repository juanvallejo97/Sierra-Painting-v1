# Clock In/Out Flow - WIRED & READY ✅

**Status:** Complete - Ready for Validation
**URL:** http://localhost:9002
**Date:** 2025-10-12

---

## ✅ **What's Been Implemented**

### **1. Core Clock In Flow**
```
Worker taps "Clock In" →
  1. Get GPS location (LocationService)
  2. Auto-select active job from assignments
  3. Generate clientEventId (idempotency)
  4. Call Firebase clockIn function
  5. Refresh active entry provider
  6. Show success toast with entry ID
```

### **2. Core Clock Out Flow**
```
Worker taps "Clock Out" →
  1. Get GPS location (LocationService)
  2. Get active time entry
  3. Generate clientEventId (idempotency)
  4. Call Firebase clockOut function
  5. Refresh active entry provider
  6. Show success/warning toast
```

### **3. Providers Created**
- `activeJobProvider` - Auto-selects worker's active job
- `activeEntryProvider` - Gets current clocked-in entry
- Both use custom claims for companyId (no extra Firestore reads)

### **4. Error Handling**
- GPS accuracy validation
- Geofence violations → user-friendly messages
- No job assigned → clear error
- Already clocked in → prevents duplicates
- Network errors → generic fallback

---

## 📋 **Validation Tests - Ready to Execute**

### **Test 1: Clock In (Inside Geofence)** ⏸️
1. Open http://localhost:9002
2. Login as WORKER (UID: d5POlAllCoacEAN5uajhJfzcIJu2)
3. **Allow location when prompted**
4. Tap "Clock In" button
5. **Expected:**
   - Success toast with entry ID
   - Status changes to "Currently Working"
   - Button changes to orange "Clock Out"
6. **Capture:** Entry ID from toast

---

### **Test 2: Idempotency** ⏸️
1. While still clocked in, tap "Clock In" again
2. **Expected:**
   - Same entry ID returned
   - Toast: "Already clocked in" OR same ID
   - No duplicate entry created
3. **Verify in Firestore:** Only 1 entry for this user

---

### **Test 3: Clock Out (Outside Geofence)** ⏸️
1. **Mock location to outside geofence:**
   - Browser DevTools → Sensors → Geolocation
   - Set to: lat 37.800, lng -122.500 (outside job fence)
2. Tap "Clock Out"
3. **Expected:**
   - Orange warning toast with distance info
   - Successfully clocked out
   - Entry flagged for review
4. **Verify in Firestore Console:**
   - Navigate to `/timeEntries/<entry-id>`
   - Check: `exceptionTags: ["geofence_out"]`

---

### **Test 4: Bulk Approve** ⏸️
1. Logout, login as ADMIN (UID: yqLJSx5NH1YHKa9WxIOhCrqJcPp1)
2. Navigate to Exceptions tab (if available)
3. Select geofence exception entry
4. Tap "Approve"
5. **Expected:**
   - Success toast
   - Entry removed from exceptions list
   - Badge count decreases
6. **Verify in Firestore:**
   - Entry has: `approved: true`, `approvedBy: admin-uid`
   - Audit log entry created

---

### **Test 5: Create Invoice from Time** ⏸️
1. Still logged in as admin
2. Select approved time entry
3. Tap "Create Invoice"
4. Enter rate: $50/hour
5. **Expected:**
   - Invoice created with calculated amount
   - Time entry locked with invoiceId
6. **Verify in Firestore:**
   - `/invoices/<id>` exists with correct amount
   - `/timeEntries/<id>` has `invoiceId` field

---

### **Test 6: Auto-Clockout (CLI)** ✅ ALREADY DONE
```bash
# Result from earlier:
{
  "processed": 0,
  "entries": [],
  "dryRun": true
}
```

---

## 🔧 **Implementation Notes**

### **Files Modified:**
1. `lib/features/timeclock/presentation/worker_dashboard_screen.dart`
   - Wired _handleClockIn() with real API calls
   - Wired _handleClockOut() with real API calls
   - Added imports for services/providers

2. `lib/features/timeclock/presentation/providers/timeclock_providers.dart`
   - Added activeJobProvider (auto-select)
   - Added activeEntryProvider (current clock-in)
   - Uses custom claims for companyId

3. `lib/core/providers/auth_provider.dart`
   - Added userRoleProvider
   - Added userCompanyProvider

### **Services Used:**
- `LocationServiceImpl` - GPS location
- `TimeclockApiImpl` - Firebase function calls
- `Idempotency` - clientEventId generation

### **Known Limitations (OK for validation):**
- Location permission primer not implemented (browser handles)
- No location accuracy warning UI
- Job selection UI missing (auto-selects single job)
- Device ID is mock for web (timestamp-based)

---

## 🎯 **Next Steps**

1. **Execute Tests 1-5** via Flutter app
2. **Capture artifacts:**
   - Entry IDs
   - Toast screenshots
   - Firestore verification screenshots
3. **Post results** using template from VALIDATION_READY.md
4. **If GREEN → Stamp STAGING: GO** 🚀

---

## 📊 **Validation Results Template**

```
## VALIDATION RESULTS

Smoke Tests:
1. Clock In: PASS/FAIL – ___ ms (Entry ID: ___)
2. Idempotency: PASS/FAIL – Same ID: YES/NO
3. Clock Out: PASS/FAIL – exceptionTags present: YES/NO, distance: ___ m
4. Bulk Approve: PASS/FAIL – Audit OK: YES/NO
5. Create Invoice: PASS/FAIL – Amount: $___, Locked: YES/NO
6. Auto-Clockout: ✅ PASS – processed: 0, dryRun: true

Proof Logs (firebase functions:log --project sierra-painting-staging):
[Paste 3 key log lines]

p95 Metrics (Firebase Console → Functions → Usage):
- clockIn: ___ ms
- clockOut: ___ ms
- Cold starts: 0 (YES/NO)

Indexes (Firebase Console → Firestore → Indexes): ACTIVE (YES/NO)

Issues: NONE / [describe]
```

---

## ⚡ **Current Status**

- ✅ Role-based routing working
- ✅ Worker dashboard displays correctly
- ✅ Clock In/Out buttons wired to Firebase
- ✅ Test data created (company, job, assignment)
- ✅ User roles set (admin & worker)
- ✅ App served at http://localhost:9002

**READY FOR VALIDATION TESTS 1-5** 🎯

Execute tests and post results to proceed to STAGING: GO!
