# Firestore Setup for Testing

## Quick Setup (All-in-One)

### Option A: Run Setup Script (Recommended)

This will create all required Firestore documents and set custom claims:

```bash
# Authenticate (if not already)
gcloud auth application-default login

# Run setup script
node setup_test_data.cjs
```

**Creates:**
- ✅ User documents (`/users/{uid}` with companyId)
- ✅ Job document (`/jobs/test-job-staging` with geofence)
- ✅ Assignment (`/assignments/{id}` linking worker to job)
- ✅ Company document (`/companies/test-company-staging`)
- ✅ Custom claims for both users

**After running:**
- Sign out worker@test.com if logged in
- Sign back in (to get new claims)
- Test Clock In

---

### Option B: Manual Setup in Firebase Console

If you prefer to create documents manually:

#### 1. Firestore Database → users collection

**Document ID:** `d5POlAllCoacEAN5uajhJfzcIJu2`
```json
{
  "companyId": "test-company-staging",
  "email": "worker@test.com",
  "role": "worker",
  "displayName": "Test Worker",
  "active": true,
  "createdAt": <serverTimestamp>
}
```

**Document ID:** `yqLJSx5NH1YHKa9WxIOhCrqJcPp1`
```json
{
  "companyId": "test-company-staging",
  "email": "admin@test.com",
  "role": "admin",
  "displayName": "Test Admin",
  "active": true,
  "createdAt": <serverTimestamp>
}
```

---

#### 2. Firestore Database → jobs collection

**Document ID:** `test-job-staging`
```json
{
  "id": "test-job-staging",
  "companyId": "test-company-staging",
  "name": "SF Painted Ladies",
  "address": "710 Steiner St, San Francisco, CA 94117",
  "active": true,
  "geofence": {
    "latitude": 37.7793,
    "longitude": -122.4193,
    "radiusMeters": 150
  },
  "createdAt": <serverTimestamp>
}
```

---

#### 3. Firestore Database → assignments collection

**Document ID:** `d5POlAllCoacEAN5uajhJfzcIJu2_test-job-staging`
```json
{
  "id": "d5POlAllCoacEAN5uajhJfzcIJu2_test-job-staging",
  "companyId": "test-company-staging",
  "userId": "d5POlAllCoacEAN5uajhJfzcIJu2",
  "jobId": "test-job-staging",
  "active": true,
  "assignedAt": <serverTimestamp>
}
```

---

#### 4. Set Custom Claims (Firebase Functions or gcloud)

**Using Firebase Functions Emulator:**
```bash
firebase functions:shell --project sierra-painting-staging

# In the shell:
setUserRole({uid: 'd5POlAllCoacEAN5uajhJfzcIJu2', role: 'worker', companyId: 'test-company-staging'})
setUserRole({uid: 'yqLJSx5NH1YHKa9WxIOhCrqJcPp1', role: 'admin', companyId: 'test-company-staging'})
```

**Using gcloud:**
```bash
# Set worker claims
gcloud auth print-identity-token | \
  curl -X POST "https://us-east4-sierra-painting-staging.cloudfunctions.net/setUserRole" \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{"uid":"d5POlAllCoacEAN5uajhJfzcIJu2","role":"worker","companyId":"test-company-staging"}'
```

---

## Verify Setup

### Check in Firebase Console:

1. **Firestore Database:**
   - `/users/d5POlAllCoacEAN5uajhJfzcIJu2` - Should have `companyId` field
   - `/jobs/test-job-staging` - Should exist with `geofence` object
   - `/assignments` - Should have active assignment for worker

2. **Authentication:**
   - Click on worker@test.com
   - Scroll to "Custom claims" section
   - Should show: `{"role":"worker","companyId":"test-company-staging"}`

### Test with Script:

```bash
# Run verification (coming soon)
node verify_firestore_setup.cjs
```

---

## Troubleshooting

### "Application Default Credentials not found"

Run:
```bash
gcloud auth application-default login
```

### "Permission denied" when running scripts

Ensure you're authenticated:
```bash
gcloud auth login
gcloud config set project sierra-painting-staging
gcloud auth application-default login
```

### Custom claims not appearing

1. Check if claims were set:
   ```bash
   firebase auth:export users.json --project sierra-painting-staging
   # Check customClaims field in exported JSON
   ```

2. Force refresh by:
   - Sign out of the web app
   - Sign back in
   - Claims are in the JWT token now

### "No active job assigned" error

Check:
```
/assignments collection → Filter by userId: d5POlAllCoacEAN5uajhJfzcIJu2
Should have at least 1 doc with active: true
```

---

## Quick Test After Setup

1. Open http://localhost:9030 (incognito)
2. Login as worker@test.com
3. Allow location permission
4. Mock location (DevTools → Sensors):
   - Latitude: 37.7793
   - Longitude: -122.4193
5. Click "Clock In"
6. **Expected:** Green toast "✓ Clocked in successfully (ID: xxx)"

---

## What Each Document Does

**users/{uid}:**
- Provides `companyId` to providers (replaces token fetch)
- Used for role-based UI routing
- Syncs with custom claims

**jobs/{jobId}:**
- Contains geofence for location validation
- Job name for UI display
- Company isolation via `companyId`

**assignments/{id}:**
- Links worker to job
- `activeJobProvider` queries this to find worker's current job
- Must have `active: true` for worker to clock in

**Custom Claims:**
- Used for Firebase Auth role checks
- Used by Cloud Functions for authorization
- Cached in JWT token (requires re-login to refresh)

---

## Next Step

**Run the setup:**
```bash
node setup_test_data.cjs
```

**Then test Clock In:**
```bash
# Open in incognito
start http://localhost:9030

# Or just navigate there manually
```
