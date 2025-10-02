# A2: Admin Sets User Roles

**Epic**: A (Authentication & RBAC) | **Priority**: P0 | **Sprint**: V1 | **Est**: S | **Risk**: M

## User Story
As an Admin, I WANT to assign roles to users (admin or painter), SO THAT access control is enforced.

## Dependencies
- **A1** (Sign-in): Must have authentication before role management

## Acceptance Criteria (BDD)

### Success Scenario: Set Role
**GIVEN** I am signed in as an admin  
**WHEN** I select a user and assign role "painter"  
**THEN** the role is saved immediately  
**AND** the user's custom claims are updated  
**AND** I see confirmation "Role updated to painter"

### Success Scenario: View User Roles
**GIVEN** I am signed in as an admin  
**WHEN** I navigate to the Users screen  
**THEN** I see a list of all users in my organization  
**AND** each user shows their current role (admin or painter)

### Edge Case: Non-Admin Access
**GIVEN** I am signed in as a painter  
**WHEN** I try to access the Users screen  
**THEN** I see error "Access denied - admin only"  
**AND** I am redirected to my home screen

### Edge Case: Change Own Role
**GIVEN** I am signed in as an admin  
**WHEN** I try to change my own role to painter  
**THEN** I see warning "Cannot change your own role"  
**AND** the operation is blocked

### Accessibility
- User list items have clear role labels
- Role selector is keyboard navigable
- Confirmation messages announced by screen reader

### Performance
- **Target**: Role update P95 ≤ 1 second
- **Metric**: Time from role selection to confirmation

## Data Models

### Zod Schema
```typescript
const SetRoleSchema = z.object({
  userId: z.string().min(8),
  role: z.enum(['admin', 'painter']),
});

export type SetRole = z.infer<typeof SetRoleSchema>;
```

### Firestore Structure
```
users/{userId}
  email: string
  displayName: string
  role: 'admin' | 'painter'
  orgId: string
  updatedAt: Timestamp
```

### Custom Claims (Firebase Auth)
```json
{
  "role": "painter",
  "orgId": "org_abc123"
}
```

### Indexes Required
```javascript
// Composite index for org users
{
  collection: 'users',
  fields: [
    { fieldPath: 'orgId', order: 'ASCENDING' },
    { fieldPath: 'role', order: 'ASCENDING' }
  ]
}
```

## Security

### Firestore Rules
```javascript
match /users/{userId} {
  // Admins can read all users in their org
  allow read: if request.auth != null 
    && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin'
    && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.orgId == resource.data.orgId;
  
  // Only cloud functions can write (via setRole callable)
  allow write: if false;
}
```

### Validation
- **Client-side**: Zod schema validates role enum
- **Server-side**: Callable function verifies caller is admin and not changing own role

## API Contracts

### Cloud Function: `setRole`
```typescript
export const setRole = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
    // 1. Verify authentication
    if (!context.auth) throw new HttpsError('unauthenticated');
    
    // 2. Validate input
    const validated = SetRoleSchema.parse(data);
    
    // 3. Get caller's user document
    const callerDoc = await db.collection('users').doc(context.auth.uid).get();
    if (!callerDoc.exists || callerDoc.data()?.role !== 'admin') {
      throw new HttpsError('permission-denied', 'Admin access required');
    }
    
    // 4. Prevent self-role change
    if (validated.userId === context.auth.uid) {
      throw new HttpsError('failed-precondition', 'Cannot change your own role');
    }
    
    // 5. Get target user document
    const targetDoc = await db.collection('users').doc(validated.userId).get();
    if (!targetDoc.exists) {
      throw new HttpsError('not-found', 'User not found');
    }
    
    // 6. Verify same organization
    if (targetDoc.data()?.orgId !== callerDoc.data()?.orgId) {
      throw new HttpsError('permission-denied', 'User not in your organization');
    }
    
    // 7. Update Firestore user document
    await db.collection('users').doc(validated.userId).update({
      role: validated.role,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // 8. Set custom claims
    await admin.auth().setCustomUserClaims(validated.userId, {
      role: validated.role,
      orgId: targetDoc.data()?.orgId,
    });
    
    // 9. Log telemetry
    functions.logger.info('Role updated', {
      adminUid: context.auth.uid,
      targetUid: validated.userId,
      newRole: validated.role,
    });
    
    return { success: true };
  });
```

