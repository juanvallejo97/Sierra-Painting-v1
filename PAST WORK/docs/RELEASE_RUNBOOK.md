# V1 Release Runbook
## Preconditions
- CI on `main` green for last commit.
- `Release Readiness Gate` workflow passed.
- Secrets set: FIREBASE_PROJECT_ID, FIREBASE_HOSTING_SITE.
## Staging
- Build locally: `flutter build web --release`
- Deploy with scripts using `--project` and `--site`.
- **Code Generation:** If dependencies changed, run:
  ```bash
  flutter pub run build_runner build --delete-conflicting-outputs
  ```
## Production
- Actions → **Release V1 (Manual)** → `tag = v1.0.0`, `build_android_aab = true|false`
## Verification
- Open `https://<site>.web.app` → 200, no console errors.
- Key flows: login, lead creation, Firestore writes.
## Rollback
- Use Hosting clone to previous version as documented in UPDATES_EXECUTION.md.
