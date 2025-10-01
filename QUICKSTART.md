# Quick Start Guide

## Prerequisites
- Flutter SDK 3.16.0+
- Firebase CLI
- Node.js 18+
- Git
- A Firebase project

## 5-Minute Setup

### Step 1: Clone and Install
```bash
git clone https://github.com/juanvallejo97/Sierra-Painting-v1.git
cd Sierra-Painting-v1
flutter pub get
cd functions && npm install && cd ..
```

### Step 2: Configure Firebase
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure your Firebase project
flutterfire configure

# This will update lib/firebase_options.dart with your project credentials
```

### Step 3: Generate Hive Adapters
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Step 4: Start Emulators (Optional but Recommended)
```bash
# In one terminal
firebase emulators:start
```

### Step 5: Run the App
```bash
# In another terminal
flutter run
```

## First Login

Since this is a fresh setup, you'll need to create a user:

### Option 1: Using Firebase Console
1. Go to Firebase Console → Authentication
2. Add a user with email/password
3. Go to Firestore Database
4. Create a collection `users`
5. Add a document with the user's UID:
```json
{
  "email": "your-email@example.com",
  "isAdmin": true,
  "createdAt": "2024-01-01T00:00:00Z"
}
```

### Option 2: Using Emulator UI
1. Open http://localhost:4000
2. Go to Authentication tab
3. Add a test user
4. Go to Firestore tab
5. Create the user document as above

## Testing the App

### Test Authentication
1. Run the app
2. Log in with your created user
3. You should see the Time Clock screen

### Test RBAC
1. Navigate to Admin screen (if user is admin)
2. Try accessing /admin without admin role (should redirect)

### Test Offline Mode
1. Turn off internet/disable emulators
2. Try creating entries (they go to Hive queue)
3. Turn on internet
4. Queue processes automatically

## Deploy to Production

### Setup CI/CD
```bash
# Get Firebase CI token
firebase login:ci

# Copy the token and add to GitHub Secrets as FIREBASE_TOKEN
```

### Deploy Manually
```bash
# Deploy security rules
firebase deploy --only firestore:rules,storage:rules

# Build and deploy functions
cd functions
npm run build
firebase deploy --only functions
```

### Deploy via GitHub Actions
```bash
# For staging
git push origin main

# For production
git tag v1.0.0
git push origin v1.0.0
```

## Common Issues

### Issue: Flutter command not found
**Solution**: Install Flutter SDK and add to PATH

### Issue: Firebase command not found
**Solution**: 
```bash
npm install -g firebase-tools
```

### Issue: Build runner fails
**Solution**:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Issue: Firebase not initialized
**Solution**: Make sure you ran `flutterfire configure`

### Issue: Emulators won't start
**Solution**: Check if ports are available (9099, 8080, 5001, 9199, 4000)

## Development Workflow

### 1. Create a Feature Branch
```bash
git checkout -b feature/my-feature
```

### 2. Make Changes
Edit files in `lib/features/` or `functions/src/`

### 3. Test Locally
```bash
# Start emulators
firebase emulators:start

# Run Flutter app
flutter run

# Run tests
flutter test
```

### 4. Commit and Push
```bash
git add .
git commit -m "Add my feature"
git push origin feature/my-feature
```

### 5. Create Pull Request
CI will automatically run tests and analysis

## Project Structure Quick Reference

```
lib/
├── main.dart              # App entry point
├── app/
│   ├── app.dart          # Material App with theme
│   └── router.dart       # Routes with RBAC guards
├── core/
│   ├── providers/        # Riverpod providers
│   └── services/         # Shared services
└── features/
    ├── auth/            # Login screen
    ├── timeclock/       # Time tracking
    ├── estimates/       # Estimates management
    ├── invoices/        # Invoice management
    └── admin/           # Admin panel

functions/src/
├── index.ts             # Cloud Functions
├── schemas/            # Zod validation schemas
└── services/           # Business logic (PDF, etc.)
```

## Tips

1. **Use Emulators**: Always develop with emulators to avoid production data issues
2. **Check Rules**: Verify Firestore rules in emulator UI (http://localhost:4000)
3. **Monitor Logs**: Watch Flutter console and Functions logs
4. **Test Offline**: Always test offline scenarios
5. **Follow Structure**: Keep feature code in respective folders

## Support

For issues or questions:
1. Check the full README.md
2. Review docs/KickoffTicket.md
3. Check Firebase Console logs
4. Review security rules

## Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Riverpod Documentation](https://riverpod.dev)
- [go_router Documentation](https://pub.dev/packages/go_router)
