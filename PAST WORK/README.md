# PAST WORK Archive

## Purpose

This folder contains historical documentation, audit reports, checklists, prototypes, and debug artifacts from the development and pre-release phases of Sierra Painting v1.

**These files are archival and non-blocking** - they are not required for building, testing, or deploying the application. They are preserved for historical reference, audit trails, and learning.

## What Was Moved Here

All files moved to this folder on **2025-10-14** as part of the repo declutter initiative (branch: `chore/repo-declutter-past-work`).

### Categories Archived:

1. **Audit & Reports** (80+ files)
   - Pattern: `AUDIT_*`, `*_REPORT`, `*_ANALYSIS`, `*_SUMMARY`
   - Examples: `SENIOR_DEV_REPORT.md`, `PERFORMANCE_AUDIT_REPORT.md`, `POST_PATCH_VALIDATION_REPORT.md`
   - Includes comprehensive 18-suite audit results and post-patch validation

2. **Checklists & Guides** (50+ files)
   - Pattern: `*_CHECKLIST`, `*_GUIDE`, `*_PLAYBOOK`, `*_RUNBOOK`, `*_PLAN`
   - Examples: `PRODUCTION_DEPLOYMENT_CHECKLIST.md`, `STAGING_DEPLOY_DRY_RUN.md`, `SMOKE_TEST_EXECUTABLE_CHECKLIST.md`

3. **Implementation Docs** (30+ files)
   - Pattern: `QWEN_*`, `IMPLEMENTATION_*`, `MIGRATION_*`, `T0_*`
   - Examples: `QWEN_TASKS.json`, `QWEN_001_IMPLEMENTATION_GUIDE.md`, `IMPLEMENTATION_ORDER.md`
   - Includes task delegation artifacts for QWEN30-CODER

4. **Debug & Diagnostic Files** (40+ files)
   - Pattern: `DEBUG_*`, `DIAGNOSTIC_*`, `DEBUGGING_*`, `*_FIX_*`
   - Examples: `ADMIN_DASHBOARD_DEBUG_ANALYSIS.md`, `APPCHECK_400_ERROR_ESCALATION.md`, `WEB_BOOT_BLOCKER_REPORT.md`

5. **Log Files** (all *.log)
   - Examples: `build_web.log`, `deploy_functions.log`, `firebase-debug.log`, `curl_appcheck_test.log`

6. **Status & Tracking** (20+ files)
   - Pattern: `*_STATUS`, `*_NEXT_STEPS`, `OVERNIGHT_*`, `CURRENT_STATUS`, `PATCH_*`
   - Examples: `CURRENT_STATUS.md`, `NEXT_STEPS.md`, `PATCH_STATUS.md`

7. **Security & Performance** (15+ files)
   - Pattern: `SECURITY_*`, `PERFORMANCE_*`, `OBSERVABILITY_*`
   - Examples: `SECURITY_AUDIT_SUMMARY.md`, `PERFORMANCE_BASELINE_REPORT.md`, `OBSERVABILITY_SECURITY_AUDIT.md`

8. **Config Backups & Prototypes**
   - Files: `firestore.indexes.new.json`, `firestore_indexes_backup.json`, `admin_role.json`
   - CSV files: `AUDIT_risk_register.csv`, `OWNERSHIP_MATRIX.csv`, `RISK_BACKLOG.csv`

9. **Directories**
   - `.artifacts/` - Validation artifacts
   - `.deployment-history/` - Deployment logs
   - `docs/` - Architecture, ADRs, developer guides, explanations
   - `.claude/` - Claude AI assistant configurations
   - `.copilot/` - GitHub Copilot instructions

10. **GitHub Workflows** (28 archival workflows moved)
    - Experimental/debug: `meta-debug.yml`, `guard-*.yml`, `validator-*.yml`
    - Redundant: `smoke_check.yml` + `smoke_tests.yml`, `security.yml` + `security-scan.yml`
    - Archival: `backup_staging.yml`, `nightly.yml`, `stabilization.yml`, `release_*.yml`
    - **Kept only 8 essential workflows**: `ci.yml`, `code_quality.yml`, `commitlint.yml`, `deploy.yml`, `firestore_rules.yml`, `repo-hygiene.yml`, `security-scan.yml`, `tests.yml`

## Files That Stayed at Root

Only production-required files remain at the repository root:

- **App code**: `lib/`, `web/`, `assets/`, `test/`, `functions/`
- **Core configs**: `pubspec.yaml`, `firebase.json`, `.firebaserc`, `firestore.rules`, `firestore.indexes.json`, `storage.rules`
- **Metadata**: `README.md`, `LICENSE`, `CHANGELOG.md`, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`
- **CI workflows**: `.github/workflows/*.yml` (8 essential workflows only)
- **Generated outputs**: Excluded from Git via `.gitignore` (`coverage/`, `build/`, `functions/lib/`)

## Why This Cleanup?

After passing the post-patch audit with an **A- overall grade (89/100)** and **A security grade (95/100)**, the repository had accumulated 100+ archival documents, reports, and debug artifacts that were cluttering the root directory.

**Goals:**
1. **Clean trunk for v1-rc.1 release** - Easy navigation for new developers
2. **Preserve history** - All files kept in Git history via `git mv`
3. **Prevent re-clutter** - Added `repo-hygiene.yml` workflow to guard against new clutter
4. **Focus on production** - Only build/test/deploy essentials at root

## How to Access Historical Files

All files are preserved in Git history and can be accessed:

```bash
# View file from PAST WORK
cat "PAST WORK/SENIOR_DEV_REPORT.md"

# Search within archival docs
git grep "coverage" "PAST WORK/"

# View file at previous commit (before move)
git show main~5:SENIOR_DEV_REPORT.md

# List all files moved
git log --oneline --name-status | grep "PAST WORK"
```

## Reference Documents

Key documents in this archive:

- **SENIOR_DEV_REPORT.md** - Comprehensive 18-suite audit (overall A-, security A)
- **QWEN_TASKS.json** - 12 implementation tasks for v1-rc.1
- **POST_PATCH_VALIDATION_REPORT.md** - Baseline metrics before v1 release
- **CLAUDE.md** - Project instructions for Claude AI assistant
- **docs/** - Architecture diagrams, ADRs, developer workflows, App Check guide

---

**Archive Created**: 2025-10-14
**Branch**: `chore/repo-declutter-past-work`
**Commit**: [Will be added after merge]
**Files Moved**: 100+ documents, 28 workflows, 3 directories
**Repo Reduction**: ~150 files moved from root to PAST WORK/
