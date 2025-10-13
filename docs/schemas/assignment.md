# Assignment Schema

**Collection:** `/assignments/{assignmentId}`
**Version:** 2.0
**Last Updated:** 2025-10-12

---

## Overview

Links a worker (user) to a job site. Determines which jobs a worker is authorized to clock in to.

**Purpose:**
- Authorize workers to clock in to specific job sites
- Enable company isolation (workers can only see their company's jobs)
- Track assignment lifecycle (active/inactive)

---

## Canonical Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `assignmentId` | `string` | ✅ | Document ID, unique identifier |
| `companyId` | `string` | ✅ | Company that owns this assignment |
| `userId` | `string` | ✅ | Worker user ID |
| `jobId` | `string` | ✅ | Job site ID |
| `active` | `boolean` | ✅ | Whether assignment is currently active (default: true) |
| `createdAt` | `Timestamp` | ✅ | Assignment creation timestamp |
| `updatedAt` | `Timestamp` | ✅ | Last update timestamp |

---

## Business Rules

### One Active Assignment Per User
**Recommended:** One active assignment per user per company.

While the schema allows multiple active assignments, app logic should enforce only one active assignment at a time to prevent clock-in ambiguity.

**Enforcement:** Cloud Functions validate assignment before allowing clock in.

---

## TypeScript Interface

```typescript
// functions/src/types.ts
export interface Assignment {
  assignmentId: string;
  companyId: string;
  userId: string;
  jobId: string;
  active: boolean;
  createdAt?: FirebaseFirestore.Timestamp;
  updatedAt?: FirebaseFirestore.Timestamp;
}
```

---

## Dart Model

```dart
// lib/core/models/assignment.dart
class Assignment {
  final String assignmentId;
  final String companyId;
  final String userId;
  final String jobId;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  Assignment({
    required this.assignmentId,
    required this.companyId,
    required this.userId,
    required this.jobId,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Assignment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Assignment(
      assignmentId: doc.id,
      companyId: data['companyId'] as String,
      userId: data['userId'] as String,
      jobId: data['jobId'] as String,
      active: data['active'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }
}
```

---

## Firestore Security Rules

```javascript
match /assignments/{assignmentId} {
  // Anyone in the same company can read assignments
  allow read: if authed()
    && resource.data.companyId == request.auth.token.companyId;

  // Only admins/managers can create/update/delete assignments
  allow create, update, delete: if authed()
    && hasAnyRole(['admin', 'manager'])
    && (
      // On create, must set correct companyId
      (request.resource.data.companyId == request.auth.token.companyId) ||
      // On update/delete, existing must match
      (resource.data.companyId == request.auth.token.companyId)
    );
}
```

---

## Composite Index (REQUIRED)

This compound query requires a Firestore composite index:

```javascript
// Query used by providers to find active assignment
db.collection('assignments')
  .where('userId', '==', uid)
  .where('companyId', '==', companyId)
  .where('active', '==', true)
  .limit(1)
```

**Index Definition:**
```json
{
  "collectionGroup": "assignments",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "userId", "order": "ASCENDING" },
    { "fieldPath": "companyId", "order": "ASCENDING" },
    { "fieldPath": "active", "order": "ASCENDING" }
  ]
}
```

**Deploy:** `firebase deploy --only firestore:indexes`

---

## Setup Example

```typescript
// functions/src/setup.ts (or tools/setup_test_data.cjs)
const assignmentId = `${userId}__${jobId}`;
await db.collection('assignments').doc(assignmentId).set({
  assignmentId,
  companyId: 'company-sierra-painting',
  userId: 'user-worker-123',
  jobId: 'job-sf-painted-ladies',
  active: true,
  createdAt: admin.firestore.FieldValue.serverTimestamp(),
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
});
```

---

## Queries

### Get Active Assignment for User
```dart
final assignments = await db
  .collection('assignments')
  .where('userId', isEqualTo: currentUserId)
  .where('companyId', isEqualTo: currentCompanyId)
  .where('active', isEqualTo: true)
  .limit(1)
  .get();
```

### Get All Workers Assigned to Job
```typescript
const workers = await db
  .collection('assignments')
  .where('jobId', '==', jobId)
  .where('companyId', '==', companyId)
  .where('active', '==', true)
  .get();
```

---

## Deactivating an Assignment

**Admin/Manager Action:**
```typescript
await db.collection('assignments').doc(assignmentId).update({
  active: false,
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
});
```

**Effect:** Worker can no longer clock in to this job.

---

## Validation

| Rule | Check |
|------|-------|
| Assignment ID format | Not empty |
| Company ID | Valid company exists |
| User ID | Valid user exists |
| Job ID | Valid job exists |
| Active | Boolean |

---

## Related Schemas

- [User](./user.md) - Worker assigned to job
- [Job](./job.md) - Job site worker is assigned to
- [TimeEntry](./time_entry.md) - Clock in/out records for this assignment

---

**See Also:**
- [Firestore Composite Indexes](https://firebase.google.com/docs/firestore/query-data/indexing)
- [Firestore Security Rules](../../firestore.rules)
