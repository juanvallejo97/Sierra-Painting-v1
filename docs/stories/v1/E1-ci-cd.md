# E1: CI/CD Gates

**Epic**: E (Operations & Observability) | **Priority**: P0 | **Sprint**: V1 | **Est**: M | **Risk**: L

## User Story
As a Developer, I WANT automated CI/CD gates, SO THAT broken code doesn't get deployed.

## Dependencies
- None (foundation story)

## Acceptance Criteria (BDD)

### Success Scenario: PR Validation
**GIVEN** I open a pull request  
**WHEN** CI pipeline runs  
**THEN** all checks pass: lint, format, build, tests  
**AND** PR is marked as "ready to merge"

### Success Scenario: Automated Deploy to Staging
**GIVEN** code is merged to main branch  
**WHEN** CI pipeline runs  
**THEN** Firestore rules are deployed to staging  
**AND** Cloud Functions are deployed to staging  
**AND** deployment status is reported in Slack/email

### Edge Case: Linting Failure
**GIVEN** I push code with linting errors  
**WHEN** CI pipeline runs  
**THEN** lint check fails  
**AND** PR is blocked from merging  
**AND** error details are shown in PR

### Edge Case: Test Failure
**GIVEN** I push code that breaks a test  
**WHEN** CI pipeline runs  
**THEN** test check fails  
**AND** PR is blocked from merging  
**AND** failing test name is shown

### Performance
- **Target**: CI pipeline completes in P95 ≤ 5 minutes
- **Metric**: Time from push to all checks complete

## CI/CD Pipeline

### GitHub Actions Workflow
```yaml
# .github/workflows/ci.yml
name: CI/CD

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  lint-flutter:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter analyze
      - run: dart format --output=none --set-exit-if-changed .

  test-flutter:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test

  lint-functions:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: functions
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 18
      - run: npm ci
      - run: npm run lint
      - run: npm run format:check

  test-functions:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: functions
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
      - run: npm ci
      - run: npm test

  deploy-staging:
    if: github.ref == 'refs/heads/main'
    needs: [lint-flutter, test-flutter, lint-functions, test-functions]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
          projectId: sierra-painting-staging
          channelId: live
```

## Definition of Done (DoD)
- [ ] GitHub Actions workflow created
- [ ] Flutter lint check working
- [ ] Flutter test check working
- [ ] Functions lint check working
- [ ] Functions test check working
- [ ] Automated deploy to staging on merge
- [ ] Branch protection rules enabled (require checks to pass)
- [ ] Demo: push PR → see checks run → merge → auto-deploy

## Notes

### Implementation Tips
- Use branch protection rules to require CI checks before merge
- Cache dependencies to speed up CI (Flutter pub cache, npm cache)
- Run tests in parallel when possible
- Set timeout limits to prevent hung jobs

### References
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Flutter CI/CD Guide](https://docs.flutter.dev/deployment/cd)
- [Firebase CI/CD](https://firebase.google.com/docs/cli#cli-ci-systems)
