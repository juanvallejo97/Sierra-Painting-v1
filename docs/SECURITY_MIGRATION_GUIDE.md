# Security Migration Guide

**Purpose**: Step-by-step guide to implement the security improvements from the 2025-10-09 security audit.

**Timeline**: Complete within 1 week of audit completion

---

## Overview

This guide helps you migrate from Firestore-based role checks to custom claims-based authorization, improving both security and performance.

### Benefits of Migration

- ✅ **Performance**: No Firestore reads in security rules (saves quota + faster)
- ✅ **Security**: Cryptographically verified via Firebase Auth tokens
- ✅ **Simplicity**: Single source of truth for user roles
- ✅ **Cost**: Reduces Firestore read operations significantly

---

## Pre-Migration Checklist

Before starting, ensure you have:

- [ ] Backed up production Firestore database
- [ ] Reviewed current user roles in `users` collection
- [ ] Scheduled maintenance window (optional, no downtime required)
- [ ] Notified team of pending changes
- [ ] Staged changes in development environment first

---

## Step 1: Rotate Compromised Credentials

**Priority**: IMMEDIATE (do this first)

### Firebase API Key

```bash
# 1. Go to Firebase Console
# https://console.firebase.google.com/project/YOUR_PROJECT/settings/general

# 2. Click "Add app" or select existing web app
# 3. Regenerate API key (or create new app)
# 4. Update .env file with new key
# 5. Delete old API key restriction (keep it monitored for 24h)
```

### Firebase Deployment Token

```bash
# 1. Generate new token
firebase login:ci

# 2. Copy token (starts with "1//...")
# 3. Update GitHub Secrets
# Go to: Settings → Secrets and variables → Actions
# Update: FIREBASE_TOKEN

# 4. Test deployment
firebase deploy --only hosting --project YOUR_PROJECT --token YOUR_NEW_TOKEN
```

### OpenAI API Key

```bash
# 1. Go to https://platform.openai.com/api-keys
# 2. "Create new secret key"
# 3. Copy key immediately (won't be shown again)
# 4. Update GCP Secret Manager:

gcloud secrets versions add openai-api-key --data-file=- <<< "your-new-key"

# 5. Verify
gcloud secrets versions access latest --secret="openai-api-key"

# 6. Delete old key from OpenAI platform
```

### Verify Rotation

```bash
# Check audit logs for suspicious activity
firebase auth:export users.json --project YOUR_PROJECT
# Review recent sign-ins and anomalies

# Check Cloud Functions logs
gcloud logging read "resource.type=cloud_function" --limit 100 --project YOUR_PROJECT
```

---

## Step 2: Deploy Custom Claims Infrastructure

### 2.1 Build and Deploy Cloud Function

```bash
# Navigate to functions directory
cd functions

# Install dependencies
npm install

# Build TypeScript
npm run build

# Deploy setUserRole function
firebase deploy --only functions:setUserRole --project YOUR_PROJECT
```

### 2.2 Bootstrap First Admin

```bash
# Open Firebase Functions shell
firebase functions:shell --project YOUR_PROJECT

# Run bootstrap function
const { bootstrapFirstAdmin } = require('./lib/auth/setUserRole');
await bootstrapFirstAdmin(
  'your-admin@company.com',
  'temporary-secure-password',
  'your-company-id'
);

# Output should show:
# ✅ Admin user created successfully: your-admin@company.com
#    UID: abc123...
#    Company ID: your-company-id
```

**Important**: Change the temporary password immediately after first login!

### 2.3 Verify Custom Claims

```typescript
// In your app or Firebase console
const user = firebase.auth().currentUser;
const idTokenResult = await user.getIdTokenResult();
console.log(idTokenResult.claims);
// Should show: { role: 'admin', companyId: 'your-company-id', ... }
```

---

## Step 3: Migrate Existing Users

### 3.1 Export Current User Roles

```bash
# Export users from Firestore
firebase firestore:export gs://YOUR_BUCKET/firestore-backup --project YOUR_PROJECT

# Or query programmatically
```

```typescript
// migration-script.ts
import * as admin from 'firebase-admin';

admin.initializeApp();

async function exportUserRoles() {
  const usersSnapshot = await admin.firestore()
    .collection('users')
    .get();

  const users = usersSnapshot.docs.map(doc => ({
    uid: doc.id,
    ...doc.data()
  }));

  console.log(JSON.stringify(users, null, 2));
}

exportUserRoles();
```

### 3.2 Batch Set Custom Claims