## Telemetry

### Analytics Events
- `role_updated`: Admin changed user role
  - Properties: `adminUid`, `targetUid`, `newRole`, `oldRole`
- `role_update_denied`: Attempted unauthorized role change
  - Properties: `callerUid`, `reason`

### Audit Log Entries
```typescript
{
  timestamp: Timestamp,
  entity: 'user_role',
  action: 'ROLE_CHANGED',
  actorUid: string,
  orgId: string,
  details: {
    targetUserId: string,
    oldRole: string,
    newRole: string
  }
}
```

## Testing Strategy

### Unit Tests
- `SetRoleSchema` validation: valid roles pass, invalid fail
- `setRole` function: mocked Firestore calls
- Self-role change: blocked with proper error
- Cross-org role change: blocked with proper error

### Integration Tests (Emulator)
- **Test 1**: Admin sets painter role → Firestore updated, custom claims set
- **Test 2**: Admin sets admin role → works correctly
- **Test 3**: Painter tries to set role → permission denied
- **Test 4**: Admin tries to change own role → blocked
- **Test 5**: Admin tries to change user in different org → denied

### E2E Tests (Flutter)
- **Test 1**: Admin signs in → navigates to Users → changes role → sees confirmation
- **Test 2**: Painter signs in → tries to access Users screen → denied

## UI Components

### Users List (Admin Only)
```dart
ListView.builder(
  itemCount: users.length,
  itemBuilder: (context, index) {
    final user = users[index];
    return ListTile(
      title: Text(user.displayName),
      subtitle: Text(user.email),
      trailing: DropdownButton<String>(
        value: user.role,
        items: [
          DropdownMenuItem(value: 'admin', child: Text('Admin')),
          DropdownMenuItem(value: 'painter', child: Text('Painter')),
        ],
        onChanged: (newRole) => _handleRoleChange(user.id, newRole!),
      ),
    );
  },
)
```

## Definition of Ready (DoR)
- [x] **A1** (Sign-in) completed
- [x] Zod schema defined
- [x] Firestore rules drafted
- [x] Admin UI mockups reviewed
- [x] Performance targets agreed (1s role update)

## Definition of Done (DoD)
- [ ] `setRole` callable function implemented
- [ ] Admin Users screen implemented
- [ ] Role dropdown selector implemented
- [ ] Permission checks working (painter blocked)
- [ ] Self-role change blocked
- [ ] Cross-org role change blocked
- [ ] Unit tests pass
- [ ] Integration tests pass (emulator)
- [ ] E2E test: admin changes role → user gets new permissions
- [ ] Telemetry events wired
- [ ] Audit log entry created
- [ ] Firestore rules deployed to staging
- [ ] Demo: change role → sign in as that user → verify access
- [ ] Performance: P95 ≤ 1s verified

## Notes

### Implementation Tips
- Store role in both Firestore (for queries) and custom claims (for auth rules)
- After changing role, target user must refresh token to see new claims
- Use `FirebaseAuth.instance.currentUser?.getIdToken(true)` to force token refresh
- Consider showing "Sign out and back in to see changes" message to target user

### Gotchas
- Custom claims updates take ~1 hour to propagate unless token is force-refreshed
- Maximum custom claims payload: 1000 bytes (plenty for role + orgId)
- Revoking admin access doesn't immediately kick them out (they can finish current session)
- Consider adding "last updated by" field for audit trail

### References
- [Firebase Custom Claims Documentation](https://firebase.google.com/docs/auth/admin/custom-claims)
- [ADR-011: Story-Driven Development](../../adrs/011-story-driven-development.md)
