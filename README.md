# D'Sierra Painting Application

### What is this?
A Flutter app (web + Android) with Firebase backend (Auth, Firestore, Functions), App Check, analytics, and perf tracing.

## Quickstart
```bash
flutter pub get
# Web
flutter run -d chrome
# Android (emulator running)
flutter run -d emulator-5554
```

## Environments
- `.env` (local dev)
- `.env.staging` (staging) — `APP_CHECK_ENFORCE=true`
- `.env.production` (prod) — `APP_CHECK_ENFORCE=true`

## Testing
- Widget tests (web parity): `flutter test --concurrency=1`
- Android integration: `flutter test integration_test -d <device>`

## Observability
- Firebase Analytics (screen + auth flow events)
- Firebase Performance (boot + first-frame traces)
- Crashlytics gated by user consent

## Docs Index
- `docs/architecture/overview.md`
- `docs/adr/` (architectural decisions)
- `docs/runbooks/` (oncall + incident)
- `docs/ci.md`, `docs/observability.md`, `docs/app_check.md`
