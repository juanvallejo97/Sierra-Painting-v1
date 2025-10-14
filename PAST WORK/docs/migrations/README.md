# Migration Guide Template

## Change summary

Brief overview of what's changing and why.

## Affected packages

List the packages being updated and their version changes.

## Required code changes

Detailed steps for migrating code:

**Before:**
```dart
// Old code example
```

**After:**
```dart
// New code example
```

## Backward compatibility / feature flags

Describe any backward compatibility concerns or feature flags needed.

## Rollback steps

1. Revert commit: `git revert <commit-hash>`
2. Redeploy: `firebase deploy`
3. Verify: check monitoring dashboards

## Verification checklist

- [ ] All tests pass
- [ ] No new errors in logs
- [ ] Performance metrics stable
- [ ] User-facing features work
