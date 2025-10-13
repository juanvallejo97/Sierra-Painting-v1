# US-EAST4 Setup Checklist

**Region**: us-east4 (Northern Virginia)
**Rationale**: Closest to East Coast location for optimal latency

---

## ✅ Already Configured

Your codebase is **already configured** for us-east4:

### firebase.json
```json
{
  "firestore": {
    "location": "us-east4",  // ✅ Configured
    ...
  },
  "functions": {
    "endpoints": {
      "createLead": {
        "region": "us-east4",  // ✅ Configured
        ...
      },
      "healthCheck": {
        "region": "us-east4",  // ✅ Configured
        ...
      }
    }
  }
}
```

**No code changes needed!** Your configuration is ready for us-east4.

---

## 🎯 What You MUST Do When Creating Projects

When you create `sierra-painting-staging` and `sierra-painting-prod` in Firebase Console:

### CRITICAL: Select us-east4 for ALL Services

#### 1. Firestore Database
```
Firebase Console → Firestore Database → Create database
→ Location: us-east4 (Northern Virginia)  ⚠️ CRITICAL
```

#### 2. Cloud Storage
```
Firebase Console → Storage → Get started
→ Location: us-east4 (Northern Virginia)  ⚠️ CRITICAL
```

#### 3. Cloud Functions
```
(Automatically deployed to us-east4 via firebase.json config)
No manual selection needed ✅
```

---

## ⚠️ IMPORTANT: Region is Immutable

Once you select a region for Firestore/Storage, **you CANNOT change it**.

**If you accidentally select the wrong region**:
- You must delete the project and start over, OR
- Create a new project and migrate data (2-4 hours effort)

**Double-check before clicking "Enable"!**

---

## 📋 Setup Workflow (30 Minutes)

### Step 1: Create Staging Project (5 min)

1. Go to https://console.firebase.google.com/
2. Click "Add project"
3. Project name: **Sierra Painting Staging**
4. Project ID: **sierra-painting-staging**
5. Click "Create project"

### Step 2: Enable Staging Services (10 min)

1. **Firestore**:
   - Build → Firestore Database → Create database
   - Mode: Test mode
   - Location: **us-east4** ⚠️
   - Enable

2. **Storage**:
   - Build → Storage → Get started
   - Mode: Test mode
   - Location: **us-east4** ⚠️
   - Done

3. **Authentication**:
   - Build → Authentication → Get started
   - Enable Email/Password provider

4. **App Check**:
   - Build → App Check
   - Register web app
   - Get reCAPTCHA v3 site key

### Step 3: Create Production Project (5 min)

Repeat Step 1 with:
- Project name: **Sierra Painting Production**
- Project ID: **sierra-painting-prod**

### Step 4: Enable Production Services (10 min)

Repeat Step 2 for production project.
**CRITICAL**: Select **us-east4** for Firestore and Storage!

---

## 🚀 Automated Deployment (After Project Creation)

Once both projects are created with us-east4:

```powershell
# Verify projects exist
firebase projects:list

# Should show:
# - sierra-painting-staging ✅
# - sierra-painting-prod ✅

# Run automated deployment
pwsh ./scripts/deploy_to_new_projects.ps1
```

This will deploy:
- ✅ 11 Firestore indexes
- ✅ Security rules (0 warnings)
- ✅ Cloud Functions (to us-east4)

---

## 🔍 Verification

### After Deployment

#### Check Firestore Location
```
Firebase Console → Firestore → Settings
Should show: "Database location: us-east4"
```

#### Check Storage Location
```
Firebase Console → Storage → Settings
Should show: "Default bucket location: us-east4"
```

#### Check Functions Region
```bash
firebase functions:list
# Should show region: us-east4
```

---

## 📊 Expected Performance (us-east4)

From East Coast location:

| Service | Latency (p95) | Baseline |
|---------|---------------|----------|
| Firestore reads | ~20ms | ✅ Excellent |
| Firestore writes | ~30ms | ✅ Excellent |
| Storage uploads | ~80ms | ✅ Good |
| Cloud Functions | ~150ms | ✅ Good |

Compare to us-central1: ~30-50ms slower across all services.

---

## ✅ Checklist

Before starting setup:

- [ ] Read this entire document
- [ ] Understand region is immutable after creation
- [ ] Ready to select **us-east4** for both projects

During setup (CRITICAL):

**Staging Project**:
- [ ] Firestore location: **us-east4** ⚠️
- [ ] Storage location: **us-east4** ⚠️
- [ ] Authentication enabled
- [ ] App Check configured

**Production Project**:
- [ ] Firestore location: **us-east4** ⚠️
- [ ] Storage location: **us-east4** ⚠️
- [ ] Authentication enabled
- [ ] App Check configured

After setup:

- [ ] Verify both projects show us-east4 in settings
- [ ] Run `pwsh ./scripts/deploy_to_new_projects.ps1`
- [ ] Verify 11 indexes deployed
- [ ] Verify rules deployed (0 warnings)
- [ ] Test app latency

---

## 🆘 Troubleshooting

### "I accidentally selected us-central1"

**Solution**:
1. Delete the Firestore database (if nothing critical stored yet)
2. Re-enable Firestore with us-east4
3. Re-deploy indexes

OR:

1. Delete the entire project
2. Create new project
3. Select us-east4 when enabling services

### "Region option doesn't show us-east4"

**Possible causes**:
- Free plan limitations (upgrade to Blaze plan)
- Region not available for your account type

**Solution**: Upgrade to Blaze (pay-as-you-go) plan to access all regions.

---

## 📚 References

- **Region config docs**: `docs/FIREBASE_REGION_CONFIG.md`
- **Setup guide**: `FIREBASE_PROJECT_SETUP_GUIDE.md`
- **Deployment script**: `scripts/deploy_to_new_projects.ps1`
- **Firebase locations**: https://firebase.google.com/docs/projects/locations

---

## 🎯 Summary

**TL;DR**:
1. ✅ Code already configured for us-east4
2. ⚠️ **CRITICAL**: Select **us-east4** when enabling Firestore/Storage
3. ✅ Run automated deployment script after project creation
4. ✅ Expected latency: ~20-30ms from East Coast

**You're ready to create the projects!** Just remember: **us-east4** for everything.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
