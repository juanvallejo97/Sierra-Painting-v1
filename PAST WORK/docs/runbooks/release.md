# Release Runbook (Android + Web)
## Android
- Bump version in `pubspec.yaml`
- `flutter build appbundle --release`
- Upload to Play Console (internal track)
## Web
- `flutter build web --release --web-renderer html`
- Host on Firebase Hosting or your CDN
## Post-Release
- Verify Perf traces + Analytics
- Check Crashlytics signals and App Check token rates