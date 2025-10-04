# Developer Onboarding

## Prerequisites
- Flutter >= 3.8
- Node.js >= 18
- Firebase CLI
- Git and a code editor

## Setup (Quick)
```bash
git clone https://github.com/juanvallejo97/Sierra-Painting-v1.git
cd Sierra-Painting-v1
flutter pub get

# Functions
cd functions && npm ci && cd ..

# Firebase project selection
firebase login
firebase use --add   # select or create (staging/prod aliases)

# Configure FlutterFire
flutterfire configure
```

## Running Locally
```bash
# Terminal 1
firebase emulators:start

# Terminal 2
flutter run
```

## Tests
```bash
flutter analyze && flutter test
cd functions && npm run typecheck && npm run lint && npm test
```

## Contributing
- Follow Conventional Commits
- Open PRs from feature branches
- See CONTRIBUTING.md for details

---