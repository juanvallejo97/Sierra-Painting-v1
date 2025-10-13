# Test User Setup - Quick Start

**Admin UID:** `yqLJSx5NH1YHKa9WxIOhCrqJcPp1`
**Worker UID:** `d5POlAllCoacEAN5uajhJfzcIJu2`

---

## Step 1: Check Existing Company (1 minute)

**Firestore Console:** https://console.firebase.google.com/project/sierra-painting-staging/firestore/data/~2Fcompanies

**Do you see any companies listed?**

- **If YES:** Note the company ID (document ID), use it in Step 2
- **If NO:** We'll create one in Step 2

---

## Step 2: Create Test Company (If Needed)

**If no company exists, create one in Firestore Console:**

1. Navigate to: https://console.firebase.google.com/project/sierra-painting-staging/firestore/data
2. Click on `companies` collection (or create it)
3. Click "Add document"
4. **Document ID:** `test-company-staging` (use this ID)
5. **Fields:**
   ```
   name: "Test Company - Staging"
   createdAt: [Click "timestamp" → "now"]
   active: true
   ```
6. Click "Save"

**Company ID to use:** `test-company-staging`

---

## Step 3: Set Admin Role

**Run this command with your company ID:**

```bash
firebase functions:call setUserRole --data '{"uid":"yqLJSx5NH1YHKa9WxIOhCrqJcPp1","role":"admin","companyId":"test-company-staging"}' --project sierra-painting-staging
```

**Expected Response:**
```json
{
  "success": true,
  "uid": "yqLJSx5NH1YHKa9WxIOhCrqJcPp1",
  "role": "admin",
  "companyId": "test-company-staging"
}
```

---

## Step 4: Set Worker Role

```bash
firebase functions:call setUserRole --data '{"uid":"d5POlAllCoacEAN5uajhJfzcIJu2","role":"worker","companyId":"test-company-staging"}' --project sierra-painting-staging
```

**Expected Response:**
```json
{
  "success": true,
  "uid": "d5POlAllCoacEAN5uajhJfzcIJu2",
  "role": "worker",
  "companyId": "test-company-staging"
}
```

---

## Step 5: Create Test Job with Geofence

**Firestore Console:** https://console.firebase.google.com/project/sierra-painting-staging/firestore/data

1. Navigate to `jobs` collection (or create it)
2. Click "Add document"
3. **Document ID:** `test-job-staging` (use this ID)
4. **Fields:**
   ```
   companyId: "test-company-staging"
   name: "Test Job - SF"
   address: "Painted Ladies, San Francisco, CA"
   lat: 37.7793
   lng: -122.4193
   radiusM: 150
   status: "active"
   createdAt: [timestamp → now]
   ```
5. Click "Save"

**Job ID to use:** `test-job-staging`

---

## Step 6: Create Assignment (Link Worker to Job)

**Firestore Console:** https://console.firebase.google.com/project/sierra-painting-staging/firestore/data

1. Navigate to `assignments` collection (or create it)
2. Click "Add document"
3. **Document ID:** (auto-generate)
4. **Fields:**
   ```
   companyId: "test-company-staging"
   jobId: "test-job-staging"
   userId: "d5POlAllCoacEAN5uajhJfzcIJu2"
   active: true
   role: "worker"
   startDate: [timestamp → now]
   createdAt: [timestamp → now]
   ```
5. Click "Save"

---

## Step 7: Verification Checklist

**Before running smoke tests, verify in Firestore Console:**

- [ ] `/companies/test-company-staging` exists
- [ ] `/jobs/test-job-staging` exists with lat: 37.7793, lng: -122.4193, radiusM: 150
- [ ] `/assignments/<id>` exists linking worker UID to job
- [ ] Admin role set (verify by checking Auth token claims or testing admin UI access)

---

## Step 8: Ready to Test

**Your test credentials:**

### Worker Tests (Tests 1-3):
- **Login:** (your worker account email/password)
- **UID:** `d5POlAllCoacEAN5uajhJfzcIJu2`
- **Company:** `test-company-staging`
- **Assigned Job:** `test-job-staging`
- **Geofence:** lat: 37.7793, lng: -122.4193, radius: 150m

### Admin Tests (Tests 4-5):
- **Login:** (your admin account email/password)
- **UID:** `yqLJSx5NH1YHKa9WxIOhCrqJcPp1`
- **Company:** `test-company-staging`
- **Role:** admin

---

## Quick Commands Summary

```bash
# Set admin role
firebase functions:call setUserRole --data '{"uid":"yqLJSx5NH1YHKa9WxIOhCrqJcPp1","role":"admin","companyId":"test-company-staging"}' --project sierra-painting-staging

# Set worker role
firebase functions:call setUserRole --data '{"uid":"d5POlAllCoacEAN5uajhJfzcIJu2","role":"worker","companyId":"test-company-staging"}' --project sierra-painting-staging

# Test auto-clockout (Test 6)
firebase functions:call adminAutoClockOutOnce --data '{"dryRun":true}' --project sierra-painting-staging
```

---

## Next Step

**Tell me:**
1. Do you have an existing company in Firestore? (Check the link above)
2. If YES: What's the company ID?
3. If NO: I'll help you create the test company

**Once you confirm, run the role setup commands and proceed with validation tests.**
