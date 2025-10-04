# Quality Checks Guide

This guide explains how to use the quality checking infrastructure in this repository.

## Quick Start

### Run Quality Checks Locally

```bash
# Run all quality checks
./scripts/quality.sh

# Apply auto-fixes first, then check
./scripts/quality.sh --fix

# Run with strict mode (treat infos as errors)
./scripts/quality.sh --fatal-infos
```

### Generate API Documentation

```bash
# Generate documentation
./scripts/generate-docs.sh

# View documentation
open docs/api/index.html
```

## What Gets Checked

### 1. Code Analysis (`dart analyze`)

Static analysis with strict linting rules:
- 130+ lint rules from `very_good_analysis`
- 14 additional strict rules (see `analysis_options.yaml`)
- Type safety, null safety, and best practices
- On release branches: treats infos as errors (`--fatal-infos`)

### 2. Code Metrics (`dart_code_metrics`)

Complexity and maintainability analysis:
- **Cyclomatic Complexity**: Max 20 per method
- **Number of Parameters**: Max 5 per method
- **Nesting Level**: Max 5 levels deep
- **Source Lines of Code**: Max 100 per file
- **Maintainability Index**: Min 50

### 3. Unused Code Detection

Scans for:
- Unused classes
- Unused methods
- Unused parameters
- Unused imports
- Unused variables

Report is generated but does not fail the build (to avoid false positives).

## CI/CD Integration

### Automatic Checks

Quality checks run automatically on:
- Every push to `main` or `release/**` branches
- Every pull request to `main` or `release/**`

### CI Behavior

**On Pull Requests:**
- Standard quality checks
- Generates unused code report
- Posts summary to PR comments

**On Release Branches:**
- Strict mode enabled (`--fatal-infos`)
- Fails on any lint warnings or infos
- Ensures highest quality for releases

### Viewing CI Results

1. Go to the "Actions" tab in GitHub
2. Click on your PR or commit
3. View "Code Quality & Lint Enforcement" job
4. Download "unused-code-report" artifact if available

## Configuration Files

### `analysis_options.yaml`
Main linting configuration:
- Extends `very_good_analysis`
- Defines lint rules
- Configures analyzer exclusions

### `analysis_options_metrics.yaml`
Metrics and complexity thresholds:
- Code metrics rules
- Complexity limits
- Style preferences

### `dartdoc_options.yaml`
Documentation generation settings:
- Include/exclude patterns
- Output directory
- Source code linking

## Scripts Reference

### `scripts/quality.sh`

**Options:**
- `--fix` - Apply automatic fixes before analyzing
- `--no-metrics` - Skip dart_code_metrics checks
- `--no-unused` - Skip unused code detection
- `--fatal-infos` - Treat infos as errors
- `--help` - Show help message

**Exit Codes:**
- `0` - All checks passed
- `1` - Analysis or metrics failed

### `scripts/generate-docs.sh`

Generates API documentation using `dart doc`.

**Output:** `docs/api/` (not committed to git)

## Workflow for Developers

### Before Committing

```bash
# Apply auto-fixes
./scripts/quality.sh --fix

# Review changes
git diff

# Run quality checks
./scripts/quality.sh
```

### Fixing Issues

**Automatic Fixes:**
```bash
dart fix --apply
```

**Manual Fixes:**
Review the output from `dart analyze` and fix issues one by one.

**Complexity Issues:**
If a method exceeds complexity threshold:
1. Break it into smaller methods
2. Extract complex logic into helper methods
3. Use early returns to reduce nesting

### Handling False Positives

**Unused Code:**
If legitimate code is flagged as unused:
- Verify it's actually used
- Add a comment explaining why it's kept
- Consider if it should be removed

**Lint Rules:**
To disable a specific rule for a line:
```dart
// ignore: rule_name
final value = someCode();
```

To disable for a file:
```dart
// ignore_for_file: rule_name
```

## Best Practices

1. **Run quality checks before every commit**
2. **Use `--fix` to apply automatic fixes**
3. **Keep complexity low** - aim for < 15 cyclomatic complexity
4. **Document public APIs** - helps with dart doc
5. **Review unused code reports** - clean up regularly
6. **Never disable lint rules** without good reason (and document why)

## Troubleshooting

### "dart_code_metrics not found"

The script will automatically install it. If you want to install manually:
```bash
dart pub global activate dart_code_metrics
```

### "Analysis failed"

1. Read the error messages carefully
2. Try applying auto-fixes: `./scripts/quality.sh --fix`
3. Fix remaining issues manually
4. Re-run quality checks

### "Too many issues"

Start with the most critical:
1. Errors (must fix)
2. Warnings (should fix)
3. Infos (nice to fix)

Use `dart fix --apply` to fix many issues automatically.

## Additional Resources

- [Effective Dart](https://dart.dev/guides/language/effective-dart)
- [Very Good Analysis](https://pub.dev/packages/very_good_analysis)
- [Dart Code Metrics](https://pub.dev/packages/dart_code_metrics)
- [Dart Doc Guide](https://dart.dev/tools/dart-doc)

## Updating Configuration

### Adding New Lint Rules

Edit `analysis_options.yaml`:
```yaml
linter:
  rules:
    your_new_rule: true
```

### Changing Complexity Thresholds

Edit `analysis_options_metrics.yaml`:
```yaml
dart_code_metrics:
  metrics:
    cyclomatic-complexity: 25  # Increase limit
```

### Excluding Files

Edit `analysis_options.yaml`:
```yaml
analyzer:
  exclude:
    - "lib/generated/**"
```

## Questions?

See `QUALITY_IMPLEMENTATION.md` for detailed implementation notes, or ask the team.
