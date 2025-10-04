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
- Follow Conventional Commits (e.g., `feat:`, `fix:`, `docs:`)
- Create feature branches from `main`
- Use issue templates in `.github/ISSUE_TEMPLATE/`
- Run tests and lint before submitting PRs
- Ensure CI passes before requesting review

---