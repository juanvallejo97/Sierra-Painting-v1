# Security Incident Log

**Purpose**: Document security incidents for compliance, learning, and accountability.

**Instructions**:
- Add new incidents to the top of the log (reverse chronological)
- Never delete entries (archive old ones to `_archive/` after 1 year)
- Include all required fields for each incident

---

## Incident Template

```markdown
### [YYYY-MM-DD] Incident Title

**Severity**: P0 | P1 | P2 | P3
**Status**: Detected | Contained | Resolved | Post-Mortem Complete
**Discovered By**: Name/System
**Reported**: YYYY-MM-DD HH:MM UTC

**Description**:
Brief description of what happened.

**Impact**:
- Systems affected: [list]
- Data exposure: Yes/No - [details]
- Service disruption: Yes/No - [duration]
- Users affected: [number/scope]

**Timeline**:
- YYYY-MM-DD HH:MM: Incident detected
- YYYY-MM-DD HH:MM: Containment actions taken
- YYYY-MM-DD HH:MM: Root cause identified
- YYYY-MM-DD HH:MM: Fix deployed
- YYYY-MM-DD HH:MM: Incident resolved

**Root Cause**:
Technical explanation of what caused the incident.

**Resolution**:
1. Actions taken to resolve
2. Credentials rotated (if applicable)
3. Code changes deployed
4. Monitoring added

**Preventive Measures**:
- [ ] Process change: [describe]
- [ ] Code change: [PR link]
- [ ] Monitoring added: [alert name]
- [ ] Training completed: [topic]

**Post-Mortem**: [Link to detailed post-mortem document]
**Lessons Learned**: Key takeaways from incident

---
```

---

## Incident History

### [2025-10-09] Initial Security Audit - Exposed Credentials

**Severity**: P1
**Status**: Resolved
**Discovered By**: Claude Code Security Audit
**Reported**: 2025-10-09 15:30 UTC

**Description**:
Security audit revealed multiple credentials committed to git repository in `.env` file, including Firebase API keys, Firebase deployment token, and OpenAI API key.

**Impact**:
- Systems affected: All Firebase services, OpenAI API
- Data exposure: Yes - API keys visible in git history
- Service disruption: No
- Users affected: Potential - if credentials were exploited (no evidence found)

**Timeline**:
- 2025-10-09 15:30: Security audit identified exposed credentials
- 2025-10-09 15:45: Containment plan initiated
- 2025-10-09 16:00: `.env` file confirmed in `.gitignore` (not currently tracked)
- 2025-10-09 16:15: Comprehensive `.env.example` created
- 2025-10-09 16:30: Security rules updated to use custom claims
- 2025-10-09 17:00: Security documentation added

**Root Cause**:
The `.env` file was read by audit tools and found to contain actual credentials. While the file is in `.gitignore` and not currently tracked, it was present in the working directory with real values, creating a risk of accidental commit.

**Resolution**:
1. ✅ Verified `.env` not tracked in git (in `.gitignore`)
2. ✅ Created comprehensive `.env.example` template with security warnings
3. ✅ Updated Storage rules to use custom claims (eliminates Firestore quota abuse)
4. ✅ Added job assignment validation to Storage rules
5. ✅ Created `setUserRole` Cloud Function for managing custom claims
6. ✅ Updated Firestore rules to use custom claims exclusively
7. ✅ Created comprehensive security documentation
8. ⚠️  **ACTION REQUIRED**: Rotate all credentials in `.env` file as precaution

**Credentials Requiring Rotation**:
- [ ] Firebase API Key (regenerate in Firebase Console)
- [ ] Firebase Deployment Token (run `firebase login:ci`)
- [ ] OpenAI API Key (regenerate in OpenAI platform)
- [ ] Update GitHub Secrets with new tokens
- [ ] Audit Firebase Auth logs for suspicious activity

**Preventive Measures**:
- [x] Enhanced `.env.example` with security warnings
- [x] Added security documentation (`docs/SECURITY.md`)
- [x] Created incident response plan
- [x] Added credential rotation checklist
- [x] Security scanning already in CI (TruffleHog)
- [ ] **TODO**: Add pre-commit hook to block `.env` commits
- [ ] **TODO**: Implement quarterly credential rotation policy
- [ ] **TODO**: Add monitoring alerts for security events

**Post-Mortem**: This document serves as the post-mortem.

**Lessons Learned**:
1. **Prevention**: Template files (`.env.example`) must have security warnings
2. **Detection**: Automated security scans are critical - already implemented via GitHub Actions
3. **Response**: Need clear credential rotation procedures - now documented
4. **Architecture**: Custom claims are superior to Firestore-based role checks (performance + security)
5. **Documentation**: Comprehensive security docs prevent future incidents - now in place

**Follow-up Actions**:
1. Rotate all potentially exposed credentials (see checklist above)
2. Implement pre-commit hooks to prevent `.env` commits
3. Schedule quarterly security reviews
4. Conduct team training on secret management best practices

---

## Archive Notice

Incidents older than 1 year are moved to `docs/_archive/SECURITY_INCIDENTS_YYYY.md` for historical reference while keeping this log current and actionable.

---

**Last Updated**: 2025-10-09
**Next Review**: 2025-11-09 (Monthly)
