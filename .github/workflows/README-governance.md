# Project Governance & PR Conflict Resolver Workflow

This workflow automates PR conflict resolution and enforces project governance standards.

## Purpose

- Automate conflict detection for multiple PRs
- Enforce quality gates (lint, typecheck, test, build)
- Codify project phases and exit criteria
- Provide clear resolution instructions

## Usage

### Via GitHub UI

1. Go to the repository on GitHub
2. Click **Actions** tab
3. Select **Project Governance & PR Conflict Resolver** from the workflows list
4. Click **Run workflow** button
5. Fill in the inputs:
   - **prs**: Comma-separated PR numbers (e.g., `123,124,125`)
   - **base**: Base branch to merge against (default: `main`)
6. Click **Run workflow** to start

### Example

```
prs: 45,46,47
base: main
```

This will check PRs #45, #46, and #47 for conflicts with the `main` branch.

## What It Does

### 1. Quality Gates

Runs the following checks:
- **Lint**: Code style and formatting
- **Typecheck**: Type safety verification
- **Test**: Unit and integration tests
- **Build**: Build verification

All quality gates must pass before the conflict resolver runs.

### 2. Conflict Resolution

For each PR:
- Fetches the PR branch
- Attempts a test merge with the base branch
- Posts a comment on the PR with:
  - ✅ Success status if no conflicts
  - ⚠️ Warning with resolution steps if conflicts found
  - Quality gate results
  - Links to relevant documentation

### 3. Summary Report

Generates a workflow summary with:
- PR numbers processed
- Quality gate status
- Project phase enforcement info
- Links to PR comments

## Project Phases Enforced

### Phase 3: Functional Hardening
- All unit tests pass (>= 90% coverage on changed lines)
- Static analysis: no new high-severity findings
- Security: dependency scan clean or waivered

### Phase 4: Final Documentation
- Updated README, CHANGELOG, and ADRs for scope changes
- Public API docs regenerated and committed

### Phase 5: CI/CD & Ship Checks
- Green CI (lint, typecheck, test, build)
- Signed tags & release notes generated
- Image/package published with SBOM

## Quality Standards

- **Conventional Commits**: All commits follow conventional commit format
- **Semantic Versioning**: Version bumps follow semver
- **Required Checks**: lint, typecheck, test, build must pass

## Conflict Resolution Process

When conflicts are detected, the workflow posts detailed instructions:

1. **Pull latest changes** from base branch
2. **Resolve conflicts** in the listed files
3. **Commit the resolution** with appropriate message
4. **Re-run quality gates** to ensure all checks pass

## Permissions

The workflow requires:
- `contents: write` - To fetch and checkout branches
- `pull-requests: write` - To post comments on PRs

## Best Practices

1. **Run regularly**: Use this workflow when you have multiple PRs to review
2. **Process related PRs**: Group PRs that might affect each other
3. **Monitor results**: Check the PR comments for detailed information
4. **Act promptly**: Resolve conflicts as soon as they're identified

## Troubleshooting

### Workflow fails on quality gates
- One or more quality checks (lint, typecheck, test, build) failed
- Check the workflow logs for details
- Fix issues in the repository and re-run

### Cannot find PR
- PR number doesn't exist or is not accessible
- Verify PR numbers are correct
- Ensure PRs are in the same repository

### Conflicts not detected
- PR may be up to date with base branch
- Try fetching latest changes and re-run

## Integration

This workflow integrates with:
- Repository CI/CD pipelines
- Branch protection rules
- PR review process
- Project governance standards

## See Also

- [Governance Documentation](../../docs/GOVERNANCE.md)
- [Branch Protection Configuration](../../docs/BRANCH_PROTECTION.md)
- [Developer Workflow Guide](../../docs/DEVELOPER_WORKFLOW.md)
- [V1 Ship-Readiness Plan](../../docs/Plan.md)
