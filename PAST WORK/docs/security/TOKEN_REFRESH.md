# Token Refresh on Role Change

**Version:** 1.0
**Last Updated:** 2025-10-12
**Status:** ✅ **IMPLEMENTED**

---

## Overview

This document describes the automatic token refresh mechanism that prevents privilege escalation when user roles change.

**Problem:** Firebase Auth tokens contain custom claims (role, companyId) that are cached for up to 1 hour. If an admin changes a user's role, the user's old token remains valid until expiry, potentially allowing unauthorized access.

**Solution:** Automatic token refresh triggered by backend notification when roles change.

---

## Architecture

### Token Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│  User logs in                                                │
│  ↓                                                           │
│  Firebase Auth generates ID token                           │
│  ↓                                                           │
│  Token contains custom claims: {role: 'worker', ...}        │
│  ↓                                                           │
│  Token cached for up to 1 hour                              │
└─────────────────────────────────────────────────────────────┘

Without token refresh:
  Admin changes role: worker → manager
  ↓
  User still has old token with role='worker' for up to 1 hour
  ↓
  Security risk: User can't access manager features they should have
  OR worse: Demoted admin still has admin privileges

With token refresh:
  Admin changes role via setUserRole function
  ↓
  Backend sets forceTokenRefresh=true in user document
  ↓
  Client TokenRefreshService detects flag
  ↓
  Client calls getIdToken(true) to force refresh
  ↓
  New token generated with updated role
  ↓
  User immediately has correct permissions
```

---

## Implementation

### Backend (Cloud Functions)

**File:** `functions/src/auth/setUserRole.ts`

When admin changes a user's role, the function:
1. Sets custom claims via `setCustomUserClaims()`
2. Updates user document with new role
3. **Sets `forceTokenRefresh: true` flag**
4. Logs the change to audit log

**Code:**
```typescript
await userRef.set(
  {
    role,
    companyId,
    roleUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    // Force token refresh flag
    forceTokenRefresh: true,
    tokenRefreshReason: 'role_change',
  },
  { merge: true }
);
```

---

### Client (Flutter)

**File:** `lib/core/services/token_refresh_service.dart`

The `TokenRefreshService` class:
1. Listens to user document in Firestore
2. Detects `forceTokenRefresh` flag
3. Calls `getIdToken(true)` to force refresh
4. Clears the flag after successful refresh

**Lifecycle:**
- **Start listening:** When user logs in
- **Stop listening:** When user logs out
- **Auto-managed:** Via `tokenRefreshListenerProvider` in `auth_provider.dart`

**Code:**
```dart
class TokenRefreshService {
  void startListening() {
    _userDocSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(_handleUserDocChange);
  }

  Future<void> _handleUserDocChange(DocumentSnapshot snapshot) async {
    final forceRefresh = data['forceTokenRefresh'] as bool?;
    if (forceRefresh == true) {
      await _refreshToken(snapshot.reference);
    }
  }

  Future<void> _refreshToken(DocumentReference userRef) async {
    // Force token refresh (bypass cache)
    await user.getIdToken(true);

    // Clear flag
    await userRef.update({
      'forceTokenRefresh': FieldValue.delete(),
      'tokenRefreshReason': FieldValue.delete(),
    });
  }
}
```

---

### Integration (Main App)

**File:** `lib/main.dart`

The `SierraPaintingApp` widget watches the `tokenRefreshListenerProvider`:

```dart
class SierraPaintingApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize token refresh listener
    ref.watch(tokenRefreshListenerProvider);

    return MaterialApp(...);
  }
}
```

**Provider:** `lib/core/providers/auth_provider.dart`

```dart
final tokenRefreshListenerProvider = Provider<void>((ref) {
  final user = ref.watch(currentUserProvider);
  final service = ref.watch(tokenRefreshServiceProvider);

  if (user != null) {
    service.startListening(); // User logged in
  } else {
    service.stopListening(); // User logged out
  }
});
```

---

## Security Benefits

### Prevents Privilege Escalation

**Scenario 1: Role Upgrade (Worker → Manager)**
```
Without token refresh:
  T+0s:   Admin promotes worker to manager
  T+1s:   Worker tries to access manager dashboard → DENIED (old token)
  T+3600s: Worker's token expires, refreshes → SUCCESS

