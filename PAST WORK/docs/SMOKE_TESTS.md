# Smoke Tests

Fast, deterministic health checks to block bad releases before promotion.

## Overview

Smoke tests are **pre-promotion validation checks** that run in < 5 minutes to verify the app and backend are healthy before deploying to staging or production.

### What are Smoke Tests?

- **Fast**: Complete in ≤5 minutes
- **Deterministic**: No flaky tests, always pass/fail consistently
- **Blocking**: Failed smoke tests prevent promotions
- **Health-focused**: Basic "does it work?" checks, not comprehensive testing

### When do they run?

1. **On every PR** - Provides fast feedback before merge
2. **Before staging deployment** - Blocks bad code from reaching staging
3. **Before production deployment** - Final safety check before release

## Test Components

### 1. Mobile App Smoke Tests

**Location**: `integration_test/app_smoke_test.dart`

**What it tests**:
- App launches successfully
- First frame renders within performance budget (< 3s in CI)
- Can navigate to key screens without crashing
- Frame rendering stays within budget

**Performance metrics exported**:
- `app_startup_ms`: Time to first frame
- `app_startup_p90_ms`: P90 startup time (for trending)
- `frame_time_ms`: Single frame render time

**Running locally**:
```bash
flutter test integration_test/app_smoke_test.dart
```

### 2. Backend Health Check

**Location**: `functions/test/smoke/health_test.ts`

**What it tests**:
- `/healthCheck` endpoint returns 200 status
- Response includes `status`, `timestamp`, and `version`
- Response time < 50ms (target) or < 200ms (CI)
- Timestamp is valid ISO 8601 format

**Running locally**:
```bash
cd functions
npm test -- test/smoke/
```

## Workflow: `.github/workflows/smoke.yml`

The smoke test workflow orchestrates both mobile and backend tests.

### Jobs

1. **mobile_smoke**: Runs Flutter integration tests
2. **backend_smoke**: Runs backend health check tests
3. **smoke_summary**: Aggregates results and reports to PR

### Artifacts Generated

- `mobile-smoke-metrics`: Performance metrics from mobile tests
- `backend-health-report`: Health check results

### Success Criteria

✅ **Pass**: All tests pass, safe to promote
❌ **Fail**: Any test fails, blocks promotion

## Integration with CI/CD

### Staging Pipeline (`staging.yml`)

```yaml
smoke_tests:
  uses: ./.github/workflows/smoke.yml
  needs: [build_check_flutter, lint_and_test_functions]

deploy_indexes:
  needs: [smoke_tests, emulator_smoke]
```

Smoke tests must pass before deploying to staging.

### Production Pipeline (`production.yml`)

```yaml
smoke_tests:
  uses: ./.github/workflows/smoke.yml
  needs: [build_flutter_release, lint_and_test_functions]

deploy_indexes_production:
  needs: [smoke_tests]
```

Smoke tests are the **final gate** before production deployment.

## Performance Budgets

| Metric | Budget (Local) | Budget (CI) | Current |
|--------|---------------|-------------|---------|
| App Startup | 500ms | 3000ms | ✅ |
| Frame Time | 16ms | 100ms | ✅ |
| Health Check | 50ms | 200ms | ✅ |

## Debugging Failed Smoke Tests

### Mobile Test Failures

1. Check the workflow artifacts for `mobile-smoke-metrics`
2. Look for PERFORMANCE_METRIC logs in test output
3. Run locally: `flutter test integration_test/app_smoke_test.dart`

Common issues:
- App crashes on startup: Check main.dart initialization
- Timeout: App takes > 10s to settle, check for infinite loops
- Navigation fails: Expected UI elements not found

### Backend Test Failures

1. Check the workflow artifacts for `backend-health-report`
2. Review test output in the workflow logs
3. Run locally: `cd functions && npm test -- test/smoke/`

Common issues:
- Build failure: TypeScript compilation errors
- Import errors: Check function exports in `src/index.ts`
- Timeout: Function initialization taking too long

## Adding New Smoke Tests

### Mobile Tests

Edit `integration_test/app_smoke_test.dart`:

```dart
testWidgets('New critical flow works', (tester) async {
  app.main();
  await tester.pumpAndSettle();
  
  // Your test here
  expect(find.byType(SomeWidget), findsOneWidget);
});
```

Keep tests fast and focused on critical paths.

### Backend Tests

Create new test file in `functions/test/smoke/`:

```typescript
describe('New Feature Smoke Test', () => {
  it('should work', () => {
    // Your test here
    expect(true).toBe(true);
  });
});
```

## Rollback on Failure

If smoke tests fail in production pipeline:

1. **Automatic**: Deployment is blocked, no code reaches production
2. **Manual rollback**: If already at 10% canary, use:
   ```bash
   cd scripts/rollback
   ./rollback.sh
   ```

See [rollout-rollback.md](../docs/rollout-rollback.md) for details.

## Best Practices

### DO ✅

- Keep tests under 5 minutes total
- Test critical user paths only
- Export performance metrics
- Make tests deterministic (no randomness)
- Fail fast on critical issues

### DON'T ❌

- Add comprehensive feature tests (use unit/integration tests instead)
- Test edge cases (not the goal of smoke tests)
- Add tests that depend on external services
- Make tests flaky or timing-dependent
- Skip smoke tests to "move faster"

## Monitoring

Smoke test metrics are tracked in:
- GitHub Actions workflow artifacts
- PR comments (automated summary)
- Performance dashboard (planned)

## Related Documentation

- [Testing Strategy](../test/README.md)
- [Performance Budgets](../docs/PERFORMANCE_BUDGETS.md)
- [CI/CD Workflows](../.github/workflows/)
- [Rollout & Rollback](../docs/rollout-rollback.md)

## Troubleshooting

### "No tests found" error

- Check jest.config.js includes test directory
- Verify test file naming: `*.ts` for smoke tests
- Ensure test files are in `functions/test/smoke/`

### Flutter test hangs

- Increase timeout: `await tester.pumpAndSettle(Duration(seconds: 10))`
- Check for infinite animations
- Verify app.main() completes

### Smoke tests pass locally but fail in CI

- CI has stricter timeouts and less resources
- Check performance budgets are CI-appropriate
- Review workflow logs for environment differences

---

**Questions?** See the [main testing guide](../test/README.md) or open an issue.
