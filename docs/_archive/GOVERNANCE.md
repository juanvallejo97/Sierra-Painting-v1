# Recommendations for Future Governance

## Overview

This document provides actionable recommendations for maintaining code quality, consistency, and best practices in the Sierra Painting v1 project going forward.

---

## 1. Pre-commit Hooks

### Setup Instructions

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash

echo "Running pre-commit checks..."

# Check Flutter formatting
echo "Checking Flutter code formatting..."
flutter format --set-exit-if-changed lib/ test/
if [ $? -ne 0 ]; then
  echo "❌ Flutter formatting check failed. Run 'flutter format lib/ test/' to fix."
  exit 1
fi

# Run Flutter analyzer
echo "Running Flutter analyzer..."
flutter analyze
if [ $? -ne 0 ]; then
  echo "❌ Flutter analysis failed. Fix errors before committing."
  exit 1
fi

# Check TypeScript formatting (if functions changed)
if git diff --cached --name-only | grep -q "^functions/"; then
  echo "Checking TypeScript code..."
  cd functions
  npm run lint
  if [ $? -ne 0 ]; then
    echo "❌ TypeScript lint failed. Run 'npm run lint --fix' to fix."
    exit 1
  fi
  npm run typecheck
  if [ $? -ne 0 ]; then
    echo "❌ TypeScript type checking failed."
    exit 1
  fi
  cd ..
fi

echo "✅ All pre-commit checks passed!"
exit 0
```

Make it executable:
```bash
chmod +x .git/hooks/pre-commit
```

### Alternative: Using Husky

Add to `package.json`:
```json
{
  "scripts": {
    "prepare": "husky install"
  },
  "devDependencies": {
    "husky": "^8.0.0"
  }
}
```

Create `.husky/pre-commit`:
```bash
#!/bin/sh
. "$(dirname "$0")/_/husky.sh"

flutter format --set-exit-if-changed lib/ test/
flutter analyze
cd functions && npm run lint && npm run typecheck
```

---

## 2. CI/CD Enhancements

### Current State
- ✅ `.github/workflows/ci.yml` exists
- ✅ Runs Flutter and Functions checks
- ✅ `.github/workflows/governance.yml` - Project governance & PR conflict resolver

### Project Governance Workflow

The governance workflow (`.github/workflows/governance.yml`) automates conflict resolution and enforces quality standards for multiple PRs.

**Usage:**
1. Go to Actions → Project Governance & PR Conflict Resolver
2. Click "Run workflow"
3. Enter comma-separated PR numbers (e.g., `123,124,125`)
4. Specify base branch (default: `main`)
5. Click "Run workflow"

**What it does:**
- Runs quality gates (lint, typecheck, test, build)
- Checks each PR for merge conflicts
- Posts detailed comments on PRs with:
  - ✅ Conflict status
  - 📝 Resolution instructions
  - 📊 Quality gate results
- Generates summary report

**Project Phases Enforced:**
- **Phase 3:** Functional Hardening (>= 90% test coverage)
- **Phase 4:** Final Documentation (README, CHANGELOG, ADRs)
- **Phase 5:** CI/CD & Ship Checks (green CI, signed tags)

### Recommended Additions

#### Add Format Check to CI

```yaml
# In .github/workflows/ci.yml
- name: Check Flutter formatting
  run: dart format --set-exit-if-changed lib/ test/
  
- name: Check TypeScript formatting
  working-directory: functions
  run: npm run format:check  # Add this script to package.json
```

#### Add Test Coverage Reporting

```yaml
# Add after tests
- name: Run Flutter tests with coverage
  run: flutter test --coverage

- name: Upload coverage to Codecov
  uses: codecov/codecov-action@v3
  with:
    files: ./coverage/lcov.info
    fail_ci_if_error: false
