# Run tests

This guide shows you how to run tests for Sierra Painting.

## Prerequisites

- Development environment set up (see [Getting started](../tutorials/getting-started.md))
- Firebase emulators installed

## Run Flutter tests

1. Run all Flutter tests:

   ```bash
   flutter test
   ```

   **Expected output**: Test results showing pass/fail status.

2. Run tests with coverage:

   ```bash
   flutter test --coverage
   ```

   Coverage report is generated in `coverage/lcov.info`.

## Run Cloud Functions tests

1. Navigate to functions directory:

   ```bash
   cd functions
   ```

2. Run unit tests:

   ```bash
   npm test
   ```

3. Run integration tests (requires emulators):

   ```bash
   # Terminal 1: Start emulators
   firebase emulators:start

   # Terminal 2: Run integration tests
   npm run test:integration
   ```

## Run Firestore rules tests

1. Start emulators in one terminal:

   ```bash
   firebase emulators:start
   ```

2. Run rules tests in another terminal:

   ```bash
   npm run test:rules
   ```

## Run quality checks

1. Run all quality checks:

   ```bash
   ./scripts/quality.sh
   ```

   This runs:
   - Flutter analyze
   - Dart code metrics
   - Unused code detection

2. Apply automatic fixes:

   ```bash
   ./scripts/quality.sh --fix
   ```

## Troubleshooting

**Tests fail with "Cannot connect to Firebase"**:

- Ensure emulators are running
- Check that ports 4000, 8080, 9099, 5001, 9199 are not in use

**"command not found" errors**:

- Run `flutter pub get` for Flutter dependencies
- Run `npm ci` in `functions/` for Node dependencies

## Next steps

- [Deploy to staging](deploy-staging.md)
- [View test coverage reports](view-coverage.md)
