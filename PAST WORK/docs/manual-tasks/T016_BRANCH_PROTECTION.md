# T-016: Branch Protection Setup Guide

**Priority**: P1 - MEDIUM (Process Enforcement)
**Estimated Time**: 15-20 minutes
**Prerequisites**: GitHub repository admin access
**Status**: ⏳ Awaiting configuration

---

## Overview

Branch protection prevents accidental or malicious changes to critical branches by enforcing:
- Pull request reviews before merging
- Status checks (CI/CD) must pass
- No force pushes or branch deletion
- Signed commits (optional)

**Without protection**, anyone with write access can:
- Push directly to `main` → bypassing code review
- Force push → rewriting history
- Delete branches → losing work

---

## Recommended Protection Rules

### `main` Branch (Production)
**Protection Level**: MAXIMUM

**Rules**:
- ✅ Require pull request before merging
  - ✅ Require 1 approval (minimum)
  - ✅ Dismiss stale reviews when new commits pushed
  - ✅ Require review from code owners (if CODEOWNERS exists)
- ✅ Require status checks to pass
  - ✅ `test` (flutter test)
  - ✅ `build` (flutter build)
  - ✅ `lint` (flutter analyze)
  - ✅ Require branches to be up to date before merging
- ✅ Require conversation resolution before merging
- ✅ Require signed commits (recommended)
- ✅ Require linear history (optional, prevents merge commits)
- ❌ Allow force pushes (NEVER on main)
- ❌ Allow deletions (NEVER on main)

### `staging` Branch (Staging Environment)
**Protection Level**: HIGH

**Rules**:
- ✅ Require pull request before merging
  - ✅ Require 1 approval (can be lower than main)
- ✅ Require status checks to pass
  - ✅ `test`, `build`, `lint`
- ✅ Require conversation resolution
- ❌ Force pushes allowed for admins only (emergency hotfixes)
- ❌ Allow deletions (prevent)

### Feature Branches
**Protection Level**: NONE (developers need flexibility)

**Rules**:
- ✅ Allow force pushes (for rebasing)
- ✅ Allow deletions (cleanup after merge)

---

## Implementation Steps

### Step 1: Access GitHub Repository Settings (2 min)

1. Navigate to: https://github.com/your-org/sierra-painting-v1

2. Click **Settings** tab

3. Click **Branches** in left sidebar

4. Look for "Branch protection rules" section

**If you don't see Settings tab**:
- You need admin access to the repository
- Contact repository owner to grant admin access

### Step 2: Protect `main` Branch (10 min)

1. Click **Add rule** (or **Add branch protection rule**)

2. **Branch name pattern**: `main`

3. **Protect matching branches** section:

#### Required Settings (MUST enable):

**Require a pull request before merging**:
- [x] Require a pull request before merging
- Number of approvals required: **1** (increase to 2 for stricter control)
- [x] Dismiss stale pull request approvals when new commits are pushed
- [x] Require review from Code Owners (if you have CODEOWNERS file)

**Require status checks to pass before merging**:
- [x] Require status checks to pass before merging
- [x] Require branches to be up to date before merging

Click **Search for status checks** and select:
- `test` (flutter test workflow)
- `build` (flutter build workflow)
- `lint` (flutter analyze workflow)
- `functions-build` (Cloud Functions build, if CI exists)

**Note**: These status checks must exist in your `.github/workflows/*.yml` files

**Require conversation resolution before merging**:
- [x] Require conversation resolution before merging

**Require signed commits** (Recommended):
- [x] Require signed commits
  - **Note**: This requires developers to set up GPG signing
  - See: https://docs.github.com/en/authentication/managing-commit-signature-verification

**Require linear history** (Optional):
- [x] Require linear history
  - **Effect**: Prevents merge commits, enforces rebase workflow
  - **Trade-off**: Requires developers to rebase before merging

**Do not allow bypassing the above settings** (CRITICAL):
- [x] Do not allow bypassing the above settings
  - **Effect**: Even admins must follow rules
  - **Exception**: Uncheck if you need emergency hotfix capability

#### Forbidden Settings (MUST disable):

**Allow force pushes**:
- [ ] Allow force pushes
  - **NEVER enable on main** - rewrites history

**Allow deletions**:
- [ ] Allow deletions
  - **NEVER enable on main** - prevents accidental deletion

4. Click **Create** or **Save changes**

### Step 3: Protect `staging` Branch (5 min)

1. Click **Add rule** again

2. **Branch name pattern**: `staging`

3. Apply similar rules as `main`, but with relaxed settings:

