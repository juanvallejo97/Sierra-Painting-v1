# Setup Guide

This guide will walk you through setting up the Sierra Painting application from scratch.

## Prerequisites

Before you begin, ensure you have the following installed:

1. **Flutter SDK** (version 3.0.0 or higher)
   - Install from: https://flutter.dev/docs/get-started/install
   - Verify: `flutter doctor`

2. **Node.js** (version 18 or higher)
   - Install from: https://nodejs.org/
   - Verify: `node --version`

3. **Firebase CLI**
   ```bash
   npm install -g firebase-tools
   firebase --version
   ```

4. **Git**
   - Verify: `git --version`

## Step 1: Firebase Project Setup

1. **Create a Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Click "Add project"
   - Follow the setup wizard

2. **Enable Firebase Services**
   - **Authentication**: Enable Email/Password sign-in method
   - **Firestore Database**: Create database in production mode
   - **Storage**: Initialize Cloud Storage
   - **Functions**: Set up billing (required for Cloud Functions)
   - **App Check**: Enable App Check for your platform

3. **Configure App Check**
   - For Android: Set up Play Integrity
   - For iOS: Set up App Attest
   - For Web: Set up reCAPTCHA

## Step 2: Clone and Configure

1. **Clone the repository**
   ```bash
   git clone https://github.com/juanvallejo97/Sierra-Painting-v1.git
   cd Sierra-Painting-v1
   ```

2. **Configure Firebase**
   ```bash
   # Login to Firebase
   firebase login

   # Select your Firebase project
   firebase use --add
   
   # Update .firebaserc with your project ID
   ```

3. **Generate Firebase Configuration for Flutter**
   ```bash
   # Install FlutterFire CLI
   dart pub global activate flutterfire_cli
   
   # Configure platforms (iOS, Android, Web)
   flutterfire configure
   ```
   
   This will update `lib/core/config/firebase_options.dart` with your project's credentials.

## Step 3: Install Dependencies

1. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

2. **Install Functions dependencies**
   ```bash
   cd functions
   npm install
   cd ..
   ```

## Step 4: Deploy Firebase Backend

1. **Deploy Firestore Security Rules**
   ```bash
   firebase deploy --only firestore:rules
   ```

2. **Deploy Storage Rules**
   ```bash
   firebase deploy --only storage:rules
   ```

3. **Deploy Firestore Indexes**
   ```bash
   firebase deploy --only firestore:indexes
   ```

4. **Build and Deploy Cloud Functions**
   ```bash
   cd functions
   npm run build
   firebase deploy --only functions
   cd ..
   ```

## Step 5: Configure Environment Variables

1. **Functions Environment Variables**
   ```bash
   cd functions
   cp .env.example .env
   # Edit .env with your actual values
   ```

2. **Set Firebase Functions Config** (for Stripe, optional)
   ```bash
   firebase functions:config:set stripe.secret_key="sk_test_..." stripe.webhook_secret="whsec_..."
   ```

## Step 6: Setup Remote Config (Feature Flags)

1. Go to Firebase Console → Remote Config
2. Add the following parameters:
   - `stripe_enabled` (Boolean): `false`
   - `offline_mode_enabled` (Boolean): `true`

## Step 7: Run the Application

1. **Start an emulator or connect a device**
   ```bash
   # List available devices
   flutter devices
   ```

2. **Run in debug mode**
   ```bash
   flutter run
   ```

3. **Or run with specific device**
   ```bash
   flutter run -d <device-id>
   ```

## Step 8: Testing

1. **Run Flutter tests**
   ```bash
   flutter test
   ```

2. **Run Functions tests**
   ```bash
   cd functions
   npm test
   cd ..
   ```

3. **Run linting**
   ```bash
   # Flutter
   flutter analyze
   
   # Functions
   cd functions
   npm run lint
   cd ..
   ```

## Step 9: Building for Production

### Android
```bash
# Create release build
flutter build apk --release

# Or create app bundle
flutter build appbundle --release
```

### iOS
```bash
# Build for iOS (requires macOS)
flutter build ios --release
```

### Web
```bash
# Build web version
flutter build web --release

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

## Step 10: Configure CI/CD

The project includes GitHub Actions workflows. To enable them:

1. **Add Firebase token to GitHub Secrets**
   ```bash
   firebase login:ci
   # Copy the token
   ```

2. **Add to GitHub Repository Secrets**
   - Go to Settings → Secrets and variables → Actions
   - Add `FIREBASE_TOKEN` with the token from above

3. **Enable GitHub Actions**
   - The workflows will automatically run on push/PR

## Stripe Setup (Optional)

If you want to enable Stripe payments:

1. **Create Stripe Account**
   - Sign up at https://stripe.com

2. **Get API Keys**
   - Get your test API keys from Stripe Dashboard

3. **Configure Webhook**
   - Create webhook endpoint pointing to your Cloud Function
   - URL: `https://<region>-<project-id>.cloudfunctions.net/stripeWebhook`
   - Select events: `checkout.session.completed`, `payment_intent.succeeded`, `payment_intent.payment_failed`

4. **Enable Feature Flag**
   - In Firebase Remote Config, set `stripe_enabled` to `true`

5. **Deploy Functions with Stripe Config**
   ```bash
   firebase functions:config:set stripe.secret_key="sk_live_..." stripe.webhook_secret="whsec_..."
   firebase deploy --only functions
   ```

## Troubleshooting

### Flutter Doctor Issues
```bash
flutter doctor
# Follow the instructions to fix any issues
```

### Firebase Connection Issues
- Verify `firebase.json` configuration
- Check `.firebaserc` has correct project ID
- Ensure you're logged in: `firebase login`

### Build Issues
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

## Security Checklist

Before going to production:

- [ ] Update all Firebase API keys in `firebase_options.dart`
- [ ] Review and test Firestore security rules
- [ ] Review and test Storage security rules
- [ ] Enable App Check for all platforms
- [ ] Set up proper user roles in Firestore
- [ ] Configure proper CORS settings
- [ ] Enable Firebase Audit Logs
- [ ] Set up monitoring and alerts
- [ ] Test offline functionality
- [ ] Review and update environment variables
- [ ] Enable production Stripe keys (if using)

## Support

If you encounter issues:
1. Check the [README.md](README.md) for general information
2. Review Firebase Console for errors
3. Check Cloud Functions logs: `firebase functions:log`
4. Open an issue on GitHub

## Next Steps

- Customize the theme in `lib/core/config/theme_config.dart`
- Add your business logic in `lib/features/`
- Configure user roles and permissions
- Set up monitoring and analytics
- Add custom Cloud Functions as needed
