Project-specific Copilot instructions — Sierra-Painting-v1

Summary
- Monorepo with a Flutter app (mobile + web) and Firebase backend.
- Key folders: `lib/` (Flutter app), `functions/` (Cloud Functions, TypeScript), `test/` and `integration_test/`, plus many ops scripts under `scripts/`.
- CI/deploy is gated: token/app-check validation must produce `logs/token_validation_log.txt` before automated deploys.

Quick architecture notes (big picture)
- Frontend: Flutter app under `lib/` with feature folders under `lib/features/*`. Routing uses `GoRouter` and Riverpod (`lib/app/router.dart`).
- Backend: Firebase services: Auth, Firestore, Storage, Cloud Functions (`functions/`), plus Firestore rules (`firestore.rules`) and indexes (`firestore.indexes.json`).
- Devops: `firebase.json` controls hosting, functions predeploy hooks; `scripts/validate_tokens.js` + `scripts/gate_and_deploy.js` implement a local gating and deploy flow.

Developer workflows & commands (source verified)
- Build web: `flutter build web --release` (script: `predeploy:web` in root `package.json`).
- Build functions: `npm --prefix functions run build` (script: `predeploy:functions`). Run `cd functions && npm install` first if dependencies change.
- Run functions tests: `cd functions && npm test` (Jest) — tests exist under `src/test` and `test/`.
- Lint & static check: `flutter analyze` for dart; `cd functions && npm run lint` for functions.
- Validation / gated deploy (local):
  - `node scripts/validate_tokens.js` — starts a local static server and uses Puppeteer to validate App Check / ID tokens and writes `logs/token_validation_log.txt`.
  - `node scripts/gate_and_deploy.js` — reads `logs/token_validation_log.txt` and runs `firebase deploy` non-interactively. It prefers `GOOGLE_APPLICATION_CREDENTIALS` (ADC) and falls back to `FIREBASE_TOKEN`.

Project conventions & patterns
- Environment: `.env` is used locally (see `.env.example`). Do not commit `.env` with secrets. `loadEnv.mjs` and `validate_tokens.js` will load `.env` when present.
- Service accounts & CI: CI should use a service-account JSON stored as a secret (recommended) and set `GOOGLE_APPLICATION_CREDENTIALS` in the environment. The repo has helpers to accept ADC.
- Tests: Firestore security rules live tests under `tests/rules/` and `firestore-tests/` — CI gates require these to pass.
- Predeploy hooks: `package.json` wires `predeploy:web` → Flutter web build and `predeploy:functions` → functions build. `firebase.json` calls those before deploy.

Files to inspect for context when changing areas
- Routing / auth flow: `lib/app/router.dart`, `core/providers/auth_provider.dart`, `app/app.dart`.
- Functions: `functions/src/` and `functions/test/` for implementation and tests.
- Deploy tooling: `scripts/validate_tokens.js`, `scripts/gate_and_deploy.js`, `scripts/run_preflight_local.ps1`.
- CI workflows: `.github/workflows/*` (validator and deploy workflows reference `logs/token_validation_log.txt`).

Quick rules for AI-coded changes
- Preserve gating behaviour: do not remove `validate_tokens.js` or the requirement for `logs/token_validation_log.txt` unless you update the gating logic in `scripts/gate_and_deploy.js` and CI workflows.
- When modifying `functions/package.json`, run `npm install` in `functions/` and run tests; commit the updated `package-lock.json`.
- When touching Flutter web output or assets, update `firebase.json` rewrites/headers when needed and run `flutter build web --release` locally to produce `build/web`.

If you need more context
- Start with: `README.md`, `DEPLOYMENT_INSTRUCTIONS.md`, `ARCHITECTURE.md`, and `instructions.yaml` (project goals & risks).
- For infra changes, check `firebase.json`, `firestore.rules`, and `firestore.indexes.json`.

Deliverable expectations for PRs made by an AI
- Small, focused commits (per `instructions.yaml` governance). Include: changed files, updated build/test commands, updated lockfiles, and a short checklist proving local validation (e.g., `flutter analyze` ran, `functions tests` green, `node scripts/validate_tokens.js` produced `logs/token_validation_log.txt`).

Questions for reviewer (leave in PR body)
- Does this change affect the canonical web target (we have `web/`, `web_react/`, `webapp/`)?
- Are there any additional CI secrets/keys that must be rotated after this change?

If this file already existed, merge its specific rules into the above rather than overriding them.

End of copilot-instructions.md
