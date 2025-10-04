# Deploy to staging

This guide shows you how to deploy Sierra Painting to the staging environment.

## Prerequisites

- Staging Firebase project configured
- Firebase CLI authenticated
- All tests passing

## Automatic deployment

Changes pushed to the `main` branch automatically deploy to staging via GitHub Actions.

1. Merge your changes to `main`:

   ```bash
   git checkout main
   git pull origin main
   git merge feature/your-feature
   git push origin main
   ```

2. Monitor deployment:

   - Visit [GitHub Actions](https://github.com/juanvallejo97/Sierra-Painting-v1/actions)
   - Click on the running workflow
   - View deployment logs

**Expected duration**: 5-10 minutes

## Manual deployment

Use manual deployment for testing or when CI is unavailable.

1. Ensure you're using the staging project:

   ```bash
   firebase use staging
   ```

2. Run tests locally:

   ```bash
   flutter test
   cd functions && npm test && cd ..
   ```

3. Deploy to staging:

   ```bash
   firebase deploy
   ```

   This deploys:
   - Firestore rules
   - Firestore indexes
   - Cloud Functions
   - Storage rules

## Verify deployment

1. Check Firebase Console:

   - Visit https://console.firebase.google.com/project/sierra-painting-staging
   - Verify Functions are deployed
   - Check Firestore rules updated

2. Run smoke tests:

   ```bash
   npm run smoke
   ```

3. Test key flows manually:

   - Sign in
   - Clock in/out
   - View jobs today

## Troubleshooting

**"Insufficient permissions" error**:

- Ensure your account has Editor role in the staging project
- Run `firebase login --reauth`

**Functions deployment fails**:

- Check Cloud Functions logs
- Verify Node.js version matches `engines` in `functions/package.json`

**Rules deployment fails**:

- Validate rules syntax: `firebase deploy --only firestore:rules --dry-run`

## Next steps

- [Monitor staging performance](check-performance.md)
- [Deploy to production](deploy-production.md)