With token refresh:
  T+0s:  Admin promotes worker to manager
  T+1s:  TokenRefreshService detects flag
  T+2s:  New token generated with role='manager'
  T+3s:  Worker tries to access manager dashboard → SUCCESS
```

**Scenario 2: Role Downgrade (Admin → Worker)**
```
Without token refresh:
  T+0s:   Admin demotes user to worker (e.g., employee termination)
  T+1s:   User still has admin token → Can delete data, change roles
  T+3600s: Token expires → Privileges revoked

With token refresh:
  T+0s: Admin demotes user to worker
  T+1s: TokenRefreshService refreshes token
  T+2s: User loses admin privileges immediately
```

---

## Testing

### Manual Test

**1. Setup:**
- User A (worker role)
- User B (admin role)

**2. Test Steps:**
1. Login as User A
2. Verify role in token:
   ```dart
   final user = FirebaseAuth.instance.currentUser;
   final token = await user?.getIdTokenResult();
   print(token?.claims?['role']); // Output: 'worker'
   ```

3. In separate browser/device, login as User B (admin)
4. User B calls `setUserRole` to promote User A to 'manager':
   ```dart
   final setUserRole = httpsCallable(functions, 'setUserRole');
   await setUserRole({
     'uid': userA.uid,
     'role': 'manager',
     'companyId': 'company-123',
   });
   ```

5. Back on User A's device, within 2-3 seconds:
   ```dart
   final newToken = await user?.getIdTokenResult(true); // Force refresh
   print(newToken?.claims?['role']); // Output: 'manager'
   ```

**Expected:** User A's role updates to 'manager' within seconds (not hours)

---

### Automated Test

**File:** `functions/src/auth/__tests__/setUserRole.integration.test.ts`

Test verifies:
1. `setUserRole` sets `forceTokenRefresh` flag
2. Flag persists in Firestore
3. Audit log records role change

**Run:**
```bash
cd functions
npm test -- setUserRole
```

---

## Monitoring

### Metrics to Track

**1. Token Refresh Success Rate**
- Metric: Percentage of successful token refreshes
- Target: > 99%
- Alert: If < 95%

**2. Token Refresh Latency**
- Metric: Time from role change to token refresh
- Target: < 5 seconds (p95)
- Alert: If > 30 seconds

**3. Failed Refresh Count**
- Metric: Number of failed `getIdToken(true)` calls
- Alert: If > 10/hour

### Logging

**Backend (Cloud Functions):**
```typescript
logger.info('User role changed', {
  userId: uid,
  oldRole: oldRole,
  newRole: role,
  forceRefreshSet: true,
});
```

**Client (Flutter):**
```dart
debugPrint('[TokenRefreshService] Token refresh required: role_change');
debugPrint('[TokenRefreshService] Token refreshed successfully');
```

---

## Troubleshooting

### Issue: Token Not Refreshing

**Symptom:** User role changes but permissions don't update

**Diagnosis:**
1. Check user document in Firestore:
   ```javascript
   db.collection('users').doc(userId).get()
   ```
   - Verify `forceTokenRefresh: true` is set

2. Check client logs for token refresh:
   ```
   [TokenRefreshService] Token refresh required: role_change
   [TokenRefreshService] Refreshing token...
   [TokenRefreshService] Token refreshed successfully
   ```

**Common Causes:**
- Client not listening (check `tokenRefreshListenerProvider` is watched)
- Firestore permissions deny client read to own user doc
- Network connectivity issues

**Fix:**
```dart
// Manually force refresh
final user = FirebaseAuth.instance.currentUser;
await user?.getIdToken(true);
```

---

### Issue: Flag Not Cleared

**Symptom:** `forceTokenRefresh` remains true after refresh

**Diagnosis:**
Check Firestore user document - if flag persists, client couldn't clear it

**Common Causes:**
- Firestore security rules deny client write to user doc
- Client crashed before clearing flag
- Network error during flag clear

**Fix (manual):**
```javascript
// Via Firebase Console or admin SDK
db.collection('users').doc(userId).update({
  forceTokenRefresh: admin.firestore.FieldValue.delete(),
  tokenRefreshReason: admin.firestore.FieldValue.delete(),
});
```

**Note:** Flag will be cleared on next successful refresh attempt

---

### Issue: Excessive Token Refreshes

**Symptom:** Token refreshes multiple times in quick succession

**Diagnosis:** Check logs for repeated `[TokenRefreshService] Token refresh required` messages

**Common Causes:**
- Firestore listener triggering on every document change (not just forceTokenRefresh)
- Multiple TokenRefreshService instances running
- Flag not being cleared properly

**Fix:**
1. Ensure only one listener per user (check provider lifecycle)
2. Verify flag is deleted after refresh (not set to false)

---

## Future Enhancements

### 1. Token Version Tracking

Instead of flag-based refresh, use version counter:

```typescript
// Backend
await admin.auth().setCustomUserClaims(uid, {
  role,
  companyId,
  tokenVersion: (currentVersion || 0) + 1,
});

