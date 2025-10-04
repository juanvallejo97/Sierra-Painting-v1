# Branch Protection Configuration

## Overview

This document outlines the branch protection rules and policies for the Sierra Painting v1 repository to ensure code quality, security, and linear history.

## Branch Protection Rules

### Main Branch (`main`)

#### Required Status Checks
All the following checks must pass before merging:

1. **Code Quality & Lint Enforcement** (`analyze` job)
   - Flutter analyze
   - Functions lint
   - WebApp lint

2. **Analyze and Test Flutter** (`test` job)
   - Unit tests
   - Coverage requirements

3. **Firestore Rules Tests** (`rules-test` job)
   - Security rules validation
   - Emulator-based testing

4. **Functions Integration Tests** (`functions-test` job)
   - Cloud Functions testing
   - Integration validation

5. **Build Checks** (`build` job)
   - Android build validation
   - iOS lint/build checks
   - Web build validation

6. **Web Bundle Size Budget** (`build-web-budget` job)
   - Bundle size within limits (10MB max)

#### Other Protection Settings

- **Require pull request reviews**: 1 approval required
- **Dismiss stale reviews**: Enabled when new commits are pushed
- **Require review from code owners**: Optional (recommended for large teams)
- **Require branches to be up to date**: Enabled (ensures no stale changes)
- **Require linear history**: Enabled (squash or rebase merging only)
- **Require signed commits**: Optional (recommended for security-critical projects)
- **Include administrators**: Enabled (admins must follow rules)
- **Allow force pushes**: Disabled
- **Allow deletions**: Disabled

### Configuration in GitHub

To configure these settings in GitHub:

1. Go to **Settings** > **Branches**
2. Add rule for branch name pattern: `main`
3. Enable the following:
   - ✅ Require a pull request before merging
   - ✅ Require approvals (1)
   - ✅ Dismiss stale pull request approvals when new commits are pushed
   - ✅ Require status checks to pass before merging
   - ✅ Require branches to be up to date before merging
   - ✅ Require linear history
   - ⚠️ Require signed commits (optional)
   - ✅ Include administrators
   - ✅ Do not allow bypassing the above settings

4. Add required status checks:
   - `Analyze Code (flutter)`
   - `Analyze Code (functions)`
   - `Analyze Code (webapp)`
   - `Run Tests (flutter)`
   - `Run Tests (functions)`
   - `Firestore Rules Tests`
   - `Functions Integration Tests`
   - `Build Apps (android)`
   - `Build Apps (web)`
   - `Web Bundle Size Budget`

## Commit Signing (Optional)

### Why Sign Commits?

Commit signing adds cryptographic verification that commits came from a trusted source:
- Prevents impersonation
- Adds audit trail
- Required for some compliance standards

### How to Enable

1. Generate a GPG key:
   ```bash
   gpg --full-generate-key
   ```

2. Configure Git to use the key:
   ```bash
   git config --global user.signingkey YOUR_KEY_ID
   git config --global commit.gpgsign true
   ```

3. Add your GPG public key to GitHub:
   - Settings > SSH and GPG keys > New GPG key

## Linear History

### Merge Strategies

Only the following merge strategies are allowed:
- **Squash and merge**: Combines all commits into one (recommended for feature branches)
- **Rebase and merge**: Replays commits on top of main (recommended for clean history)

❌ **Merge commits are disabled** to maintain linear history.

### Benefits

- Clean, readable history
- Easy to revert changes
- Simplified bisecting
- Better for CI/CD

## PR Requirements Checklist

Before a PR can be merged, ensure:

- [ ] All required status checks pass
- [ ] At least 1 approving review
- [ ] Branch is up to date with `main`
- [ ] No merge conflicts
- [ ] Linear history maintained (squash or rebase)
- [ ] Documentation updated if needed
- [ ] Tests added for new functionality
- [ ] Breaking changes documented

## Emergency Hotfix Process

For critical production issues:

1. Create hotfix branch from `main`
2. Make minimal changes
3. Fast-track review (but still require approval)
4. Merge using squash or rebase
5. Deploy immediately
6. Create post-mortem documentation

## Enforcement

These rules are enforced at the GitHub level and cannot be bypassed without admin privileges. All contributors, including administrators, must follow these rules to ensure code quality and security.

## Related Documentation

- [CI/CD Implementation](docs/ops/CI_CD_IMPLEMENTATION.md)
- [Developer Workflow](docs/DEVELOPER_WORKFLOW.md)
- [Testing Guide](docs/Testing.md)
- [Pull Request Template](.github/pull_request_template.md)

---

**Last Updated**: 2024
**Maintained By**: DevOps Team
