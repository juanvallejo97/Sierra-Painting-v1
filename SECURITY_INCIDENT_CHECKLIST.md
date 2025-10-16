# Security Incident Checklist - API Key Exposure

**Date:** October 15, 2025
**Incident:** GitHub Security Alert - 5 Google API Keys detected in public repository
**Severity:** Medium (Firebase Web API keys are designed to be public, but need proper restrictions)
**Status:** 🟡 IN PROGRESS

---

## ✅ COMPLETED ACTIONS

- [x] Removed `scripts/tokens.html` from git (commit e0a4ac0)
- [x] Removed `perf_reports/*.json` from git (commit e0a4ac0)
- [x] Updated `.gitignore` to prevent future exposure
- [x] Created security documentation

---

## 🚨 CRITICAL ACTIONS REQUIRED (DO THESE NOW!)

### 1. Set API Restrictions in Google Cloud Console (15 minutes)

**URL:** https://console.cloud.google.com/apis/credentials?project=sierra-painting-staging

**For EACH API key, configure:**

#### Web API Key: `AIzaSyCiveErLn0w7ojBMQOCVak-0m897XRqvsk`
- [ ] Application restrictions → "HTTP referrers (websites)"
  - [ ] Add: `https://sierra-painting-staging.web.app/*`
  - [ ] Add: `https://sierra-painting-staging.firebaseapp.com/*`
  - [ ] Add: `http://localhost:*`
  - [ ] Add: `http://127.0.0.1:*`
- [ ] API restrictions → "Restrict key" to:
  - [ ] Firebase Authentication API
  - [ ] Cloud Firestore API
  - [ ] Cloud Storage for Firebase API
  - [ ] Firebase Hosting API
  - [ ] Identity Toolkit API

#### Android API Key: `AIzaSyAZoMH7_Z7ele3Dlg4TeHPHHRNtxKUuYAY`
- [ ] Application restrictions → "Android apps"
  - [ ] Add package: `com.sierrapainting.app`
  - [ ] Add SHA-1 fingerprint (from Firebase Console)
- [ ] API restrictions → Same as above

#### iOS API Key: `AIzaSyDNe_2n0gBPDZiOdwYvq-3r-jsqWyZ_V6g`
- [ ] Application restrictions → "iOS apps"
  - [ ] Add bundle ID: `com.sierrapainting.app`
- [ ] API restrictions → Same as above

---

### 2. Enable Firebase App Check (10 minutes)

**URL:** https://console.firebase.google.com/project/sierra-painting-staging/appcheck

- [ ] Web app → Enable ReCAPTCHA v3
  - [ ] Site key: (use existing from .env)
  - [ ] Enforcement: Enabled

- [ ] Android app → Enable Play Integrity API
  - [ ] Enforcement: Enabled

- [ ] iOS app → Enable Device Check
  - [ ] Enforcement: Enabled

- [ ] Enforce on all services:
  - [ ] Cloud Firestore
  - [ ] Cloud Storage
  - [ ] Cloud Functions
  - [ ] Realtime Database (if used)

---

### 3. Check for Unauthorized Access (5 minutes)

**URL:** https://console.cloud.google.com/logs/query?project=sierra-painting-staging

**Query to run:**
```
resource.type="firebase_domain"
timestamp>="2025-10-12"
severity>="WARNING"
```

**Look for:**
- [ ] Unusual IP addresses outside your region
- [ ] High request volumes (>10,000/hour)
- [ ] Failed authentication attempts (>100)
- [ ] Requests from suspicious user agents

**Action if suspicious activity found:**
- [ ] Document findings in this file
- [ ] Rotate API keys immediately (see section 5)
- [ ] Contact Firebase support

---

### 4. Push Security Fix to GitHub (2 minutes)

```bash
cd /home/j-p-v/AppDev/Sierra-Painting-v1
git push origin main
```

- [ ] Pushed security commit to remote
- [ ] Verified commit appears on GitHub

---

### 5. Close GitHub Security Alerts (5 minutes)

**URL:** https://github.com/juanvallejo97/Sierra-Painting-v1/security

