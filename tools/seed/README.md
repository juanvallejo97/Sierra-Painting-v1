# Staging Seed Script

## Purpose

Create reproducible demo data for `sierra-painting-staging` in under 2 minutes.

## Prerequisites

1. **Firebase Service Account Key**:
   - Download from Firebase Console → Project Settings → Service Accounts → Generate New Private Key
   - Save as `firebase-service-account-staging.json` in project root
   - **DO NOT commit this file** (already in .gitignore)

2. **Install dependencies**:
   ```bash
   npm install
   ```

## Usage

### Apply Seed (Live)

```bash
npm run seed:staging
```

Creates:
- Company: "Sierra Painting – Staging Demo"
- Users: demo-admin, demo-worker, demo-customer (all with password `Demo123!`)
- Job: "Maple Ave Interior" (Albany, NY with 125m geofence)
- Assignment: Worker assigned to job (this week)
- Customer: "Taylor Home"

### Dry-Run (Check Only)

```bash
npm run seed:staging:check
```

Shows what would be created without making any changes.

## Idempotency

The script is idempotent - running it multiple times:
- Updates existing records (merge)
- Does not create duplicates
- Safe to re-run at any time

## Deterministic IDs

All IDs are deterministic (not random):
- Company: `demo-company-staging`
- Users: `staging-demo-admin-001`, `staging-demo-worker-001`, `staging-demo-customer-001`
- Job: `staging-demo-job-001`
- Assignment: `staging-demo-assignment-001`

## Output

After successful seed:

```
✅ Seed complete!

📝 Demo credentials:
   Admin:    demo-admin@staging.test / Demo123!
   Worker:   demo-worker@staging.test / Demo123!
   Customer: demo-customer@staging.test / Demo123!

🎯 Ready for demo!
```

## Troubleshooting

### Error: "Cannot find module 'firebase-service-account-staging.json'"

**Solution**: Download service account key from Firebase Console and save it as `firebase-service-account-staging.json` in project root.

### Error: "auth/email-already-exists"

**Solution**: This is expected on re-runs. The script will update the existing user instead.

### Error: "Insufficient permissions"

**Solution**: Ensure the service account has Editor or Owner role in Firebase project.

## Next Steps

After seeding:

1. **Deploy to staging**:
   ```bash
   firebase use staging
   firebase deploy --only firestore:rules,firestore:indexes,functions
   ```

2. **Configure feature flags** (Firebase Console → Remote Config):
   ```json
   {
     "timeclock_enabled": true,
     "admin_review_enabled": true,
     "invoice_from_time_enabled": true
   }
   ```

3. **Run demo** using `STAGING_DEMO_SCRIPT.md`