```

#### Add Dependency Security Scanning

```yaml
# Add new job
security:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v3
    
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        scan-ref: '.'
        format: 'sarif'
        output: 'trivy-results.sarif'
        
    - name: Upload Trivy results to GitHub Security tab
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results.sarif'
```

---

## 3. Code Review Checklist

### For All Pull Requests

#### Code Quality
- [ ] Code follows existing patterns and conventions
- [ ] No hardcoded secrets or sensitive data
- [ ] Imports are properly ordered (dart, package, relative)
- [ ] All new files have comprehensive headers (PURPOSE, FEATURES, etc.)
- [ ] Complex logic includes inline comments
- [ ] No commented-out code (remove or add TODO with context)

#### Testing
- [ ] New features have unit tests
- [ ] Modified features have updated tests
- [ ] All tests pass locally
- [ ] Edge cases are considered and tested

#### Documentation
- [ ] README updated if needed
- [ ] API documentation updated if needed
- [ ] Migration guide updated for breaking changes
- [ ] TODOs include context and tracking info

#### Performance
- [ ] No obvious performance issues
- [ ] Large lists use lazy loading
- [ ] Images are optimized
- [ ] Database queries are efficient

#### Security
- [ ] User inputs are validated
- [ ] Authentication/authorization checks in place
- [ ] No SQL injection or XSS vulnerabilities
- [ ] Sensitive operations are logged

---

## 4. Lint Rules Enhancements

### Dart/Flutter (analysis_options.yaml)

Consider adding these additional rules:

```yaml
linter:
  rules:
    # Additional strict rules
    prefer_final_parameters: true
    require_trailing_commas: true
    use_build_context_synchronously: true
    use_colored_box: true
    use_decorated_box: true
    
    # Prevent common mistakes
    avoid_dynamic_calls: true
    avoid_type_to_string: true
    cast_nullable_to_non_nullable: true
    deprecated_member_use_from_same_package: true
    no_adjacent_strings_in_list: true
    no_self_assignments: true
    no_wildcard_variable_uses: true
    prefer_void_to_null: true
    unnecessary_null_checks: true
    
    # Documentation
    public_member_api_docs: false  # Enable when ready
    package_api_docs: false
```

### TypeScript (.eslintrc.js)

Current configuration is excellent. Consider adding:

```javascript
rules: {
  // Enforce consistent brace style
  'brace-style': ['error', '1tbs'],
  
  // Enforce trailing commas (helps with git diffs)
  'comma-dangle': ['error', 'always-multiline'],
  
  // Prefer const over let
  'prefer-const': 'error',
  
  // Enforce consistent spacing
  'object-curly-spacing': ['error', 'always'],
  'array-bracket-spacing': ['error', 'never'],
}
```

---

## 5. Testing Strategy

### Current Coverage (Estimated)

| Layer | Coverage | Target |
|-------|----------|--------|
| Unit Tests | ~20% | 80% |
| Widget Tests | ~10% | 60% |
| Integration Tests | ~5% | 40% |
| E2E Tests | ~0% | 20% |

### Recommended Testing Plan

#### Phase 1: Core Services (Priority: High)
```dart
// Test files to create:
test/core/services/queue_service_test.dart
test/core/services/offline_service_test.dart
test/core/services/feature_flag_service_test.dart
test/core/network/api_client_test.dart
test/core/utils/result_test.dart ✅ (already exists)
```

#### Phase 2: Repositories (Priority: High)
```dart
test/features/timeclock/data/timeclock_repository_test.dart
test/features/auth/data/auth_repository_test.dart (create)
```

#### Phase 3: Widget Tests (Priority: Medium)
```dart
test/features/auth/presentation/login_screen_test.dart
test/features/timeclock/presentation/timeclock_screen_test.dart
test/core/widgets/error_screen_test.dart
test/design/components/app_button_test.dart
```

#### Phase 4: Integration Tests (Priority: Medium)
```dart
integration_test/auth_flow_test.dart
integration_test/clock_in_out_flow_test.dart
integration_test/offline_sync_test.dart
```

### Test Templates

#### Unit Test Template
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Mocks
class MockDependency extends Mock implements Dependency {}

void main() {
  late ServiceUnderTest service;
  late MockDependency mockDependency;

  setUp(() {
    mockDependency = MockDependency();
    service = ServiceUnderTest(mockDependency);
  });

  group('ServiceUnderTest', () {
    test('should do something when condition is met', () async {
      // Arrange
      when(() => mockDependency.method()).thenAnswer((_) async => result);

      // Act
      final result = await service.methodUnderTest();

      // Assert
      expect(result, expectedValue);
      verify(() => mockDependency.method()).called(1);
    });
  });
}
```

