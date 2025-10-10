# 🚨 Security Remediation - Quick Start Guide

**Status**: ✅ Code changes committed, ⚠️ Manual actions required

---

## ⏰ DO THIS IMMEDIATELY (Next 1 Hour)

### 1. Rotate Exposed Credentials

**Why**: Your `.env` file contains real credentials that should be rotated as a precaution.

#### Firebase API Key
```bash
# 1. Go to Firebase Console
open https://console.firebase.google.com/project/YOUR_PROJECT/settings/general

# 2. Web apps → (Your app) → Copy new API key
# 3. Update .env file
# 4. Optional: Delete old key after 24h monitoring period
```

#### Firebase Deployment Token
```bash
# Generate new token
firebase login:ci

# Update GitHub Secret
# Settings → Secrets → FIREBASE_TOKEN → Update

# Test
firebase deploy --only hosting --token NEW_TOKEN_HERE
```

#### OpenAI API Key
```bash
# 1. Go to https://platform.openai.com/api-keys
# 2. Create new secret key
# 3. Update GCP Secret Manager:

echo -n "YOUR_NEW_KEY" | gcloud secrets versions add openai-api-key --data-file=-

# 4. Verify
gcloud secrets versions access latest --secret="openai-api-key"

# 5. Delete old key from OpenAI platform
```

---

## 📅 DO THIS WEEK

### 2. Deploy Custom Claims Infrastructure

```bash
# Build and deploy setUserRole function
cd functions
npm install
npm run build
firebase deploy --only functions:setUserRole
```

### 3. Bootstrap First Admin User

```bash
# Open Functions shell
firebase functions:shell

# Run bootstrap (REPLACE WITH YOUR VALUES)
const { bootstrapFirstAdmin } = require('./lib/auth/setUserRole');
await bootstrapFirstAdmin(
  'admin@yourcompany.com',
  'temporary-secure-password',
  'your-company-id'
);

# ✅ Output should show: "Admin user created successfully"
```

### 4. Migrate Existing Users to Custom Claims

See detailed guide: `docs/SECURITY_MIGRATION_GUIDE.md`

**Quick version**:
```bash
# Create migration script (see guide for full code)
# Run migration
node migration-script.js

# Verify
node verify-migration.js
```

### 5. Deploy Updated Security Rules

```bash
# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Storage rules
firebase deploy --only storage:rules

# Verify rules are active in Firebase Console
```

---

## 📖 Read These Documents

### Essential Reading (30 minutes)
1. **`SECURITY_AUDIT_SUMMARY.md`** - What was found and fixed
2. **`docs/SECURITY_MIGRATION_GUIDE.md`** - Step-by-step migration
3. **`docs/SECURITY.md`** - Comprehensive security guide

### Reference Documentation
- **`.env.example`** - Updated template with security warnings
- **`docs/SECURITY_INCIDENTS.md`** - Incident tracking
- **`storage.rules`** - Updated rules with comments
- **`firestore.rules`** - Updated rules with comments
- **`functions/src/auth/setUserRole.ts`** - Custom claims function

---

## 🔍 What Changed?

### Files Created
- ✅ `docs/SECURITY.md` - Security documentation
- ✅ `docs/SECURITY_INCIDENTS.md` - Incident log
- ✅ `docs/SECURITY_MIGRATION_GUIDE.md` - Migration guide
- ✅ `functions/src/auth/setUserRole.ts` - Custom claims function
- ✅ `SECURITY_AUDIT_SUMMARY.md` - Audit summary
- ✅ `SECURITY_QUICK_START.md` - This file

### Files Modified
- ✅ `.env.example` - Enhanced with security warnings
- ✅ `storage.rules` - Custom claims + job validation
- ✅ `firestore.rules` - Custom claims authorization
- ✅ `firebase.json` - Enhanced security headers
- ✅ `.firebaserc` - Fixed project aliases
- ✅ `functions/src/index.ts` - Export setUserRole

### Security Improvements
1. **Custom Claims**: Eliminated Firestore reads in security rules
2. **Job Validation**: Added assignment check for photo uploads
3. **Security Headers**: CSP, X-Frame-Options, Referrer-Policy, etc.
4. **Documentation**: Comprehensive security procedures
5. **Configuration**: Fixed project aliases, enhanced .env template

---

## ✅ Verification Checklist

After completing all steps above:

### Credentials Rotated
- [ ] Firebase API key updated
- [ ] Firebase deployment token updated
- [ ] OpenAI API key updated
- [ ] GitHub Secrets updated
- [ ] .env file contains NO real secrets

### Custom Claims Deployed
- [ ] setUserRole function deployed
- [ ] First admin user created
- [ ] Existing users migrated
- [ ] Custom claims verified in tokens

### Security Rules
- [ ] Firestore rules deployed
- [ ] Storage rules deployed
- [ ] Rules tested with different roles
- [ ] Job photo uploads validated

### Documentation
- [ ] Read SECURITY_AUDIT_SUMMARY.md
- [ ] Read SECURITY_MIGRATION_GUIDE.md
- [ ] Understand incident response plan
- [ ] Team trained on new procedures

---

## 🆘 Need Help?

### Common Issues

**"Custom claims not showing in token"**
→ Force token refresh: `await user.getIdToken(true);`

**"Permission denied after deploying rules"**
→ Check custom claims are set: `user.getIdTokenResult().then(r => console.log(r.claims))`

**"Migration script failing"**
→ Check service account permissions, verify Firestore user documents exist

### Documentation
- Full migration guide: `docs/SECURITY_MIGRATION_GUIDE.md`
- Security procedures: `docs/SECURITY.md`
- Incident response: `docs/SECURITY.md` → "Security Incident Response"

### Support
- Email: security@sierrapainting.com
- Escalation: See incident response plan in `docs/SECURITY.md`

---

## 📊 Success Metrics

You'll know the migration is successful when:

✅ **Performance**: Firestore read operations reduced by ~90%
✅ **Security**: All users have custom claims set
✅ **Functionality**: Role-based access control working
✅ **Compliance**: No credentials in git, audit logs active
✅ **Documentation**: Team knows new procedures

---

## 🎯 Next Steps (After Migration)

### This Month
- [ ] Increase test coverage to 60%+
- [ ] Update outdated dependencies
- [ ] Add pre-commit hooks
- [ ] Configure monitoring alerts

### Quarterly
- [ ] Security review (every 3 months)
- [ ] Credential rotation (every 90 days)
- [ ] Dependency updates
- [ ] Team security training

---

## 📈 Timeline Summary

| Task | Timeline | Priority |
|------|----------|----------|
| Rotate credentials | **Today** | 🔴 Critical |
| Deploy setUserRole | This week | 🔴 Critical |
| Migrate users | This week | 🟠 High |
| Deploy rules | This week | 🟠 High |
| Update dependencies | This month | 🟡 Medium |
| Increase test coverage | This month | 🟡 Medium |
| Quarterly review | Ongoing | 🟢 Low |

---

**Last Updated**: 2025-10-09
**Next Review**: After migration completion

Good luck with the migration! 🚀
