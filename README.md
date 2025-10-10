# D'Sierra Painting Application

### What is this?
<<<<<<< HEAD
A Flutter app (web + Android) with Firebase backend (Auth, Firestore, Functions), App Check, analytics, and perf tracing.

## Quickstart
=======

A Flutter app (web + Android) with Firebase backend (Auth, Firestore, Functions), App Check,
analytics, and perf tracing.

## Quickstart

>>>>>>> feat/auth-foundation-day1
```bash
flutter pub get
# Web
flutter run -d chrome
# Android (emulator running)
flutter run -d emulator-5554
```

## Environments
<<<<<<< HEAD
=======

>>>>>>> feat/auth-foundation-day1
- `.env` (local dev)
- `.env.staging` (staging) — `APP_CHECK_ENFORCE=true`
- `.env.production` (prod) — `APP_CHECK_ENFORCE=true`

<<<<<<< HEAD
## Testing
- Widget tests (web parity): `flutter test --concurrency=1`
- Android integration: `flutter test integration_test -d <device>`

## Observability
=======
## Tests

    ```powershell
    pwsh -NoProfile -File scripts/run_integration_with_emulators.ps1
    ```
    or see CI job `integration-tests`.

## Tests

- **Widget tests (no Firebase/platform):**
  ```powershell
  pwsh -NoProfile -File scripts/run_test_local_temp.ps1 -TestPath test
  ```
  Use fakes (e.g., `fake_cloud_firestore`) as needed.
- **Integration tests (Firebase Emulators):**
  ```powershell
  pwsh -NoProfile -File scripts/run_integration_with_emulators.ps1
  ```
  Emulators: Firestore 8080, Functions 5001, Auth 9099, Storage 9199.

## Observability

>>>>>>> feat/auth-foundation-day1
- Firebase Analytics (screen + auth flow events)
- Firebase Performance (boot + first-frame traces)
- Crashlytics gated by user consent

## Docs Index
<<<<<<< HEAD
=======

>>>>>>> feat/auth-foundation-day1
- `docs/architecture/overview.md`
- `docs/adr/` (architectural decisions)
- `docs/runbooks/` (oncall + incident)
- `docs/ci.md`, `docs/observability.md`, `docs/app_check.md`
