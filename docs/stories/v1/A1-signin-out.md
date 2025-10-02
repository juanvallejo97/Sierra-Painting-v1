# A1: Sign-in/out + Reliable Sessions

**Epic**: A (Authentication & RBAC) | **Priority**: P0 | **Sprint**: V1 | **Est**: S | **Risk**: M

## User Story
As a Painter or Admin, I WANT to sign in with my email and password, SO THAT I can access the app securely.

## Dependencies
- None (blocking story)

## Acceptance Criteria (BDD)

### Success Scenario: Sign-in
**GIVEN** I have valid credentials  
**WHEN** I enter my email and password and tap "Sign In"  
**THEN** I am authenticated within 2 seconds  
**AND** I see the appropriate home screen (Jobs Today for painter, Dashboard for admin)

### Success Scenario: Session Persistence
**GIVEN** I signed in previously  
**WHEN** I close and reopen the app  
**THEN** I remain signed in without re-entering credentials  
**AND** I see my home screen within 1 second

### Success Scenario: Sign-out
**GIVEN** I am signed in  
**WHEN** I tap "Sign Out" from settings  
**THEN** I am signed out immediately  
**AND** redirected to the sign-in screen

### Edge Case: Invalid Credentials
**GIVEN** I enter incorrect email or password  
**WHEN** I tap "Sign In"  
**THEN** I see error "Invalid email or password"  
**AND** I remain on the sign-in screen

### Edge Case: Network Error
**GIVEN** I have no network connectivity  
**WHEN** I try to sign in  
**THEN** I see error "No internet connection"  
**AND** sign-in is blocked (cannot proceed offline)

### Edge Case: Session Expiry
**GIVEN** my session token expires  
**WHEN** I try to perform an authenticated action  
**THEN** I am redirected to sign-in screen  
**AND** I see message "Session expired, please sign in again"

### Accessibility
- Email and password fields labeled for screen readers
- "Sign In" button minimum 48×48 touch target
- Error messages announced by screen reader
- Support high contrast mode

### Performance
- **Target**: Sign-in P95 ≤ 2 seconds
- **Metric**: Time from tap "Sign In" to home screen rendered

## Data Models

### Zod Schema
```typescript
const SignInSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});

export type SignIn = z.infer<typeof SignInSchema>;
```

### Firestore Structure
```
users/{userId}
  email: string
  displayName: string
  role: 'admin' | 'painter'
  orgId: string
  createdAt: Timestamp
  updatedAt: Timestamp
  lastSignInAt: Timestamp
```

### Indexes Required
```javascript
// Single field index on orgId (auto-created)
// Single field index on email (auto-created)
```

## Security

### Firestore Rules
```javascript
match /users/{userId} {
  // Users can read their own profile
  allow read: if request.auth != null && request.auth.uid == userId;
  
  // Admins can read all users in their org
  allow read: if request.auth != null 
    && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin'
    && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.orgId == resource.data.orgId;
  
  // Only admins can write user documents (via cloud function)
  allow write: if false;
}
```

### Validation
- **Client-side**: Zod schema for email format and password length
- **Server-side**: Firebase Authentication handles password validation

## API Contracts

### Firebase Authentication
Uses Firebase Auth SDK directly (no custom function needed):
```dart
// Sign in
final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
  email: email,
  password: password,
);

// Sign out
await FirebaseAuth.instance.signOut();
```

### Custom Claims (Set by Admin)
```typescript
// Set via cloud function (A2 story)
await admin.auth().setCustomUserClaims(userId, {
  role: 'painter',
  orgId: 'org_abc123',
});
```

## Telemetry

### Analytics Events
- `sign_in_success`: Successful sign-in
  - Properties: `method: 'email'`, `userId`, `role`
- `sign_in_failure`: Failed sign-in attempt
  - Properties: `error`, `email` (hashed)
- `sign_out`: User signed out
  - Properties: `userId`, `sessionDuration`

### Audit Log Entries
```typescript
{
  timestamp: Timestamp,
  entity: 'auth',
  action: 'SIGN_IN',
  actorUid: string,
  orgId: string,
  details: {
    method: 'email',
    ipAddress: string (if available)
  }
}
```

## Testing Strategy

### Unit Tests
- Email validation: valid emails pass, invalid fail
- Password validation: minimum 8 characters enforced
- Sign-out clears auth state

### Integration Tests (Emulator)
- **Test 1**: Sign in with valid credentials → auth state updated
- **Test 2**: Sign in with invalid credentials → error returned
- **Test 3**: Sign out → auth state cleared
- **Test 4**: Session persistence → reopen app → still authenticated

### E2E Tests (Flutter)
- **Test 1**: Cold start → sign in → see home screen within 2s
- **Test 2**: Close app → reopen → still signed in
- **Test 3**: Sign out → see sign-in screen

## UI Components

### Sign-in Screen
```dart
TextField(
  decoration: InputDecoration(labelText: 'Email'),
  keyboardType: TextInputType.emailAddress,
  autofillHints: [AutofillHints.email],
),
TextField(
  decoration: InputDecoration(labelText: 'Password'),
  obscureText: true,
  autofillHints: [AutofillHints.password],
),
ElevatedButton(
  onPressed: _isLoading ? null : () => _handleSignIn(),
  child: _isLoading 
    ? CircularProgressIndicator()
    : Text('Sign In'),
  style: ElevatedButton.styleFrom(
    minimumSize: Size(double.infinity, 48),
  ),
)
```

## Definition of Ready (DoR)
- [x] Firebase Authentication configured
- [x] User schema defined
- [x] Firestore rules drafted
- [x] UI mockups reviewed
- [x] Performance targets agreed (2s sign-in)

## Definition of Done (DoD)
- [ ] Firebase Auth integration implemented
- [ ] Sign-in screen implemented
- [ ] Sign-out functionality implemented
- [ ] Session persistence working
- [ ] Error handling for all edge cases
- [ ] Unit tests pass
- [ ] Integration tests pass (emulator)
- [ ] E2E test: sign-in → sign-out flow
- [ ] Telemetry events wired
- [ ] Firestore rules deployed to staging
- [ ] Demo: sign in → navigate → close app → reopen → still signed in
- [ ] Performance: P95 ≤ 2s verified

## Notes

### Implementation Tips
- Use `firebase_auth` package for Flutter
- Store auth state in Riverpod provider for global access
- Use `authStateChanges()` stream to listen for auth changes
- Implement auto-redirect: if signed in, skip sign-in screen

### Gotchas
- Firebase Auth tokens refresh automatically every hour
- Custom claims (role, orgId) are in `idTokenResult.claims`, not user object
- Must call `reload()` after claims change to see new claims
- Offline sign-in fails (Firebase Auth requires network)

### References
- [Firebase Authentication Documentation](https://firebase.google.com/docs/auth)
- [FlutterFire Auth Package](https://pub.dev/packages/firebase_auth)
- [ADR-011: Story-Driven Development](../../adrs/011-story-driven-development.md)
