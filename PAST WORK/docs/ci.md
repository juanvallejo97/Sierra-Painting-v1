# CI gates
- Style: `flutter format --set-exit-if-changed .`
- Static analysis: `flutter analyze`
- Unit/Widget tests: `flutter test --concurrency=1 -r expanded`
- Firestore rules compile check via emulator bootstrap
- Functions guard enforces minInstances on hot endpoint

## PR Hygiene
- PR template is enforced.
- Conventional commits checked via commitlint.
- Auto-labels based on paths + size labels added.