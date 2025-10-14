# Security model

This document explains Sierra Painting's security architecture and principles.

## Core principles

### 1. Deny by default

All Firestore and Storage operations are denied unless explicitly allowed:

```javascript
// firestore.rules
match /{document=**} {
  allow read, write: if false;  // Deny everything by default
}
```

Access is granted only after verifying:

- User is authenticated
- User has appropriate role
- User owns the resource (or is admin)
- Operation is allowed by business rules

### 2. Role-based access control (RBAC)

Users have roles that determine permissions:

- **Admin**: Full access to all data and operations
- **Manager**: Access to team data, limited admin functions
- **Worker**: Access to own data, job assignments

Roles are stored as custom claims in Firebase Auth:

```dart
class UserRole {
  static const String admin = 'admin';
  static const String manager = 'manager';
  static const String worker = 'worker';
}
```

### 3. Server-side enforcement

Critical operations happen server-side only:

- Mark invoice paid
- Generate PDFs
- Process payments
- Modify user roles
- Audit logging

Clients cannot bypass these restrictions.

### 4. Organization-scoped access

Users only access data for their organization:

```javascript
match /jobs/{jobId} {
  allow read: if isAuthenticated() 
    && resource.data.orgId == request.auth.token.orgId;
}
```

This prevents data leakage between organizations.

## Authentication

### Firebase Authentication

Sierra Painting uses Firebase Authentication with email/password:

```dart
// Sign in
await FirebaseAuth.instance.signInWithEmailAndPassword(
  email: email,
  password: password,
);

// Sign out
await FirebaseAuth.instance.signOut();
```

### Custom claims

Roles are stored as custom claims set server-side:

```typescript
// Cloud Function - setUserRole
await admin.auth().setCustomUserClaims(userId, {
  role: 'admin',
  orgId: 'org-123',
});
```

Claims are included in the auth token and available in security rules.

## Authorization

### Firestore rules

Firestore rules enforce authorization:

```javascript
// Allow users to read their own data
match /users/{userId} {
  allow read: if isOwner(userId) || isAdmin();
  allow update: if isOwner(userId) && !modifiesRole();
}

// Allow workers to create time entries
match /jobs/{jobId}/timeEntries/{entryId} {
  allow create: if isAuthenticated() && isOwnEntry();
  allow read: if isOwnEntry() || isAdmin();
  allow update, delete: if false;  // Server-only
}

// Admin-only operations
match /invoices/{invoiceId} {
  allow read: if isAuthenticated() && sameOrg();
  allow create: if isAdmin();
  allow update: if isAdmin() && !modifiesPaidStatus();
}
```

### Helper functions

Rules use helper functions for readability:

```javascript
function isAuthenticated() {
  return request.auth != null;
}

function isOwner(userId) {
  return isAuthenticated() && request.auth.uid == userId;
}

function isAdmin() {
  return isAuthenticated() && request.auth.token.role == 'admin';
}

function sameOrg() {
  return isAuthenticated() 
    && request.auth.token.orgId == resource.data.orgId;
}

function modifiesRole() {
  return request.resource.data.role != resource.data.role;
}

function modifiesPaidStatus() {
  return request.resource.data.paid != resource.data.paid
    || request.resource.data.paidAt != resource.data.paidAt;
}
```

### Route guards

App routes are protected by role checks:

```dart
GoRoute(
  path: '/admin',
  builder: (context, state) => AdminDashboard(),
  redirect: (context, state) {
    final user = ref.read(currentUserProvider);
    if (user?.role != UserRole.admin) {
      return '/unauthorized';
    }
    return null;
  },
)
```

## App Check

Firebase App Check protects backend APIs from abuse.

### How it works

1. App requests App Check token
2. App Check verifies app authenticity
3. Token attached to all Firebase requests
4. Backend validates token before processing

### Configuration

```dart
// Initialize App Check
await FirebaseAppCheck.instance.activate(
  androidProvider: AndroidProvider.playIntegrity,
  appleProvider: AppleProvider.appAttest,
);
```

### Enforcement

Cloud Functions require App Check:

```typescript
export const createEstimatePdf = onCall(
  { enforceAppCheck: true },
  async (request) => {
    // Function logic
  }
);
```

## Sensitive operations

### Payment operations

Payments require multiple layers of security:

1. Admin role required
2. Server-side validation
3. Idempotency key required
4. Audit log created
5. Confirmation email sent

