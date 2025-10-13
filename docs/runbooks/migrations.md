# Schema Migrations Guide

## Overview

This guide covers migrating from legacy schemas (v1.x) to canonical schemas (v2.0) introduced in Option B Stability Patch.

## Migration Timeline

- **Start Date**: 2025-10-12
- **Legacy Support Window**: 2 weeks
- **Legacy Removal Date**: 2025-10-26
- **Status**: Legacy fallbacks active in all code

## What Changed

### Job Schema (BUG #1 Fix)

**Before (v1.x - BROKEN)**:
```json
{
  "jobId": "job123",
  "lat": 37.7793,
  "lng": -122.4193,
  "radiusM": 150
}
```

**After (v2.0 - CANONICAL)**:
```json
{
  "jobId": "job123",
  "geofence": {
    "lat": 37.7793,
    "lng": -122.4193,
    "radiusM": 150
  }
}
```

**Why**: Nested structure prevents NaN distance bugs and improves clarity.

### TimeEntry Schema (BUG #2 Fix)

**Before (v1.x - INCONSISTENT)**:
```json
{
  "entryId": "entry123",
  "workerId": "user456",  // Inconsistent naming
  "clockIn": Timestamp,   // Inconsistent naming
  "clockOut": Timestamp,
  "location": GeoPoint,   // Ambiguous (in or out?)
  "geofenceValid": true   // Ambiguous (in or out?)
}
```

**After (v2.0 - CANONICAL)**:
```json
{
  "entryId": "entry123",
  "userId": "user456",                   // Consistent naming
  "clockInAt": Timestamp,                // Clear intent
  "clockInGeofenceValid": true,          // Explicit
  "clockInLocation": {lat, lng},         // Explicit
  "clockOutAt": Timestamp,               // Clear intent
  "clockOutGeofenceValid": false,        // Explicit
  "clockOutLocation": {lat, lng},        // Explicit
  "notes": "Finished painting"
}
```

**Why**: Explicit field names prevent ambiguity and enable proper security rules.

### User Schema (BUG #3 Fix)

**Before (v1.x - INSECURE)**:
```json
// Firestore /users/{uid}
{
  "userId": "user456",
  "role": "admin",           // ❌ Client can tamper
  "companyId": "company123", // ❌ Client can tamper
  "displayName": "John Doe"
}
```

**After (v2.0 - SECURE)**:
```json
// Firestore /users/{uid} (safe fields only)
{
  "userId": "user456",
  "displayName": "John Doe",
  "email": "john@example.com",
  "photoURL": "https://...",
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}

// Firebase Auth Custom Claims (trusted, server-only)
{
  "companyId": "company123",
  "role": "admin",
  "active": true
}
```

**Why**: Moving sensitive fields to JWT custom claims prevents client tampering.

## Migration Scripts

### 1. Backup Existing Data

```bash
# Backup entire Firestore database
gcloud firestore export gs://your-bucket/backups/$(date +%Y%m%d)

# Verify backup
gsutil ls gs://your-bucket/backups/
```

### 2. Run Migration Script

```bash
# Dry run (preview changes)
node tools/migrate_v1_to_v2.cjs --dry-run

# Review output, then run actual migration
node tools/migrate_v1_to_v2.cjs

# Migration summary will show:
# - Jobs migrated: N
# - TimeEntries migrated: N
# - Users migrated: N (Firestore only, claims separate)
```

### 3. Set Custom Claims for Users

```bash
# Set custom claims for all active users
node set_roles.js

# Or use PowerShell version on Windows
pwsh ./set_roles_powershell.ps1
```

### 4. Deploy Firestore Rules

```bash
# Deploy updated rules with immutability guarantees
firebase deploy --only firestore:rules

# Deploy updated indexes
firebase deploy --only firestore:indexes
```

### 5. Deploy Cloud Functions

```bash
# Build functions with canonical schema support
npm --prefix functions run build

# Deploy functions (includes legacy fallbacks)
firebase deploy --only functions
```

