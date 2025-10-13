# Test Credentials for Staging Validation

**Project:** sierra-painting-staging

---

## Option 1: Check Existing Users (Fastest)

### Check Firebase Auth Console

**Navigate to:** https://console.firebase.google.com/project/sierra-painting-staging/authentication/users

**Look for existing users:**
- Any user with email ending in your domain
- Note their UID for role assignment

---

## Option 2: Create Test Users (If Needed)

### Create Worker User

**Via Firebase Console:**
1. Navigate to: https://console.firebase.google.com/project/sierra-painting-staging/authentication/users
2. Click "Add user"
3. Email: `worker@test.com`
4. Password: `Test123!` (or your choice)
5. Click "Add user"
6. **Copy the UID** (you'll need this)

### Create Admin User

**Via Firebase Console:**
1. Click "Add user" again
2. Email: `admin@test.com`
3. Password: `Test123!` (or your choice)
4. Click "Add user"
5. **Copy the UID** (you'll need this)

---

## Option 3: Set Admin Role (Required)

**Once you have a user, elevate them to admin:**

```bash
# Replace <UID> with the admin user's UID from step above
# Replace <COMPANY_ID> with your test company ID (check Firestore → companies collection)

firebase functions:call setUserRole --data '{"uid":"<UID>","role":"admin","companyId":"<COMPANY_ID>"}' --project sierra-painting-staging
```

**Example:**
```bash
firebase functions:call setUserRole --data '{"uid":"abc123xyz","role":"admin","companyId":"company-001"}' --project sierra-painting-staging
```

**Expected Response:**
```json
{
  "success": true,
  "uid": "abc123xyz",
  "role": "admin",
  "companyId": "company-001"
}
```

---

## Option 4: Quick Setup Script (Recommended)

**If you want to automate user creation, I can create a script. Let me know and I'll generate one.**

---

## Test Credentials Summary

**After setup, you'll have:**

### Worker User
- **Email:** `worker@test.com` (or your existing user)
- **Password:** `Test123!` (or what you set)
- **Role:** worker (default)
- **Company:** Assigned via assignment in Firestore

### Admin User
- **Email:** `admin@test.com` (or your existing user)
- **Password:** `Test123!` (or what you set)
- **Role:** admin (set via setUserRole function above)
- **Company:** Set in custom claim

---

## Verification Steps

### 1. Verify Users Exist
```bash
# List all users (if Firebase CLI supports it)
# Or check Console: https://console.firebase.google.com/project/sierra-painting-staging/authentication/users
```

### 2. Verify Admin Role
**Check Firestore Console:**
- Navigate to: https://console.firebase.google.com/project/sierra-painting-staging/firestore/data
- Look for custom claims or role documents

**Or check via token decode in your app:**
```dart
final user = FirebaseAuth.instance.currentUser;
final token = await user?.getIdTokenResult();
print('Role: ${token?.claims?['role']}');
print('Admin: ${token?.claims?['admin']}');
print('CompanyId: ${token?.claims?['companyId']}');
```

### 3. Verify Company & Job Setup

**Check Firestore Console:**
- `/companies/<company-id>` - Verify company exists
- `/jobs/<job-id>` - Verify job exists with geofence (lat, lng, radiusM)
- `/assignments/<assignment-id>` - Verify worker is assigned to job

---

## Quick Company/Job Setup (If Needed)

### Create Test Company

**Firestore Console:**
1. Navigate to: https://console.firebase.google.com/project/sierra-painting-staging/firestore/data
2. Go to `companies` collection
3. Click "Add document"
4. Document ID: `test-company-001` (or auto-generate)
5. Fields:
   ```
   name: "Test Company"
   createdAt: [Timestamp] now
   active: true
   ```

### Create Test Job

**Firestore Console:**
1. Go to `jobs` collection
2. Click "Add document"
3. Document ID: `test-job-001` (or auto-generate)
4. Fields:
   ```
   companyId: "test-company-001"
   name: "Test Job Site"
   address: "123 Test St, San Francisco, CA"
   lat: 37.7793
   lng: -122.4193
   radiusM: 100
   status: "active"
   createdAt: [Timestamp] now
   ```

### Create Test Assignment

**Firestore Console:**
1. Go to `assignments` collection
2. Click "Add document"
3. Document ID: (auto-generate)
4. Fields:
   ```
   companyId: "test-company-001"
   jobId: "test-job-001"
   userId: "<worker-uid>"
   active: true
   role: "worker"
   startDate: [Timestamp] now
   createdAt: [Timestamp] now
   ```

---

## Login Credentials for Tests

**For Tests 1-3 (Worker Path):**
- Email: `worker@test.com`
- Password: `Test123!`
- Expected: Can clock in/out at job site

**For Tests 4-5 (Admin Path):**
- Email: `admin@test.com`
- Password: `Test123!`
- Expected: Can access Exceptions tab, bulk approve, create invoices

---

## Troubleshooting

### "User not found" in Flutter App
- Verify email/password in Firebase Console → Authentication
- Ensure password meets requirements (min 6 characters)

### "Not assigned to this job"
- Check `/assignments` collection has entry linking worker to job
- Verify `active: true` on assignment
- Verify `companyId` matches on all documents

### "Permission denied" on Admin Operations
- Verify admin role set via `setUserRole` function
- Force token refresh in app:
  ```dart
  await FirebaseAuth.instance.currentUser?.getIdToken(true);
  ```

### "Not inside geofence"
- Use test coordinates: lat: 37.7793, lng: -122.4193
- Or set job `radiusM` to 250 for wider fence
- Ensure device GPS accuracy < 50m

---

## Quick Start Command Sequence

```bash
# 1. Check existing users
echo "Check Firebase Console → Authentication → Users"
echo "https://console.firebase.google.com/project/sierra-painting-staging/authentication/users"

# 2. If you have a user UID, make them admin
firebase functions:call setUserRole --data '{"uid":"<WORKER_UID>","role":"worker","companyId":"<COMPANY_ID>"}' --project sierra-painting-staging

firebase functions:call setUserRole --data '{"uid":"<ADMIN_UID>","role":"admin","companyId":"<COMPANY_ID>"}' --project sierra-painting-staging

# 3. Verify in Firestore that company, job, and assignment exist
echo "Check Firestore Console:"
echo "https://console.firebase.google.com/project/sierra-painting-staging/firestore/data"
```

---

## What You Need to Provide

**Tell me:**
1. Do you have existing users in Firebase Auth? (YES/NO)
2. If NO, should I create a setup script to automate user/company/job creation?
3. What company ID should I use for test data?

**Once you confirm, I can help set up the exact credentials you need.**

---

**Next Step:** Check Firebase Auth Console and let me know what you find. I'll help you set up the credentials quickly.
