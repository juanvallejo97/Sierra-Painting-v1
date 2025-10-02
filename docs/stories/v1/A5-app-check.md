# A5: App Check Enforcement

**Epic**: A (Authentication & RBAC) | **Priority**: P0 | **Sprint**: V1 | **Est**: S | **Risk**: M

## User Story
As a System Administrator, I WANT App Check enabled on all Cloud Functions, SO THAT only legitimate app instances can call our APIs.

## Dependencies
- **A1** (Sign-in): Authentication must work before adding App Check

## Acceptance Criteria (BDD)

### Success Scenario: Legitimate App Request
**GIVEN** the app has a valid App Check token  
**WHEN** it calls a protected Cloud Function  
**THEN** the request succeeds normally  
**AND** App Check validation passes silently

### Success Scenario: Debug Token in Development
**GIVEN** I am running the app in debug mode with debug token configured  
**WHEN** I call a protected Cloud Function  
**THEN** the request succeeds  
**AND** debug token is accepted by App Check

### Edge Case: Missing App Check Token
**GIVEN** an attacker calls a Cloud Function without App Check token  
**WHEN** the request reaches the server  
**THEN** it is rejected with error "App Check verification failed"  
**AND** the function does not execute

### Edge Case: Invalid App Check Token
**GIVEN** an attacker sends a forged App Check token  
**WHEN** the request reaches the server  
**THEN** Firebase rejects the token  
**AND** returns error "Invalid App Check token"

### Accessibility
- No UI impact (backend security feature)
- Error messages should be clear for debugging

### Performance
- **Target**: App Check validation adds ≤ 50ms to request latency
- **Metric**: Time difference between protected and unprotected function calls

## Data Models

### App Check Token (Automatic)
Firebase App Check automatically attaches tokens to requests. No custom schema needed.

### Debug Token Configuration
```json
{
  "debug_token": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "expires_at": "2025-01-01T00:00:00Z"
}
```

## Security

### Cloud Function Configuration
```typescript
// Enable App Check on all callable functions
export const clockIn = functions
  .runWith({ 
    enforceAppCheck: true,
    consumeAppCheckToken: true  // Token consumed to prevent replay
  })
  .https.onCall(async (data, context) => {
    // App Check already validated by Firebase
    // context.app contains App Check metadata
    // ... function logic
  });
```

### Firebase App Check Configuration
```javascript
// Firebase Console → App Check
// Android: Play Integrity API
// iOS: DeviceCheck / App Attest
// Web: reCAPTCHA Enterprise

// Debug tokens for development
// Add debug token UUIDs in Firebase Console for emulator/staging
```

### Firestore Rules (No Change)
App Check is orthogonal to Firestore rules. Both layers protect the app.

## API Contracts

### All Protected Functions
Every callable function should have:
```typescript
.runWith({ 
  enforceAppCheck: true,
  consumeAppCheckToken: true 
})
```

Functions to protect:
- `clockIn` (B1)
- `clockOut` (B2)
- `setRole` (A2)
- Future: `createQuote`, `markPaid`, etc.

## Telemetry

### Analytics Events
- `app_check_failure`: App Check token validation failed
  - Properties: `functionName`, `errorCode`
- `app_check_debug_token_used`: Debug token used in production (alert!)
  - Properties: `functionName`, `environment`

### Audit Log Entries
```typescript
// Log only failures (successes are normal)
{
  timestamp: Timestamp,
  entity: 'app_check',
  action: 'VERIFICATION_FAILED',
  actorUid: string | null,  // May be null if unauthenticated
  details: {
    functionName: string,
    errorCode: string,
    ipAddress: string
  }
}
```

## Testing Strategy

### Unit Tests
- App Check configuration: verify `enforceAppCheck: true` on all functions
- Mock App Check context in unit tests

### Integration Tests (Emulator)
- **Test 1**: Configure debug token → call function → succeeds
- **Test 2**: Remove debug token → call function → fails
- **Test 3**: Invalid token → call function → rejected

### E2E Tests (Flutter)
- **Test 1**: Release build → call protected function → succeeds
- **Test 2**: Debug build with debug token → call function → succeeds

## Implementation Steps

### 1. Enable App Check in Firebase Console
```bash
# Navigate to Firebase Console → App Check
# Enable for Android (Play Integrity)
# Enable for iOS (DeviceCheck)
# Generate debug tokens for development
```

### 2. Configure Flutter App
```dart
// lib/main.dart
import 'package:firebase_app_check/firebase_app_check.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Activate App Check
  await FirebaseAppCheck.instance.activate(
    // Android: Play Integrity
    androidProvider: AndroidProvider.playIntegrity,
    // iOS: DeviceCheck
    appleProvider: AppleProvider.deviceCheck,
    // Web: reCAPTCHA
    webRecaptchaSiteKey: 'your-site-key',
  );
  
  runApp(MyApp());
}
```

### 3. Configure Debug Tokens
```bash
# Generate debug token UUID
uuidgen

# Add to Firebase Console → App Check → Debug Tokens
# Set in emulator/local environment
```

### 4. Update Cloud Functions
```typescript
// functions/src/index.ts
// Add to ALL callable functions
.runWith({ 
  enforceAppCheck: true,
  consumeAppCheckToken: true 
})
```

### 5. Test in Staging
- Deploy functions with App Check enabled
- Test with debug token
- Verify rejection without token
- Test on real device (Android/iOS)

## Definition of Ready (DoR)
- [x] **A1** (Sign-in) working
- [x] Firebase project has App Check enabled
- [x] Debug tokens generated for development
- [x] Documentation reviewed (`docs/APP_CHECK.md`)
- [x] Performance impact acceptable (≤50ms)

## Definition of Done (DoD)
- [ ] App Check enabled in Firebase Console (Android + iOS)
- [ ] Flutter app configured with App Check providers
- [ ] All callable functions have `enforceAppCheck: true`
- [ ] Debug tokens configured for development
- [ ] Integration tests pass with debug token
- [ ] E2E test: release build calls protected function successfully
- [ ] Telemetry events wired for failures
- [ ] Documentation updated in `docs/APP_CHECK.md`
- [ ] Deployed to staging and verified
- [ ] Demo: call function without token → rejected, with token → succeeds
- [ ] Performance: verified ≤50ms overhead

## Notes

### Implementation Tips
- Always use debug tokens in development/staging, not production
- Play Integrity requires app to be published on Google Play (use internal testing track)
- DeviceCheck works automatically on iOS (no extra setup)
- Token replay protection: set `consumeAppCheckToken: true` to prevent reuse
- Monitor App Check metrics in Firebase Console

### Gotchas
- **Play Integrity**: App must be signed with same key as registered in Google Play
- **Debug Tokens**: Expire and must be regenerated (set expiry date)
- **Emulator**: Always requires debug token (Play Integrity doesn't work in emulator)
- **Error Messages**: App Check failures appear as "unauthenticated" to client (generic for security)

### Troubleshooting
```bash
# Common errors:
# "App Check token is invalid" → Check token expiry, regenerate debug token
# "Play Integrity not available" → App not published on Play Store internal track
# "DeviceCheck failed" → Real device required (simulator not supported)

# Verify App Check status
firebase appcheck:verify
```

### References
- [Firebase App Check Documentation](https://firebase.google.com/docs/app-check)
- [Play Integrity API](https://developer.android.com/google/play/integrity)
- [Apple DeviceCheck](https://developer.apple.com/documentation/devicecheck)
- [ADR-011: Story-Driven Development](../../adrs/011-story-driven-development.md)
- [docs/APP_CHECK.md](../../APP_CHECK.md)