**Require a pull request before merging**:
- [x] Require a pull request before merging
- Number of approvals required: **1**
- [ ] Dismiss stale pull request approvals (optional for staging)

**Require status checks to pass before merging**:
- [x] Require status checks to pass before merging
- Select: `test`, `build`, `lint`

**Allow force pushes** (Admins only for hotfixes):
- [x] Allow force pushes
- **Specify who can force push**: Administrators only

4. Click **Create** or **Save changes**

### Step 4: Configure Branch Protection Bypass (Optional)

If you need emergency hotfix capability:

1. Branch protection rule → **Settings** → **Do not allow bypassing the above settings**

2. **Uncheck** this box

3. **Allow specified actors to bypass required pull requests**:
   - Add: Repository admins
   - Use only for emergencies

**⚠️ Warning**: This creates a backdoor. Use sparingly!

### Step 5: Set Default Branch (Verify)

1. Repository Settings → **Branches** → **Default branch**

2. Verify: **main** is set as default

3. If not, click **Switch to another branch** → Select `main`

---

## Verification Checklist

### Test Protection Rules

1. **Try to push directly to `main`**:
   ```bash
   git checkout main
   git commit --allow-empty -m "Test direct push"
   git push origin main
   ```

   **Expected**: ❌ Push rejected with message:
   ```
   remote: error: GH006: Protected branch update failed for refs/heads/main.
   remote: error: Changes must be made through a pull request.
   ```

2. **Try to force push to `main`**:
   ```bash
   git push --force origin main
   ```

   **Expected**: ❌ Force push rejected

3. **Try to delete `main` branch**:
   ```bash
   git push origin :main
   ```

   **Expected**: ❌ Deletion rejected

4. **Create a pull request**:
   ```bash
   git checkout -b test-pr
   git commit --allow-empty -m "Test PR"
   git push origin test-pr
   ```

   - Open PR on GitHub
   - **Expected**: PR requires approval
   - **Expected**: Status checks must pass before merge

5. **Test admin bypass** (if enabled):
   - As admin, create PR
   - **Expected**: Can merge without approval (if bypass enabled)

### Verify Status Checks

1. GitHub Repository → **Settings** → **Branches** → `main` rule

2. Under "Require status checks to pass before merging":
   - Verify `test`, `build`, `lint` are listed

3. Create a PR with failing tests:
   ```dart
   test('should fail', () {
     expect(true, false);
   });
   ```

   - Push changes
   - **Expected**: Status check fails
   - **Expected**: "Merge" button is disabled

---

## CI/CD Integration

### Required GitHub Actions Workflows

Create these workflows in `.github/workflows/`:

#### 1. Test Workflow (`.github/workflows/test.yml`)
```yaml
name: test

on:
  pull_request:
    branches: [main, staging]
  push:
    branches: [main, staging]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.35.0'
      - run: flutter pub get
      - run: flutter test --concurrency=1
```

#### 2. Build Workflow (`.github/workflows/build.yml`)
```yaml
name: build

on:
  pull_request:
    branches: [main, staging]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter build web --release
      - run: cd functions && npm ci && npm run build
```

#### 3. Lint Workflow (`.github/workflows/lint.yml`)
```yaml
name: lint

on:
  pull_request:
    branches: [main, staging]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter analyze
      - run: cd functions && npm ci && npm run lint
```

**After creating workflows**:
1. Push workflows to repository
2. GitHub will recognize them as status checks
3. Add them to branch protection rules

---

## Team Workflow Changes

### Old Workflow (No Protection)
```bash
git checkout main
git pull
# Make changes
git commit -m "Fix bug"
git push origin main  # ✅ Direct push (risky)
```

### New Workflow (With Protection)
```bash
git checkout main
git pull
git checkout -b fix/bug-123

# Make changes
git commit -m "Fix bug"
git push origin fix/bug-123

# Open PR on GitHub
# Request review
# Wait for approval + status checks
# Merge via GitHub UI
```

### Best Practices

**Creating PRs**:
1. Create feature branch from `main`:
   ```bash
   git checkout main
   git pull
   git checkout -b feature/new-feature
   ```

2. Make atomic commits:
   ```bash
   git add file1.dart
   git commit -m "Add user authentication"
   ```

3. Push and open PR:
   ```bash
   git push origin feature/new-feature
   ```

4. Request review from team member

5. Respond to review comments:
   ```bash
   git commit -m "Address review feedback"
   git push origin feature/new-feature  # Updates existing PR
   ```

6. Merge after approval + passing checks

