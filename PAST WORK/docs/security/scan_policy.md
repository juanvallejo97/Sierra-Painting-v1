# Security Scanning Policy

**Version**: 1.0.0
**Last Updated**: 2025-10-11
**Owner**: Security & Platform Team
**Status**: Active

---

## Table of Contents

1. [Overview](#overview)
2. [Scanning Schedule](#scanning-schedule)
3. [Scan Types](#scan-types)
4. [Vulnerability Severity Levels](#vulnerability-severity-levels)
5. [Remediation SLAs](#remediation-slas)
6. [Dependency Management](#dependency-management)
7. [License Compliance](#license-compliance)
8. [Incident Response](#incident-response)
9. [Roles and Responsibilities](#roles-and-responsibilities)
10. [Compliance and Auditing](#compliance-and-auditing)

---

## Overview

This document defines the security scanning policy for the Sierra Painting application. The policy covers automated vulnerability scanning, dependency management, license compliance, and remediation procedures.

**Objectives**:
- Identify security vulnerabilities before they reach production
- Ensure dependencies are up-to-date and free of known CVEs
- Maintain license compliance for all third-party dependencies
- Provide clear remediation timelines based on severity
- Enable continuous security monitoring and improvement

**Scope**: All codebases, dependencies, and infrastructure configurations for Sierra Painting (Flutter app, Cloud Functions, CI/CD pipelines).

---

## Scanning Schedule

### Automated Scans

| Scan Type | Frequency | Trigger | Timeout |
|-----------|-----------|---------|---------|
| NPM Audit | On every PR + Weekly | PR to main/staging | 10 min |
| Dart/Flutter Audit | On every PR + Weekly | PR to main/staging | 10 min |
| CodeQL (SAST) | On every PR + Weekly | PR to main/staging | 20 min |
| Secret Scanning | On every PR + Weekly | PR to main/staging | 10 min |
| License Compliance | On every PR + Weekly | PR to main/staging | 10 min |
| Dependency Review | On every PR | PR only | 5 min |

### Manual Scans

- **Pre-Release**: Full security scan before each production deployment
- **Post-Incident**: Comprehensive scan after any security incident
- **Quarterly Review**: Deep dive security audit every 3 months

---

## Scan Types

### 1. NPM Audit (Dependency Vulnerability Scan)

**Tool**: `npm audit`
**Target**: Root `package.json` + Functions `package.json`

**What It Checks**:
- Known CVEs in npm dependencies
- Transitive dependency vulnerabilities
- Outdated packages with security patches available

**Output**:
- JSON report uploaded as GitHub artifact
- Summary in PR comment or workflow summary
- Exit code 1 if vulnerabilities found (fails workflow)

**Remediation**:
```bash
# Automatic fix (may break things)
npm audit fix

# Manual fix (safer)
npm audit fix --force
npm test  # Verify no regressions

# For specific package
npm update <package-name>
```

### 2. Dart/Flutter Dependency Audit

**Tool**: `flutter pub outdated`
**Target**: Root `pubspec.yaml`

**What It Checks**:
- Outdated Dart/Flutter packages
- Null-safety compliance
- Available security patches

**Output**:
- JSON report uploaded as GitHub artifact
- Summary in workflow output
- Warnings for packages >3 months outdated

**Remediation**:
```bash
# Check for updates
flutter pub outdated

# Update all
flutter pub upgrade

# Update specific package
flutter pub upgrade <package_name>

# Verify no regressions
flutter test
```

### 3. CodeQL (Static Application Security Testing)

**Tool**: GitHub CodeQL
**Target**: JavaScript/TypeScript code in Cloud Functions

**What It Checks**:
- SQL injection vulnerabilities
- Cross-site scripting (XSS)
- Path traversal
- Insecure randomness
- Hardcoded credentials
- Unsafe regex
- Security-extended and security-and-quality queries

**Output**:
- SARIF report uploaded to GitHub Security tab
- Alerts in GitHub Security dashboard
- Fails workflow if high/critical issues found

**Remediation**:
- Review alerts in GitHub Security → Code scanning
- Fix issues per CodeQL recommendations
- Re-run scan to verify fix
- Suppress false positives with justification

### 4. Secret Scanning (Gitleaks)

**Tool**: Gitleaks
**Target**: All files in git history

**What It Checks**:
- API keys (Firebase, Stripe, etc.)
- Database credentials
- Private keys (SSH, PGP)
- OAuth tokens
- AWS access keys
- Generic secrets (passwords, tokens)

**Output**:
- SARIF report uploaded to GitHub Security tab
- Fails workflow immediately if secrets detected
- No public exposure (secrets not logged)

**Remediation** (CRITICAL - Immediate Action Required):
1. **Rotate Compromised Credentials**: Invalidate the exposed secret immediately
2. **Remove from Git History**: Use `git filter-repo` or BFG Repo-Cleaner
3. **Add to .gitignore**: Prevent future commits
4. **Use Environment Variables**: Store secrets in GitHub Secrets or Firebase Config
5. **Audit Access Logs**: Check if secret was accessed by unauthorized parties
6. **Incident Report**: File incident report per incident response procedure

**Example Remediation**:
```bash
# Rotate Firebase API key
firebase projects:list
firebase login
# Generate new key in Firebase Console

# Remove from git history (BE CAREFUL!)
git filter-repo --path path/to/file --invert-paths

# Add to .gitignore
echo "firebase-service-account-*.json" >> .gitignore

# Use environment variable instead
export FIREBASE_API_KEY="..."
```

### 5. License Compliance

**Tool**: `license-checker`
**Target**: All npm dependencies

**What It Checks**:
- License types for all dependencies
- Prohibited licenses (GPL, AGPL, LGPL)
- Missing or ambiguous licenses

**Allowed Licenses**:
- MIT
- Apache-2.0
- BSD-2-Clause, BSD-3-Clause
- ISC
- 0BSD
- CC0-1.0
- Unlicense
- WTFPL

**Prohibited Licenses**:
- GPL-2.0, GPL-3.0 (requires source disclosure)
- AGPL-3.0 (requires network source disclosure)
- LGPL-2.0, LGPL-2.1, LGPL-3.0 (linking restrictions)

**Output**:
- JSON report with all licenses
- Summary table in workflow output
- Fails workflow if prohibited license found

**Remediation**:
```bash
# Find prohibited license
license-checker --json | jq '.[] | select(.licenses | test("GPL"))'

# Option 1: Find alternative package
npm uninstall <package>
npm install <alternative-package>

# Option 2: Seek legal approval (rare)
# Contact legal team for exception request
```

### 6. Dependency Review (GitHub Native)

**Tool**: GitHub Dependency Review Action
**Target**: Pull requests only

**What It Checks**:
- New vulnerabilities introduced in PR
- Dependency version changes
- License changes
- Security advisories

**Output**:
- Comment on PR with detailed diff
- Blocks merge if high/critical vulnerabilities introduced

**Remediation**:
- Update dependency to patched version
- Remove dependency if not needed
- Request review from security team if no patch available

---

## Vulnerability Severity Levels

Based on CVSS (Common Vulnerability Scoring System) scores:

| Severity | CVSS Score | Color | Examples |
|----------|------------|-------|----------|
| **Critical** | 9.0 - 10.0 | 🔴 Red | Remote code execution, SQL injection in production |
| **High** | 7.0 - 8.9 | 🟠 Orange | Authentication bypass, XSS in production |
| **Medium** | 4.0 - 6.9 | 🟡 Yellow | Information disclosure, CSRF |
| **Low** | 0.1 - 3.9 | 🟢 Green | Minor information leak, low-impact DoS |
| **Informational** | 0.0 | ⚪ White | Best practice violation, code smell |

---

## Remediation SLAs

### Production Environment

| Severity | Response Time | Remediation Deadline | Deployment | Escalation |
|----------|---------------|----------------------|------------|------------|
| **Critical** | < 1 hour | 24 hours | Emergency hotfix | Immediate (CTO) |
| **High** | < 4 hours | 7 days | Next scheduled release | 24 hours (Manager) |
| **Medium** | < 2 days | 30 days | Next sprint | 7 days (Team Lead) |
| **Low** | < 1 week | 90 days | Next quarter | None |
| **Informational** | Best effort | No deadline | Backlog | None |

### Staging/Development Environment

| Severity | Response Time | Remediation Deadline |
|----------|---------------|----------------------|
| **Critical** | < 4 hours | 48 hours |
| **High** | < 1 day | 14 days |
| **Medium** | < 1 week | 60 days |
| **Low** | < 2 weeks | 120 days |

### Exceptions

**Grace Period**: If a fix requires significant refactoring or has high regression risk, team lead may approve up to 2x extension with written justification.

**Temporary Mitigation**: If no patch available, implement workaround (e.g., WAF rule, rate limiting) within SLA and track vendor patch status.

---

## Dependency Management

### Update Strategy

**Patch Versions** (e.g., 1.2.3 → 1.2.4): Auto-merge if tests pass
**Minor Versions** (e.g., 1.2.3 → 1.3.0): Review + manual merge after QA
**Major Versions** (e.g., 1.2.3 → 2.0.0): Schedule for next sprint, comprehensive testing

### Dependabot Configuration

- **Schedule**: Weekly for all ecosystems
- **Pull Request Limit**: 5 per ecosystem
- **Grouping**: Related packages grouped into single PR
- **Auto-merge**: Patch versions only, if tests pass

### Manual Review Checklist

Before merging dependency update PR:
- [ ] All CI checks passed (tests, lint, build)
- [ ] No breaking changes in CHANGELOG
- [ ] E2E smoke test passed
- [ ] Security scan passed
- [ ] License remains compatible

---

## License Compliance

### Policy

**Prohibited Licenses** (requires legal approval):
- GPL family (GPL-2.0, GPL-3.0, LGPL)
- AGPL family (AGPL-3.0)
- Commercial licenses without company approval

**Allowed Licenses** (pre-approved):
- MIT, Apache-2.0, BSD family, ISC, Unlicense

**Unknown Licenses** (requires manual review):
- Custom licenses
- Dual-licensed packages (use compatible license)

### Review Process

1. **Automated Check**: License-checker runs on every PR
2. **Flagged License**: PR blocked, requires security team review
3. **Legal Review**: If needed, escalate to legal team (2-5 business days)
4. **Decision**: Approve (with conditions), reject, or find alternative
5. **Documentation**: Record decision in `docs/security/license_decisions.md`

---

## Incident Response

### When to Declare Security Incident

- **Critical vulnerability** in production dependency
- **Secret leaked** in git history or logs
- **Zero-day exploit** affecting our stack
- **Data breach** or unauthorized access
- **Compliance violation** (GDPR, PCI-DSS if applicable)

### Incident Response Steps

1. **Detect** (Automated scan or manual report)
2. **Assess** (Severity, impact, exploitability)
3. **Contain** (Disable affected feature, rotate credentials)
4. **Remediate** (Patch, deploy hotfix)
5. **Verify** (Re-scan, penetration test)
6. **Document** (Post-mortem, lessons learned)
7. **Notify** (Stakeholders, customers if required by law)

### Communication

- **Critical/High**: Slack #incidents channel + Email to platform-team@example.com
- **Medium**: Slack #alerts channel
- **Low**: GitHub issue labeled "security"

---

## Roles and Responsibilities

| Role | Responsibility |
|------|---------------|
| **Security Team** | Define policy, review findings, approve exceptions |
| **Platform Team** | Implement scans, maintain CI/CD, first-line remediation |
| **Engineers** | Fix vulnerabilities in their PRs, respond to findings |
| **Team Lead** | Prioritize security work, approve extensions, escalate blockers |
| **Engineering Manager** | Resource allocation, executive escalation, compliance |
| **CTO** | Critical incident decision-maker, external communication |

---

## Compliance and Auditing

### Audit Trail

All security scan results are:
- Archived as GitHub artifacts (30-day retention)
- Logged in GitHub Security dashboard (permanent)
- Summarized in monthly security report

### Metrics

Track monthly:
- **Mean Time to Remediate (MTTR)**: Average time from detection to fix deployment
- **Vulnerability Backlog**: Open vulnerabilities by severity
- **SLA Compliance**: % of vulnerabilities fixed within SLA
- **Dependency Freshness**: % of dependencies on latest stable version

### Reporting

**Monthly**: Security dashboard sent to engineering team
**Quarterly**: Executive summary for leadership
**Annually**: Comprehensive security audit for compliance (SOC 2, ISO 27001 if applicable)

---

## Related Documentation

- [Dependabot Configuration](../../.github/dependabot.yml)
- [Security Scan Workflow](../../.github/workflows/security-scan.yml)
- [Incident Response Playbook](../ops/incident_response.md)
- [Security Best Practices](./best_practices.md)

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2025-10-11 | Initial version | Claude Code |

---

## Feedback

For questions or suggestions:
- Slack: #security or #platform-team
- Email: security@example.com
- GitHub Issues: tag `security` and `policy`
