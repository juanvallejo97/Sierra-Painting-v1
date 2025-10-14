# App Check debug token: quick runbook

This page explains how to generate and register an App Check debug token for CI runs.

1. Local generate (dev machine or CI interactive run):
   - Open the browser to the tokens page: `http://localhost:3000/scripts/tokens.html?debug=true&email=...&pass=...`
   - Open DevTools Console; the Firebase App Check SDK prints a debug token value when in debug mode. Copy it.

2. Register the debug token in Firebase Console:
   - Go to Firebase Console → App Check → Your Web App → Debug tokens.
   - Add the copied token as a new debug token.

3. In CI:
   - Set a secret `APP_CHECK_DEBUG_TOKEN` with the debug token value or use the `--appcheck-debug` runner flag.
   - The validator will inject the debug token before the page loads and the SDK will accept it.

Notes:
- Debug tokens bypass reCAPTCHA enforcement for App Check; use them only in CI or development.
- If you need stable CI, prefer registering a reCAPTCHA site key that allows the CI host origins.
