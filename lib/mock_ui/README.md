# Mock UI Playground

This directory contains a standalone UI playground for rapid prototyping and component development.

## Purpose

The Mock UI playground provides:
- Isolated environment for UI experimentation
- Widget demonstrations (Widget Zoo, Theme Lab)
- Component prototypes and design iterations
- Development-only tools and utilities

## Running the Playground

```bash
# Run the mock UI playground (debug mode only)
flutter run -t lib/mock_ui/main_playground.dart
```

## Release Mode Protection

The playground is **gated behind `kReleaseMode`** checks:
- `lib/mock_ui/main_playground.dart` throws an error in release mode
- This prevents accidental inclusion in production builds
- All mock UI code is isolated in `lib/mock_ui/` directory
- No production code imports from `mock_ui/`

## Debug Output

- `debugPrint` statements are used throughout mock UI code
- Flutter **automatically strips `debugPrint` in release mode** (no-op)
- No need for custom logger replacement - built-in behavior is sufficient
- Debug code is automatically removed from release builds by Flutter tooling

## Architecture

```
lib/mock_ui/
├── main_playground.dart    # Entry point (gated with kReleaseMode)
├── app.shell.dart           # Playground app shell
├── router.dart              # Mock route definitions
├── components/              # Reusable mock components
├── screens/                 # Demo screens (Widget Zoo, Theme Lab, etc.)
├── fakers.dart              # Mock data generators
└── demo_state.dart          # Playground state management
```

## Safety Guarantees

1. ✅ **Entry point gated**: `main_playground.dart` throws error in release mode
2. ✅ **Code isolation**: No imports from `mock_ui/` in production code
3. ✅ **Auto tree-shaking**: Unused code automatically removed by Flutter
4. ✅ **Debug stripping**: `debugPrint` automatically becomes no-op in release
5. ✅ **Separate entry**: Uses `-t lib/mock_ui/main_playground.dart`, not default main

## Note

While the mock UI is already safe through architectural isolation, the explicit `kReleaseMode` gate in `main_playground.dart` provides an additional safety layer and makes the development-only intent explicit.