**For each alert (#1-5):**
- [ ] Alert #5 (Web key) - Close as "Will not fix" (properly restricted)
- [ ] Alert #4 (Web key) - Close as "Will not fix" (properly restricted)
- [ ] Alert #3 (iOS key) - Close as "Will not fix" (properly restricted)
- [ ] Alert #2 (Android key) - Close as "Will not fix" (properly restricted)
- [ ] Alert #1 (tokens.html key) - Close as "Revoked" (file removed)

**Reason to provide:**
> Firebase Web API keys are designed to be client-side credentials and are inherently public. Security is enforced through API restrictions in Google Cloud Console and Firebase App Check. As of October 15, 2025, all keys have proper restrictions configured and App Check is enabled. The file `scripts/tokens.html` has been removed from the repository.

---

## ⏳ OPTIONAL ACTIONS (Consider These)

### 6. Clean Git History (Optional - 30 minutes)

**Only needed if:**
- You found evidence of unauthorized access
- You want to remove keys from git history for compliance

**Options:**
1. **BFG Repo-Cleaner** - Easiest method (see git_history_cleanup_guide.md)
2. **git-filter-repo** - More powerful (see git_history_cleanup_guide.md)
3. **Do nothing** - Keys are restricted, history cleanup not critical

**My recommendation:** Skip this unless required by security policy

---

### 7. Rotate API Keys (Only if abuse detected)

**Only if you found suspicious activity in step 3:**

```bash
# Create new Firebase apps
firebase apps:create web "Web App (New)"
firebase apps:create android "Android App (New)"
firebase apps:create ios "iOS App (New)"

# Reconfigure Flutter
flutterfire configure

# Test locally
flutter run -d chrome

# Deploy
firebase deploy

# Delete old apps in Firebase Console
```

---

## 📊 INCIDENT TIMELINE

| Time | Event |
|------|-------|
| Oct 12-13 | GitHub detected exposed API keys in commits |
| Oct 15 21:30 | User discovered security alerts |
| Oct 15 21:45 | Removed problematic files, updated .gitignore |
| Oct 15 22:00 | **[IN PROGRESS]** Configuring API restrictions |
| Oct 15 22:15 | **[PENDING]** Enable Firebase App Check |
| Oct 15 22:20 | **[PENDING]** Check logs for abuse |
| Oct 15 22:25 | **[PENDING]** Close GitHub alerts |

---

## 🔍 ROOT CAUSE ANALYSIS

**What happened:**
1. `scripts/tokens.html` was created for testing with hardcoded API key
2. Lighthouse performance reports captured API keys from running app
3. Both were committed to git without being .gitignored

**Why it happened:**
1. `.gitignore` didn't include `perf_reports/` or `scripts/tokens.html`
2. No pre-commit hook to scan for secrets
3. GitHub secret scanning alerts were not configured for immediate notification

**How to prevent:**
1. ✅ Updated `.gitignore` with security-sensitive patterns
2. 🔲 TODO: Add pre-commit hook with secret scanning (gitleaks)
3. 🔲 TODO: Configure GitHub notifications for security alerts
4. 🔲 TODO: Add section to CONTRIBUTING.md about secrets management

---

## 📚 REFERENCES

- [Firebase Security Best Practices](https://firebase.google.com/docs/projects/api-keys)
- [Google Cloud API Key Restrictions](https://cloud.google.com/docs/authentication/api-keys)
- [Firebase App Check](https://firebase.google.com/docs/app-check)
- Git History Cleanup Guide: `/tmp/git_history_cleanup_guide.md`
- Firebase Security Checklist: `/tmp/firebase_security_checklist.md`

---

## ✅ INCIDENT RESOLUTION SIGN-OFF

**Once all actions complete, fill this out:**

- [ ] All critical actions completed (sections 1-5)
- [ ] API restrictions verified and working
- [ ] App Check enforced on all services
- [ ] No evidence of unauthorized access
- [ ] GitHub alerts closed with documentation
- [ ] Team notified (if applicable)

**Completed by:** ________________
**Date:** ________________
**Status:** 🟢 RESOLVED / 🔴 ESCALATED

---

**Next Review Date:** October 22, 2025 (7 days)
**Credential Rotation Schedule:** January 15, 2026 (90 days)