```typescript
// Cloud Function - markPaidManual
export const markPaidManual = onCall(
  { enforceAppCheck: true },
  async (request) => {
    // 1. Verify admin role
    if (request.auth?.token?.role !== 'admin') {
      throw new HttpsError('permission-denied', 'Admin role required');
    }
    
    // 2. Validate input
    const { invoiceId, amount, idempotencyKey } = validateInput(request.data);
    
    // 3. Check idempotency
    if (await isDuplicate(idempotencyKey)) {
      return { alreadyProcessed: true };
    }
    
    // 4. Mark paid in transaction
    await firestore.runTransaction(async (tx) => {
      const invoice = await tx.get(invoiceRef);
      if (invoice.data().paid) {
        throw new HttpsError('failed-precondition', 'Already paid');
      }
      
      tx.update(invoiceRef, {
        paid: true,
        paidAt: Timestamp.now(),
        paidBy: request.auth.uid,
      });
      
      // 5. Create audit log
      tx.create(auditRef, {
        action: 'invoice.paid',
        userId: request.auth.uid,
        invoiceId,
        timestamp: Timestamp.now(),
      });
    });
    
    return { success: true };
  }
);
```

### Role modifications

Only admins can modify roles, and it's server-side only:

```typescript
export const setUserRole = onCall(
  { enforceAppCheck: true },
  async (request) => {
    // Verify caller is admin
    if (request.auth?.token?.role !== 'admin') {
      throw new HttpsError('permission-denied', 'Admin role required');
    }
    
    // Set custom claims
    await admin.auth().setCustomUserClaims(userId, {
      role: newRole,
      orgId: request.auth.token.orgId,
    });
    
    // Audit log
    await auditLog.create({
      action: 'user.roleChanged',
      targetUserId: userId,
      oldRole: oldRole,
      newRole: newRole,
      changedBy: request.auth.uid,
      timestamp: Timestamp.now(),
    });
  }
);
```

## Audit logging

All sensitive operations are logged:

```typescript
interface AuditLog {
  action: string;           // e.g., 'invoice.paid'
  userId: string;           // Who performed action
  targetId?: string;        // What was affected
  metadata: object;         // Additional context
  timestamp: Timestamp;
}
```

Audit logs are:

- Immutable (write-only)
- Queryable by admins
- Retained for compliance
- Indexed for performance

## Testing security

### Firestore rules tests

Rules are tested with emulator:

```typescript
// tests/rules/invoices.test.ts
test('worker cannot mark invoice paid', async () => {
  const db = testEnv.authenticatedContext('worker-123', {
    role: 'worker',
    orgId: 'org-1',
  }).firestore();
  
  const invoice = db.doc('invoices/inv-1');
  await expectFirestorePermissionDenied(
    invoice.update({ paid: true })
  );
});

test('admin can mark invoice paid', async () => {
  const db = testEnv.authenticatedContext('admin-123', {
    role: 'admin',
    orgId: 'org-1',
  }).firestore();
  
  const invoice = db.doc('invoices/inv-1');
  await expectFirestorePermissionGranted(
    invoice.update({ paid: true })
  );
});
```

### Integration tests

End-to-end tests verify security:

```dart
testWidgets('non-admin cannot access admin page', (tester) async {
  // Sign in as worker
  await signIn(email: 'worker@example.com');
  
  // Attempt to navigate to admin page
  await tester.tap(find.byIcon(Icons.admin_panel_settings));
  await tester.pumpAndSettle();
  
  // Should see unauthorized message
  expect(find.text('Unauthorized'), findsOneWidget);
});
```

## Best practices

1. **Never trust client input**: Always validate server-side
2. **Use transactions**: Ensure atomic operations for critical data
3. **Audit sensitive operations**: Log who did what when
4. **Test security rules**: Include in CI/CD pipeline
5. **Principle of least privilege**: Grant minimum necessary permissions
6. **Separate environments**: Use different projects for staging/production

## Common pitfalls

### ❌ Allowing client to set sensitive fields

```javascript
// Bad - client can set paid status
match /invoices/{invoiceId} {
  allow update: if isAuthenticated();
}
```

### ✅ Protect sensitive fields

```javascript
// Good - prevent client from setting paid status
match /invoices/{invoiceId} {
  allow update: if isAuthenticated() && !modifiesPaidStatus();
}
```

### ❌ Trusting client timestamps

```javascript
// Bad - client controls timestamp
{
  createdAt: request.resource.data.createdAt
}
```

### ✅ Use server timestamps

```javascript
// Good - server sets timestamp
{
  createdAt: request.time
}
```

## Next steps

- [System architecture](architecture.md)
- [Configure App Check](../how-to/configure-app-check.md)
- [Update Firestore rules](../how-to/update-firestore-rules.md)

---