#### Widget Test Template
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('WidgetUnderTest displays correctly', (tester) async {
    // Arrange
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: WidgetUnderTest(),
        ),
      ),
    );

    // Act
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('Expected Text'), findsOneWidget);
    expect(find.byType(ExpectedWidget), findsOneWidget);
  });
}
```

---

## 6. Documentation Standards

### File Header Template (Mandatory for New Files)

```dart
/// [Component/Service/Widget Name]
///
/// PURPOSE:
/// [Clear, one-sentence description of what this file does]
///
/// RESPONSIBILITIES:
/// - [Key responsibility 1]
/// - [Key responsibility 2]
/// - [Key responsibility 3]
///
/// FEATURES: (optional)
/// - [Feature 1]
/// - [Feature 2]
///
/// USAGE:
/// ```dart
/// // Example code showing how to use this
/// final service = MyService();
/// await service.doSomething();
/// ```
///
/// ARCHITECTURE: (optional, for complex files)
/// [Explanation of design patterns, dependencies, etc.]
///
/// INVARIANTS: (optional, for critical logic)
/// - [Invariant 1: This must always be true]
/// - [Invariant 2: This must always be true]
///
/// TODO: (optional)
/// - [ ] [Specific actionable item with context]
import 'package:...';
```

### Public API Documentation

```dart
/// Does something important with the given [parameter].
///
/// Returns a [Result] containing either:
/// - Success: The processed data
/// - Failure: An error message
///
/// Throws:
/// - [ArgumentError] if parameter is invalid
/// - [StateError] if service not initialized
///
/// Example:
/// ```dart
/// final result = await service.doSomething('value');
/// if (result.isSuccess) {
///   print('Success: ${result.value}');
/// }
/// ```
Future<Result<Data, String>> doSomething(String parameter) async {
  // Implementation
}
```

---

## 7. Monitoring & Observability

### Complete Firebase Integration

Priority: **High**

Complete the TODOs in:
- `lib/core/telemetry/telemetry_service.dart`
- `lib/core/telemetry/performance_monitor.dart`
- `lib/core/telemetry/error_tracker.dart`

### Set Up Dashboards

1. **Firebase Console**
   - Crashlytics: Error tracking
   - Performance: Screen load times
   - Analytics: User behavior

2. **Custom Metrics**
   ```dart
   // Track key business metrics
   telemetryService.logEvent('clock_in', {
     'duration_minutes': duration,
     'job_id': jobId,
     'offline': isOffline,
   });
   ```

3. **Alerts**
   - Set up alerts for:
     - Error rate > 5%
     - P95 latency > 2s
     - Offline queue > 50 items
     - Failed sync attempts

---

## 8. Security Best Practices

### Authentication & Authorization

1. **Migrate from Email-based Admin Check**
   ```dart
   // Current (less secure)
   final isAdmin = user?.email?.contains('admin') ?? false;
   
   // Recommended (use custom claims)
   final idTokenResult = await user?.getIdTokenResult();
   final isAdmin = idTokenResult?.claims?['admin'] == true;
   ```

2. **Implement Custom Claims in Cloud Functions**
   ```typescript
   // Set admin claim
   await admin.auth().setCustomUserClaims(uid, { admin: true, role: 'admin' });
   ```

### Input Validation

1. **Always Validate on Server**
   - Client validation is UX, not security
   - Use Zod schemas in Cloud Functions ✅ (already doing this)

2. **Sanitize User Inputs**
   ```dart
   // Trim and validate
   final sanitized = value.trim();
   if (sanitized.isEmpty) return 'Required';
   ```

### Rate Limiting

Implement for public endpoints:

```typescript
// Use Firebase Extensions: Rate Limiting
// Or implement custom:
const rateLimiter = new Map<string, number>();

