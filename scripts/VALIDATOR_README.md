# Validator & Emulator helpers (local)

This file documents the helper scripts used to validate Firebase ID tokens and App Check tokens locally and how to run them safely on Windows (PowerShell).

Important safety rules
- Never commit secrets. Put credentials into the repository root `.env` which is ignored by Git.
- Generated files such as `scripts/firebase_config.json`, `logs/`, and `reports/` are intentionally ignored.

Quick PowerShell workflow

1. Generate a local firebase config from your `.env` (writes `scripts/firebase_config.json`):

```powershell
node scripts/generate_firebase_config.js
```

2. Start the Firebase Auth emulator (foreground):

```powershell
npx firebase emulators:start --only auth
```

3. In another terminal, populate the emulator with the test user (reads `TEST_EMAIL` / `TEST_PASS` from `.env`):

```powershell
node scripts/create_user.js
```

4. Run the validator using the included runner (it loads `.env` via `scripts/loadEnv.mjs`):

```powershell
# Run the validator against the local server port (example 61435)
node scripts/validate_runner.js --port=61435 --debug=true --headless=new
```

Notes
- If you want the validator to run against a hosted site (not emulator), set `RECAPTCHA_SITE_KEY` in `.env` or provide `APP_CHECK_DEBUG_TOKEN` as a secret in CI.
- CI: set secrets `TEST_EMAIL`, `TEST_PASS`, and `APP_CHECK_DEBUG_TOKEN` (or `RECAPTCHA_SITE_KEY`) in your repository secrets instead of placing them in `.env`.
- The generator reads `.env` at runtime — do not commit the generated `scripts/firebase_config.json`.

Files intentionally ignored
- `scripts/firebase_config.json` — generated local config
- `firebase_config.json` (root) — generated
- `logs/` and `reports/` — validator artifacts

If you want, I can add a short convenience npm script to `package.json` to run these steps in sequence (emulator start / create user / validate) for local dev. Let me know if you'd like that.
