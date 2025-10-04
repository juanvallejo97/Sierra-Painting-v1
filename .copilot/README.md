# Copilot Governance Framework

This directory contains governance configurations for the Sierra Painting v1 project.

## Files

### docs-cleanup.yaml
The baseline configuration file that defines:
- Quality gates for code, documentation, security, performance, and testing
- Review rubric for pull requests
- Architectural principles
- Files to delete during cleanup
- Target repository structure
- Migration strategy with phases
- Risk register
- Success metrics

**SHA256 Hash**: `1eed8ae6575a7f49039c9d6f5918c6dc2310928dd8f549cc9aea1ce191e5aef1`

## Purpose

This governance framework implements the cleanup plan described in `docs/Plan.md` to bring the repository to V1 ship-readiness state. It defines:

1. **Quality Gates** - Automated checks that must pass before code can be merged or deployed
2. **Review Rubric** - Standards for code review and PR approval
3. **Architectural Principles** - Core design principles that guide all changes
4. **Cleanup Strategy** - Specific files to remove and directory structure to achieve

## Usage

The baseline configuration is imported by higher-level blueprints (such as `enterprise_app_streamline_blueprint`) that extend and customize it for specific cleanup initiatives.

## Cleanup Phases

1. **Audit & Plan** ✅ - Complete (docs/Plan.md)
2. **Repo Restructure & Cleanup** - In Progress
3. **Functional Hardening** - Pending
4. **Final Documentation** - Pending
5. **CI/CD & Ship Checks** - Pending

## Files Cleaned Up

As of this commit, the following redundant files have been removed:
- `CHANGELOG.md` - Use GitHub releases instead
- `CONTRIBUTING.md` - Minimal version in README is sufficient
- `docs/index.md` - README serves this purpose
- `docs/EnhancementsAndAdvice.md` - Historical, not actionable

## Enforcement

Quality gates are enforced through:
- CI/CD checks (lint, format, type checking, tests)
- Code review requirements
- Deployment gates

## Notes

- Changes should be minimal and surgical
- Git history is preserved for auditability
- Test incrementally after each change
- Document all breaking changes in MIGRATION.md