async function checkRateLimit(ip: string): Promise<boolean> {
  const now = Date.now();
  const lastRequest = rateLimiter.get(ip) || 0;
  
  if (now - lastRequest < 1000) { // 1 request per second
    return false;
  }
  
  rateLimiter.set(ip, now);
  return true;
}
```

---

## 9. Performance Optimization

### Flutter App

1. **Image Optimization**
   ```dart
   // Use cached_network_image
   CachedNetworkImage(
     imageUrl: url,
     placeholder: (context, url) => AppSkeleton.card(),
     errorWidget: (context, url, error) => Icon(Icons.error),
   )
   ```

2. **List Performance**
   ```dart
   // Use ListView.builder for large lists
   ListView.builder(
     itemCount: items.length,
     itemBuilder: (context, index) => ItemTile(items[index]),
   )
   ```

3. **Build Optimization**
   ```dart
   // Extract expensive widgets
   class _ExpensiveWidget extends StatelessWidget {
     const _ExpensiveWidget({Key? key}) : super(key: key);
     // ...
   }
   ```

### Cloud Functions

1. **Cold Start Optimization**
   ```typescript
   // Keep functions warm (if needed)
   // Use Cloud Scheduler to ping functions every 5 minutes
   
   // Minimize dependencies
   // Import only what you need
   import { getFunctions } from 'firebase-admin/functions';
   ```

2. **Database Query Optimization**
   ```typescript
   // Use indexes
   // Limit query results
   const query = db.collection('items')
     .where('orgId', '==', orgId)
     .limit(100);
   ```

---

## 10. Version Control Best Practices

### Branch Naming

```
feature/TICKET-123-add-payment-flow
bugfix/TICKET-456-fix-clock-in-validation
hotfix/TICKET-789-critical-auth-issue
chore/update-dependencies
docs/add-testing-guide
```

### Commit Messages

Follow Conventional Commits:

```
feat(auth): add password reset functionality
fix(timeclock): resolve clock-in validation error
docs(api): update API documentation for payments
chore(deps): update Flutter to 3.24.0
test(queue): add unit tests for queue service
refactor(theme): consolidate theme configuration
perf(images): add image caching
style(format): run dart format on all files
```

### Pull Request Template

```markdown
## Description
[Clear description of what this PR does]

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update
- [ ] Refactoring
- [ ] Performance improvement

## Testing
- [ ] Unit tests added/updated
- [ ] Widget tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing performed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No breaking changes (or documented)
- [ ] All tests pass
- [ ] No console errors or warnings

## Screenshots (if applicable)
[Add screenshots for UI changes]

## Related Issues
Closes #123
```

---

## 11. Dependency Management

### Flutter Dependencies

```bash
# Regular update checks (monthly)
flutter pub outdated

# Update dependencies
flutter pub upgrade

# Check for breaking changes
flutter pub upgrade --major-versions
```

### NPM Dependencies

```bash
# Check for outdated packages
cd functions && npm outdated

# Update to safe versions
npm update

# Update to latest (carefully)
npm install package@latest
```

### Security Audits

```bash
# Flutter
flutter pub get
# Check for known vulnerabilities manually

# NPM
cd functions && npm audit
npm audit fix
```

---

## 12. Rollout Strategy

### Feature Flags (Already in Place ✅)

Continue using Firebase Remote Config for:
- Gradual rollouts
- A/B testing
- Emergency killswitches

```dart
// Check flag before showing feature
final enabled = ref.watch(featureFlagProvider('new_feature'));
if (enabled) {
  // Show new feature
}
```

### Staged Rollout

1. **Dev**: Test in development
2. **Staging**: QA testing with production-like data
3. **Canary**: 5% of users
4. **Production**: Gradual rollout to 100%

---

## 13. Incident Response

### When Things Go Wrong

1. **Immediate Actions**
   - Roll back to last known good version
   - Disable problematic feature via Remote Config
   - Post incident update to team

2. **Investigation**
   - Check Firebase Crashlytics
   - Review logs in Cloud Functions
   - Check error rates in Analytics

3. **Resolution**
   - Fix the issue
   - Add tests to prevent regression
   - Update documentation

4. **Post-Mortem**
   - Document what happened
   - What went wrong
   - How to prevent in future
   - Action items

---

## 14. Quarterly Maintenance

### Every 3 Months

- [ ] Review and update dependencies
- [ ] Security audit
- [ ] Performance review
- [ ] Documentation review
- [ ] Test coverage review
- [ ] Clean up stale TODOs
- [ ] Review and update ADRs
- [ ] Code quality audit (like this one)

---

## Conclusion

Following these recommendations will help maintain the high code quality demonstrated in this codebase. The key is consistency and automation - let tools do the heavy lifting while developers focus on delivering value.

**Key Takeaways:**
1. Automate quality checks (pre-commit hooks, CI/CD)
2. Maintain comprehensive documentation
3. Keep test coverage high
4. Monitor production actively
5. Regular maintenance and updates

---

*For questions or suggestions, please open an issue or discussion on GitHub.*
