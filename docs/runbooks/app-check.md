# App Check — Dev & Prod

## Dev (Web)

Enable debug token in `index.html`:

```html
<script>window.FIREBASE_APPCHECK_DEBUG_TOKEN = true;</script>
```

Use reCAPTCHA v3 site key for non-debug dev if desired.

## Mobile

- **Android**: Play Integrity (preferred) or SafetyNet (legacy)
- **iOS**: App Attest / DeviceCheck

## Cloud Functions (Callable)

In production, reject requests with missing/invalid App Check.

Toggle via environment: `ENFORCE_APPCHECK=true` (Functions env).

## Emulator

App Check relaxed by default. Keep enforcement off for local.

## Troubleshooting

**Error**: `failed-precondition: AppCheck required`

**Solution**: Ensure debug token/script present (web) or provider configured (mobile).

## Production Deployment

1. Set environment variable:
   ```bash
   firebase functions:config:set appcheck.enforce=true
   ```

2. Deploy functions:
   ```bash
   firebase deploy --only functions
   ```

3. Verify in Firebase Console → App Check → Apps

## Rollback Plan

If App Check blocks legitimate traffic:

1. Disable enforcement:
   ```bash
   firebase functions:config:unset appcheck.enforce
   firebase deploy --only functions
   ```

2. Investigate client configuration
3. Re-enable once fixed

## References

- [Firebase App Check Documentation](https://firebase.google.com/docs/app-check)
- [Debug Tokens](https://firebase.google.com/docs/app-check/web/debug-provider)