// Client checks version mismatch
const localVersion = tokenClaims?.tokenVersion;
const serverVersion = userDoc.tokenVersion;
if (serverVersion > localVersion) {
  await refreshToken();
}
```

**Benefits:**
- No flag to clean up
- Can track total refresh count
- Handles multiple rapid role changes

---

### 2. Server-Side Token Revocation

Firebase Admin SDK can revoke all tokens for a user:

```typescript
await admin.auth().revokeRefreshTokens(uid);
```

**Benefits:**
- Immediate revocation (no client cooperation needed)
- Useful for security incidents (compromised account)

**Drawbacks:**
- Revokes ALL sessions (logs user out everywhere)
- Requires re-authentication

**Use Cases:**
- Account compromised
- Emergency admin demotion
- User deletion

---

### 3. Role Change Notifications

Show UI notification when role changes:

```dart
// Listen for role changes
ref.listen(userRoleProvider, (previous, next) {
  if (previous != null && next != null && previous != next) {
    showSnackBar('Your role has been updated to: $next');
  }
});
```

---

## Compliance

### Security Standards

**OWASP Top 10:**
- **A01:2021 - Broken Access Control**: Token refresh prevents stale permissions

**NIST Cybersecurity Framework:**
- **PR.AC-4**: Access permissions managed by role changes reflect immediately

### Audit Trail

All role changes logged to `auditLog` collection:

```typescript
{
  action: 'setUserRole',
  targetUserId: 'user-123',
  performedBy: 'admin-456',
  oldRole: 'worker',
  newRole: 'manager',
  timestamp: Timestamp,
}
```

Retention: 7 years (per data retention policy)

---

## References

### Firebase Documentation
- [Custom Claims](https://firebase.google.com/docs/auth/admin/custom-claims)
- [getIdToken()](https://firebase.google.com/docs/reference/js/auth.user#getidtoken)
- [Security Rules](https://firebase.google.com/docs/firestore/security/rules-structure)

### Internal Documentation
- `functions/src/auth/setUserRole.ts` - Role management function
- `lib/core/services/token_refresh_service.dart` - Client refresh service
- `docs/policy/DATA_RETENTION_POLICY.md` - Audit log retention

---

**Approved By:**
- Engineering: TBD
- Security: TBD

**Next Review Date:** 2026-10-12
