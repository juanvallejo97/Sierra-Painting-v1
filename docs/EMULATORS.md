# Firebase Emulators Setup Guide

This guide explains how to run Firebase Emulators for local development and testing.

## Prerequisites

- Node.js 18+ installed
- Firebase CLI installed globally: `npm install -g firebase-tools@13.23.1`
- Project dependencies installed: `npm install` in the `functions/` directory
- Flutter dependencies installed: `flutter pub get`

## Starting Emulators

### Quick Start

From the project root directory:

```bash
firebase emulators:start
```

This will start all configured emulators:
- **Authentication**: http://localhost:9099
- **Firestore**: http://localhost:8080
- **Cloud Functions**: http://localhost:5001
- **Storage**: http://localhost:9199
- **Emulator UI**: http://localhost:4000

### Start Specific Emulators

To start only specific emulators:

```bash
# Only Firestore and Functions
firebase emulators:start --only firestore,functions

# Only Auth and Firestore
firebase emulators:start --only auth,firestore
```

### Start with Import/Export

Import existing data:

```bash
firebase emulators:start --import=./emulator-data
```

Export data on shutdown:

```bash
firebase emulators:start --export-on-exit=./emulator-data
```

## Connecting Flutter App to Emulators

Update your Flutter app to use emulators in development mode. Add to `lib/main.dart`:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

Future<void> _connectToEmulators() async {
  const useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: false);
  
  if (useEmulator) {
    const emulatorHost = 'localhost';
    
    // Connect to Auth emulator
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
    
    // Connect to Firestore emulator
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
    
    // Connect to Storage emulator
    await FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);
    
    print('✅ Connected to Firebase Emulators');
  }
}
```

Run with emulators:

```bash
flutter run --dart-define=USE_EMULATOR=true
```

## Testing Cloud Functions

### Call HTTP Functions

```bash
# Health check
curl http://localhost:5001/<project-id>/us-central1/healthCheck

# Stripe webhook (test)
curl -X POST http://localhost:5001/<project-id>/us-central1/stripeWebhook \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

### Call Callable Functions

Use the Firebase Functions SDK in your app, it will automatically connect to the emulator when configured.

```dart
final callable = FirebaseFunctions.instance.httpsCallable('markPaymentPaid');
try {
  final result = await callable.call({
    'invoiceId': 'invoice_123',
    'amount': 100.0,
    'paymentMethod': 'cash',
    'notes': 'Test payment'
  });
  print('Success: ${result.data}');
} catch (e) {
  print('Error: $e');
}
```

## Emulator UI Features

Access the Emulator UI at http://localhost:4000

### Features:
- **Firestore**: View and edit documents in real-time
- **Authentication**: Create test users, view tokens
- **Functions**: View function logs and execution history
- **Storage**: Upload/download test files

### Useful Actions:
1. **Clear all data**: Click "Clear all data" in the UI
2. **Export data**: File → Export data
3. **View logs**: Switch to Logs tab for real-time function logs

## Seeding Test Data

Create a script to seed test data. Example `scripts/seed-emulator.ts`:

```typescript
import * as admin from 'firebase-admin';

admin.initializeApp({
  projectId: 'demo-project',
});

// Connect to emulator
process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';

async function seed() {
  const db = admin.firestore();
  
  // Create test admin user
  await db.collection('users').doc('admin-test-1').set({
    email: 'admin@test.com',
    role: 'admin',
    displayName: 'Test Admin',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  // Create test invoice
  await db.collection('invoices').doc('invoice-test-1').set({
    userId: 'user-test-1',
    amount: 1000,
    status: 'pending',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  console.log('✅ Emulator seeded with test data');
}

seed().catch(console.error);
```

Run seeding:

```bash
npx ts-node scripts/seed-emulator.ts
```

## Testing Security Rules

### From Emulator UI

1. Go to http://localhost:4000
2. Click on Firestore tab
3. Try to create/update documents
4. Check if rules deny unauthorized access

### Using Rules Test Framework

Create `firestore.rules.test.ts`:

```typescript
import * as testing from '@firebase/rules-unit-testing';

const PROJECT_ID = 'test-project';

describe('Firestore Rules', () => {
  let testEnv: testing.RulesTestEnvironment;

  beforeAll(async () => {
    testEnv = await testing.initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules: fs.readFileSync('firestore.rules', 'utf8'),
      },
    });
  });

  test('Deny invoice.paid writes from clients', async () => {
    const admin = testEnv.authenticatedContext('admin-id');
    const invoice = admin.firestore().doc('invoices/test-invoice-1');
    
    // This should be denied
    await testing.assertFails(
      invoice.update({ paid: true })
    );
  });
});
```

## Troubleshooting

### Port Already in Use

If you see "Port already in use" errors:

```bash
# Kill processes on specific port
kill -9 $(lsof -ti:4000)  # Replace 4000 with your port
```

Or change ports in `firebase.json`:

```json
{
  "emulators": {
    "ui": {
      "port": 4001
    }
  }
}
```

### Functions Not Updating

If function changes aren't reflected:

1. Rebuild functions: `cd functions && npm run build`
2. Restart emulators: `firebase emulators:start`

### Auth Emulator Connection Issues

Ensure you're using the correct host:
- **Mobile/Web Emulators**: Use `10.0.2.2` instead of `localhost` on Android emulator
- **Physical devices**: Use your computer's IP address

## Production Deployment

⚠️ **Never deploy emulator data to production!**

Always test with emulators before deploying:

```bash
# 1. Test locally
firebase emulators:start

# 2. Run tests
npm test

# 3. Deploy to staging
firebase deploy --only functions,firestore:rules --project staging

# 4. Deploy to production (after testing staging)
firebase deploy --only functions,firestore:rules --project production
```

## Resources

- [Firebase Emulator Suite Documentation](https://firebase.google.com/docs/emulator-suite)
- [Firestore Rules Testing](https://firebase.google.com/docs/rules/unit-tests)
- [Local Development Best Practices](https://firebase.google.com/docs/emulator-suite/connect_and_prototype)