```typescript
// migration-script.ts continued
async function migrateUserRoles() {
  const db = admin.firestore();
  const usersSnapshot = await db.collection('users').get();

  let processed = 0;
  let errors = 0;

  for (const doc of usersSnapshot.docs) {
    const userData = doc.data();
    const uid = doc.id;
    const role = userData.role || 'crew'; // Default to crew if missing
    const companyId = userData.companyId;

    if (!companyId) {
      console.warn(`⚠️  User ${uid} missing companyId, skipping...`);
      errors++;
      continue;
    }

    try {
      // Set custom claims
      await admin.auth().setCustomUserClaims(uid, {
        role,
        companyId,
        updatedAt: Date.now(),
      });

      console.log(`✅ Migrated ${uid}: role=${role}, companyId=${companyId}`);
      processed++;

      // Rate limit: 1 QPS for setCustomUserClaims
      await new Promise(resolve => setTimeout(resolve, 1000));
    } catch (error) {
      console.error(`❌ Failed to migrate ${uid}:`, error);
      errors++;
    }
  }

  console.log(`\n📊 Migration Summary:`);
  console.log(`   Processed: ${processed}`);
  console.log(`   Errors: ${errors}`);
  console.log(`   Total: ${usersSnapshot.docs.length}`);
}

migrateUserRoles();
```

### 3.3 Run Migration Script

```bash
# Compile TypeScript
npx tsc migration-script.ts

# Run with service account
GOOGLE_APPLICATION_CREDENTIALS=./service-account.json node migration-script.js

# Monitor output for errors
```

### 3.4 Verify Migration

```typescript
// verify-migration.ts
async function verifyMigration() {
  const db = admin.firestore();
  const auth = admin.auth();

  const usersSnapshot = await db.collection('users').get();
  let verified = 0;
  let failed = 0;

  for (const doc of usersSnapshot.docs) {
    const uid = doc.id;
    const firestoreRole = doc.data().role;

    try {
      const user = await auth.getUser(uid);
      const customClaims = user.customClaims || {};
      const claimsRole = customClaims.role;

      if (firestoreRole === claimsRole) {
        verified++;
      } else {
        console.error(`❌ Mismatch for ${uid}: Firestore=${firestoreRole}, Claims=${claimsRole}`);
        failed++;
      }
    } catch (error) {
      console.error(`❌ Error checking ${uid}:`, error);
      failed++;
    }
  }

  console.log(`\n✅ Verification: ${verified} matched, ${failed} failed`);
}

verifyMigration();
```

---

## Step 4: Deploy Updated Security Rules

### 4.1 Test Rules Locally

```bash
# Start emulators
firebase emulators:start

# In another terminal, run rules tests
cd firestore-tests
npm test
```

### 4.2 Deploy Firestore Rules

```bash
# Deploy to staging first
firebase deploy --only firestore:rules --project sierra-painting-staging

# Test in staging environment
# Run integration tests, verify role checks work

# Deploy to production
firebase deploy --only firestore:rules --project sierra-painting-prod
```

### 4.3 Deploy Storage Rules

```bash
# Deploy to staging first
firebase deploy --only storage:rules --project sierra-painting-staging

# Test file uploads with different roles

# Deploy to production
firebase deploy --only storage:rules --project sierra-painting-prod
```

---

## Step 5: Update Client Code

### 5.1 Force Token Refresh

After migration, clients need to refresh their ID tokens to get custom claims:

```dart
// Add to app initialization or user role update handler
Future<void> refreshUserToken() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await user.getIdToken(true); // Force refresh
    print('✅ Token refreshed with custom claims');
  }
}
```

### 5.2 Add Role Change Listener

```dart
// lib/features/auth/logic/auth_controller.dart
class AuthController extends StateNotifier<AuthState> {
  // Listen for custom claims changes
  Future<void> listenForRoleChanges() async {
    FirebaseAuth.instance.idTokenChanges().listen((user) async {
      if (user != null) {
        final idToken = await user.getIdTokenResult();
        final role = idToken.claims?['role'] as String?;
        final companyId = idToken.claims?['companyId'] as String?;

        print('🔐 User role: $role, Company: $companyId');

        // Update app state based on role
        state = state.copyWith(
          role: role,
          companyId: companyId,
        );
      }
    });
  }
}
```

### 5.3 Update Role Management UI