## Verification

### Check Job Migration

```bash
# Verify nested geofence structure
firebase firestore:get jobs/job_painted_ladies

# Expected output:
{
  "jobId": "job_painted_ladies",
  "geofence": {
    "lat": 37.7793,
    "lng": -122.4193,
    "radiusM": 150
  }
}
```

### Check TimeEntry Migration

```bash
# Verify canonical field names
firebase firestore:get time_entries/{entryId}

# Expected output:
{
  "entryId": "entry123",
  "userId": "user456",           // Not "workerId"
  "clockInAt": Timestamp,        // Not "clockIn"
  "clockInGeofenceValid": true,  // Not "geofenceValid"
  "clockInLocation": {lat, lng}  // Not GeoPoint "location"
}
```

### Check Custom Claims

```bash
# Verify user claims (use Firebase Auth Admin SDK)
firebase auth:get {uid}

# Check customClaims field:
{
  "customClaims": {
    "companyId": "company123",
    "role": "worker",
    "active": true
  }
}
```

## Rollback Plan

If migration causes issues:

### 1. Revert Cloud Functions

```bash
# Rollback to previous deployment
gcloud functions deploy clockIn \
  --region=us-east4 \
  --source=./functions-backup \
  --trigger-http

gcloud functions deploy clockOut \
  --region=us-east4 \
  --source=./functions-backup \
  --trigger-http
```

### 2. Restore Firestore Data

```bash
# Restore from backup
gcloud firestore import gs://your-bucket/backups/20251012
```

### 3. Revert Firestore Rules

```bash
# Restore previous rules
cp firestore.rules.backup firestore.rules
firebase deploy --only firestore:rules
```

## Testing Migration

### Pre-Migration Test

```bash
# Test with legacy data (should work with fallbacks)
flutter test integration_test/clock_in_e2e_test.dart
```

### Post-Migration Test

```bash
# Test with canonical data
npm --prefix functions run test
flutter test --concurrency=1
```

## Common Issues

### Issue: "Job geofence is NaN"

**Cause**: Job document missing nested geofence structure

**Fix**:
```bash
# Re-run migration for specific job
node tools/migrate_v1_to_v2.cjs --job-id=job123
```

### Issue: "User claim mismatch"

**Cause**: Custom claims not set or outdated

**Fix**:
```bash
# Reset claims for specific user
node set_roles.js --uid=user456 --role=worker --company=company123
```

### Issue: "Firestore rules blocking writes"

**Cause**: Rules expect canonical schema, but data is legacy

**Fix**: Ensure migration script completed successfully before deploying rules

## Legacy Support Window

### Current Status (2025-10-12 to 2025-10-26)

- ✅ All code has legacy fallbacks
- ✅ normalizeJob() handles both formats
- ✅ normalizeTimeEntry() handles both formats
- ✅ Flutter models parse both formats

### After 2025-10-26

- ❌ Remove legacy fallbacks
- ❌ Remove migration scripts
- ❌ Update documentation to show only v2.0 schemas

## Migration Checklist

- [ ] Backup Firestore database
- [ ] Run migration script (dry-run)
- [ ] Review migration output
- [ ] Run migration script (actual)
- [ ] Set custom claims for all users
- [ ] Deploy Firestore rules
- [ ] Deploy Firestore indexes
- [ ] Deploy Cloud Functions
- [ ] Verify job migration
- [ ] Verify time entry migration
- [ ] Verify custom claims
- [ ] Run integration tests
- [ ] Monitor error logs for 24 hours
- [ ] Remove legacy fallbacks (after 2025-10-26)

## Contact

- **Migration Issues**: Create GitHub issue with label `migration`
- **Data Integrity Issues**: Escalate to CTO immediately
- **Questions**: Check #backend channel on Slack

## See Also

- [Canonical Schemas](../schemas/)
- [Timeclock Runbook](./timeclock.md)
- [Migration Script](../../tools/migrate_v1_to_v2.cjs)
