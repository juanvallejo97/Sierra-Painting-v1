# User Schema

**Collection:** `/users/{userId}`
**Version:** 2.0
**Last Updated:** 2025-10-12

---

## Overview

Represents a user account (worker or admin) within a company. User identity and authentication are managed by Firebase Auth, while this document stores profile information.

**Important:** User role and company membership are stored in **Firebase Auth Custom Claims**, not in this Firestore document (for client-side access control restrictions).

---

## Canonical Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `userId` | `string` | ✅ | Document ID, matches Firebase Auth UID |
| `displayName` | `string` | ✅ | User's full name |
| `email` | `string` | ✅ | User's email address |
| `photoURL` | `string?` | ❌ | Profile photo URL (optional) |
| `createdAt` | `Timestamp` | ✅ | Account creation timestamp |
| `updatedAt` | `Timestamp` | ✅ | Last profile update timestamp |

---

## Custom Claims (Firebase Auth Token)

These fields are **NOT stored in Firestore** - they are part of the JWT token:

| Claim | Type | Description |
|-------|------|-------------|
| `companyId` | `string` | Company ID user belongs to |
| `role` | `"worker" \| "admin" \| "manager"` | User's role |
| `active` | `boolean` | Whether user account is active |

**Access:** Read from `FirebaseAuth.currentUser.getIdTokenResult().claims`

**Set By:** Admin-only Cloud Function `adminSetMembership`

---

## Firestore Security Rules

```javascript
match /users/{userId} {
  // Users can read their own profile
  allow read: if request.auth.uid == userId;

  // Users can create their own profile (client-side registration)
  // BUT can only set these specific fields (no role/companyId)
  allow create: if request.auth.uid == userId
    && request.resource.data.keys().hasOnly([
      'displayName', 'email', 'photoURL', 'createdAt', 'updatedAt'
    ])
    && request.time == request.resource.data.createdAt
    && request.resource.data.updatedAt == request.resource.data.createdAt;

  // Users can update their own profile (limited fields)
  allow update: if request.auth.uid == userId
    && request.resource.data.keys().hasOnly([
      'displayName', 'photoURL', 'updatedAt'
    ])
    && request.resource.data.updatedAt == request.time;

  // No client-side deletes
  allow delete: if false;
}
```

**Rationale:**
- Role and company membership are **too sensitive** to allow client writes
- Admins set these via server-side Cloud Function (bypasses rules)
- Prevents privilege escalation attacks

---

## TypeScript Interface

```typescript
// functions/src/types.ts
export interface User {
  userId: string;
  displayName: string;
  email: string;
  photoURL?: string;
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
}

// Custom claims (not in Firestore)
export interface UserClaims {
  companyId: string;
  role: 'worker' | 'admin' | 'manager';
  active: boolean;
}
```

---

## Dart Model

```dart
// lib/core/models/user.dart
class User {
  final String userId;
  final String displayName;
  final String email;
  final String? photoURL;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.userId,
    required this.displayName,
    required this.email,
    this.photoURL,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return User(
      userId: doc.id,
      displayName: data['displayName'] as String,
      email: data['email'] as String,
      photoURL: data['photoURL'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }
}
```

---

## Setup & Admin Operations

### Creating a User (Client-Side)

```typescript
// Client creates basic profile after Firebase Auth signup
await db.collection('users').doc(user.uid).set({
  displayName: 'John Doe',
  email: 'john@example.com',
  photoURL: null,
  createdAt: FieldValue.serverTimestamp(),
  updatedAt: FieldValue.serverTimestamp(),
});
```

### Setting Role & Company (Server-Side Only)

```typescript
// functions/src/admin.ts
export const adminSetMembership = onCall(async (req) => {
  // Verify caller is admin
  const { uid, companyId, role, active } = req.data;

  // Set custom claims (bypasses Firestore rules)
  await admin.auth().setCustomUserClaims(uid, {
    companyId,
    role,
    active,
  });

  return { success: true };
});
```

**Important:** User must sign out and back in for new claims to take effect (JWT refresh).

---

## Queries

### Get Current User Profile
```dart
final userDoc = await db.collection('users').doc(currentUser.uid).get();
final user = User.fromFirestore(userDoc);
```

### Get Custom Claims
```dart
final idTokenResult = await currentUser.getIdTokenResult(forceRefresh: true);
final companyId = idTokenResult.claims?['companyId'] as String?;
final role = idTokenResult.claims?['role'] as String?;
```

---

## Migration Notes

**Legacy Fields (DEPRECATED):**
- ~~`companyId`~~ → Use custom claims
- ~~`role`~~ → Use custom claims
- ~~`active`~~ → Use custom claims

**Removal Date:** 2025-10-26

**Migration Script:** `tools/migrate_user_claims.cjs`

---

## Validation

| Rule | Check |
|------|-------|
| Email format | Valid email regex |
| Display name | 2-50 characters |
| Photo URL | Valid https:// URL or null |

---

## Related Schemas

- [Assignment](./assignment.md) - Links users to jobs
- [TimeEntry](./time_entry.md) - User's clock in/out records

---

**See Also:**
- [Firebase Custom Claims Documentation](https://firebase.google.com/docs/auth/admin/custom-claims)
- [Firestore Security Rules](../../firestore.rules)