```dart
// Admin panel - Set user role
Future<void> setUserRole(String uid, String role) async {
  final setRoleFunction = FirebaseFunctions.instance
      .httpsCallable('setUserRole');

  try {
    final result = await setRoleFunction.call({
      'uid': uid,
      'role': role,
      'companyId': currentUser.companyId,
    });

    print('✅ Role set: ${result.data}');

    // Force target user to refresh token on next request
    // (They'll get new claims automatically)
  } catch (e) {
    print('❌ Failed to set role: $e');
    rethrow;
  }
}
```

---

## Step 6: Monitor and Validate

### 6.1 Monitor Firestore Usage

```bash
# Check Firestore read operations dropped
# Firebase Console → Firestore → Usage

# Before migration: High read count from rules
# After migration: Minimal read count (no admin checks)
```

### 6.2 Monitor Security Events

```typescript
// Query audit log for role changes
const auditLogs = await firestore()
  .collection('auditLog')
  .where('action', '==', 'setUserRole')
  .where('timestamp', '>', last24Hours)
  .orderBy('timestamp', 'desc')
  .get();

console.log(`📊 Role changes in last 24h: ${auditLogs.size}`);
```

### 6.3 Test Critical Flows

Manually test with different roles:

- [ ] **Admin**: Full access to all features
- [ ] **Manager**: Can manage jobs, cannot access admin panel
- [ ] **Staff**: Can create estimates, cannot manage jobs
- [ ] **Crew**: Can view jobs, upload photos, clock in/out

### 6.4 Verify Storage Rules

```bash
# Upload job photo as crew member assigned to job
# Expected: Success

# Upload job photo as crew member NOT assigned
# Expected: Permission denied

# Upload job photo as admin
# Expected: Success (admins can upload to any job)
```

---

## Step 7: Cleanup (Optional)

### 7.1 Remove Legacy Code

After verification period (1-2 weeks), remove Firestore-based role checks:

```typescript
// Remove isAdminLegacy() from storage.rules
// Remove any client code using Firestore role lookups
```

### 7.2 Add Monitoring Alerts

```bash
# Set up Cloud Monitoring alert for security events
gcloud alpha monitoring policies create \
  --notification-channels=YOUR_CHANNEL \
  --display-name="Security: High Failed Auth Rate" \
  --condition-display-name="Failed auth > 10/min" \
  --condition-threshold-value=10 \
  --condition-threshold-duration=60s
```

---

## Rollback Plan

If issues arise during migration:

### Rollback Step 1: Revert Security Rules

```bash
# Revert Firestore rules
git checkout HEAD~1 firestore.rules
firebase deploy --only firestore:rules --project YOUR_PROJECT

# Revert Storage rules
git checkout HEAD~1 storage.rules
firebase deploy --only storage:rules --project YOUR_PROJECT
```

### Rollback Step 2: Continue Using Legacy Mode

The new code maintains backward compatibility:
- Firestore `users` collection still has `role` field
- Legacy `isAdminLegacy()` function available in rules
- Custom claims are additive (don't break existing logic)

**No data loss** - custom claims can remain set without causing issues.

---

## Troubleshooting

### Issue: Users Can't Access Resources After Migration

**Cause**: Client hasn't refreshed ID token yet.

**Fix**:
```dart
// Force token refresh
await FirebaseAuth.instance.currentUser?.getIdToken(true);
```

### Issue: Custom Claims Not Set

**Cause**: Migration script failed or user created after migration.

**Fix**:
```bash
# Set claims manually via setUserRole function
# Or re-run migration script for specific users
```

### Issue: Storage Rules Failing

**Cause**: Job document missing `assignedCrew` field.

**Fix**:
```typescript
// Update job documents to include assignedCrew array
await firestore()
  .collection('jobs')
  .doc(jobId)
  .update({
    assignedCrew: [userId1, userId2],
  });
```

---

## Post-Migration Checklist

- [ ] All users have custom claims set
- [ ] Security rules deployed to all environments
- [ ] Client apps refreshed tokens
- [ ] Critical flows tested with all roles
- [ ] Firestore read operations reduced
- [ ] Audit logs show successful role changes
- [ ] Monitoring alerts configured
- [ ] Team trained on new setUserRole function
- [ ] Documentation updated
- [ ] Incident closed in SECURITY_INCIDENTS.md

---

## Support

If you encounter issues during migration:

1. Check `docs/SECURITY.md` for detailed documentation
2. Review audit logs in `auditLog` collection
3. Contact: security@sierrapainting.com
4. Escalate: P1 incidents to on-call (see incident response plan)

---

**Migration Version**: 1.0
**Last Updated**: 2025-10-09
**Estimated Time**: 2-4 hours (depending on user count)