**Handling Conflicts**:
```bash
# Option 1: Merge main into feature branch
git checkout feature/new-feature
git merge main
git push origin feature/new-feature

# Option 2: Rebase (if linear history required)
git checkout feature/new-feature
git rebase main
git push --force origin feature/new-feature  # Only on feature branches!
```

---

## Common Issues & Solutions

### Issue: "Status check has not run on the latest commit"

**Cause**: GitHub Actions workflow hasn't completed yet

**Solution**:
1. Wait for workflow to complete
2. Check Actions tab for progress
3. If stuck, re-run workflow

### Issue: "Required status check is missing"

**Cause**: Status check not configured or workflow doesn't exist

**Solution**:
1. Create missing workflow (`.github/workflows/*.yml`)
2. Push workflow to repository
3. Add status check to branch protection

### Issue: "Cannot merge because of merge conflicts"

**Cause**: Feature branch is out of sync with `main`

**Solution**:
```bash
git checkout feature-branch
git merge main  # Or git rebase main
# Resolve conflicts
git add .
git commit -m "Resolve merge conflicts"
git push origin feature-branch
```

### Issue: "Admins can't merge without approval"

**Cause**: "Do not allow bypassing the above settings" is checked

**Solution**:
1. **Option A** (Recommended): Get approval from another admin
2. **Option B** (Emergency): Temporarily disable rule → merge → re-enable
3. **Option C**: Enable admin bypass in branch protection settings

### Issue: "CI/CD is failing but changes are trivial"

**Cause**: Flaky tests or unrelated failures

**Solution**:
1. **Fix the root cause** (don't bypass checks)
2. Re-run failed workflow
3. If test is flaky, mark as `@Skip` temporarily
4. Create issue to fix flaky test

---

## Rollback Plan

If branch protection causes issues:

### Disable Protection (5 min)
1. GitHub → Repository → Settings → Branches
2. Find `main` branch rule
3. Click **Edit** → **Delete** (temporary)
4. Make urgent changes
5. Re-enable protection

### Modify Rules (2 min)
1. Click **Edit** on branch rule
2. Uncheck problematic setting
3. **Save changes**
4. Document why rule was modified

---

## Advanced Configuration

### CODEOWNERS File (Optional)

Create `.github/CODEOWNERS`:
```
# Require review from specific teams/users

# Root files
* @your-org/dev-team

# Flutter code
/lib/** @your-org/frontend-team
/test/** @your-org/qa-team

# Cloud Functions
/functions/** @your-org/backend-team

# CI/CD
/.github/** @your-org/devops-team

# Admin features (extra scrutiny)
/lib/features/admin/** @your-org/admin-reviewers
```

**Effect**: PRs changing these files require review from specified owners

### Rulesets (GitHub Enterprise)

GitHub Enterprise supports more advanced rulesets:
1. Repository → Settings → **Rules** → **Rulesets**
2. Create ruleset with fine-grained permissions
3. Apply to multiple branches with patterns

---

## Monitoring & Maintenance

### Weekly
- [ ] Review open PRs (ensure none are stuck)
- [ ] Check for bypassed protections (audit log)

### Monthly
- [ ] Review branch protection rules
- [ ] Update status checks if CI/CD changes
- [ ] Check for stale branches (cleanup)

### Quarterly
- [ ] Review team access (remove inactive members)
- [ ] Update CODEOWNERS if team structure changed
- [ ] Audit protection bypasses

---

## Team Training

### Onboarding Checklist
- [ ] Explain PR workflow
- [ ] Show how to create feature branches
- [ ] Demonstrate merge conflict resolution
- [ ] Practice creating and merging PRs
- [ ] Explain status checks and how to fix failures

### Common Commands
```bash
# Create feature branch
git checkout -b feature/my-feature

# Push and create PR
git push -u origin feature/my-feature

# Update PR with new commits
git commit -am "Update"
git push origin feature/my-feature

# Sync with main
git checkout main && git pull
git checkout feature/my-feature
git merge main  # Or git rebase main

# Delete merged branch
git checkout main
git branch -d feature/my-feature
git push origin --delete feature/my-feature
```

---

## References

- **GitHub Branch Protection**: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/defining-the-mergeability-of-pull-requests/about-protected-branches
- **CODEOWNERS**: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners
- **GitHub Actions**: https://docs.github.com/en/actions
- **Git Flow**: https://nvie.com/posts/a-successful-git-branching-model/

---

**Status**: ⏳ Ready for implementation
**Owner**: DevOps Team
**Due Date**: Within 1 week (MEDIUM priority)
**Estimated Impact**: Prevents ~90% of accidental main branch corruption
