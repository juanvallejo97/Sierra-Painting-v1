# Getting started with Sierra Painting

This tutorial takes you through setting up your development environment and running Sierra Painting
for the first time.

**Expected time**: 15 minutes

**Prerequisites**:

- macOS, Linux, or Windows with WSL2
- Git installed
- Basic command line knowledge

## Install Flutter SDK

1. Download Flutter SDK ≥ 3.8.0:

   ```bash
   # Visit https://flutter.dev/docs/get-started/install
   # Follow instructions for your OS
   ```

2. Add Flutter to your PATH:

   ```bash
   export PATH="$PATH:`pwd`/flutter/bin"
   ```

3. Verify installation:

   ```bash
   flutter doctor
   ```

   **Expected output**: Flutter SDK checks should pass (Android toolchain optional for now).

## Install Node.js

1. Install Node.js ≥ 18:

   ```bash
   # Visit https://nodejs.org/
   # Download and install LTS version
   ```

2. Verify installation:

   ```bash
   node --version
   npm --version
   ```

   **Expected output**: Version numbers v18.x.x or higher.

## Install Firebase CLI

1. Install Firebase CLI:

   ```bash
   npm install -g firebase-tools@13.23.1
   ```

2. Verify installation:

   ```bash
   firebase --version
   ```

## Clone the repository

1. Clone Sierra Painting:

   ```bash
   git clone https://github.com/juanvallejo97/Sierra-Painting-v1.git
   cd Sierra-Painting-v1
   ```

2. Install Flutter dependencies:

   ```bash
   flutter pub get
   ```

3. Install Cloud Functions dependencies:

   ```bash
   cd functions
   npm ci
   cd ..
   ```

## Configure Firebase

1. Log in to Firebase:

   ```bash
   firebase login
   ```

2. Create or select a Firebase project:

   ```bash
   firebase use --add
   ```

   Select or create a development project (not production).

3. Generate Firebase configuration:

   ```bash
   flutterfire configure
   ```

   This creates `lib/firebase_options.dart`.

## Run with emulators

1. Start Firebase emulators (Terminal 1):

   ```bash
   firebase emulators:start
   ```

   **Expected output**: Emulator UI at http://localhost:4000

2. Run the app (Terminal 2):

   ```bash
   flutter run
   ```

   Select a device when prompted. The app connects to emulators automatically.

## Verify your setup

1. Open the app on your device/emulator
2. Navigate to the sign-in screen
3. Create a test account in the Auth emulator

**Success!** You now have a working development environment.

## Next steps

- [Deploy to staging](../how-to/deploy-staging.md)
- [Run tests](../how-to/run-tests.md)
- [Understand the architecture](../explanation/architecture.md)
