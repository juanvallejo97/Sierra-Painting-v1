# Contributing to Sierra Painting

Thank you for your interest in contributing to Sierra Painting! This document provides guidelines for contributing to the project.

## Code of Conduct

- Be respectful and professional
- Focus on constructive feedback
- Help create a welcoming environment

## Development Setup

See [SETUP.md](SETUP.md) for detailed setup instructions.

## Making Changes

### 1. Create a Feature Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/bug-description
```

### 2. Make Your Changes

- Follow the existing code style
- Write meaningful commit messages
- Keep changes focused and atomic

### 3. Testing

Before submitting:

```bash
# Run Flutter tests
flutter test

# Run linting
flutter analyze

# Format code
flutter format .

# Test Functions (if changed)
cd functions
npm run lint
npm run build
npm test
```

### 4. Commit Guidelines

Use conventional commit messages:

```
feat: Add new payment method
fix: Resolve offline sync issue
docs: Update README with new instructions
style: Format code according to guidelines
refactor: Restructure service layer
test: Add unit tests for payment service
chore: Update dependencies
```

### 5. Submit Pull Request

- Push your branch to GitHub
- Create a Pull Request
- Describe your changes clearly
- Link any related issues

## Code Style

### Dart/Flutter

- Follow the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use the project's `analysis_options.yaml`
- Prefer `const` constructors when possible
- Use meaningful variable names

### TypeScript

- Follow the ESLint configuration
- Use TypeScript types, avoid `any`
- Add JSDoc comments for public functions
- Keep functions small and focused

## Project Structure

```
lib/
├── core/                    # Core functionality
│   ├── config/             # Configuration files
│   ├── services/           # Core services
│   └── utils/              # Utility functions
├── features/               # Feature modules
│   └── [feature]/
│       ├── models/        # Data models
│       ├── screens/       # UI screens
│       ├── widgets/       # Feature widgets
│       └── services/      # Feature services
└── shared/                # Shared components
    ├── widgets/           # Reusable widgets
    └── models/            # Shared models
```

## Adding New Features

### 1. Create Feature Module

```
lib/features/new-feature/
├── models/
│   └── new_feature_model.dart
├── screens/
│   └── new_feature_screen.dart
├── widgets/
│   └── new_feature_widget.dart
└── services/
    └── new_feature_service.dart
```

### 2. Add Tests

```
test/features/new-feature/
├── models/
│   └── new_feature_model_test.dart
└── services/
    └── new_feature_service_test.dart
```

### 3. Update Documentation

- Update README.md if needed
- Add feature documentation in `docs/`
- Update ARCHITECTURE.md for architectural changes

## Firebase Changes

### Firestore Rules

When modifying `firestore.rules`:

1. Test locally with Firebase Emulator
2. Document changes in comments
3. Test with multiple user roles
4. Deploy to staging first

### Cloud Functions

When modifying `functions/`:

1. Update TypeScript types
2. Add Zod validation schemas
3. Write unit tests
4. Test locally with Firebase Emulator
5. Check Cloud Functions logs after deployment

### Storage Rules

When modifying `storage.rules`:

1. Test upload/download scenarios
2. Verify size limits
3. Test file type restrictions
4. Check permissions for different roles

## Accessibility Guidelines

All UI changes must maintain WCAG 2.2 AA compliance:

- **Contrast**: Minimum 4.5:1 for text
- **Touch Targets**: Minimum 48x48 logical pixels
- **Semantic Labels**: All interactive elements
- **Screen Reader**: Test with TalkBack/VoiceOver
- **Keyboard Navigation**: Ensure full keyboard access

## Testing Guidelines

### Unit Tests

- Test business logic
- Mock external dependencies
- Aim for >80% code coverage

### Widget Tests

- Test UI components
- Verify accessibility
- Test user interactions

### Integration Tests

- Test critical user flows
- Test offline scenarios
- Test Firebase integration

## Documentation

### Code Comments

- Use comments for complex logic
- Avoid obvious comments
- Keep comments up to date

### README Updates

Update README.md when:
- Adding new features
- Changing setup process
- Updating dependencies

### Architecture Documentation

Update ARCHITECTURE.md when:
- Changing system architecture
- Adding new services
- Modifying data flow

## Performance

Consider performance impact:
- Lazy loading for large lists
- Image optimization
- Minimize Firestore reads
- Cache frequently accessed data
- Profile before and after changes

## Security

Security considerations:
- Never commit secrets or API keys
- Follow principle of least privilege
- Validate all user inputs
- Use App Check for API protection
- Review security rules carefully

## Deployment

### Staging

Test changes in staging environment:
```bash
# Deploy to staging project
firebase use staging
firebase deploy
```

### Production

Deploy to production:
```bash
# Deploy to production project
firebase use production
firebase deploy
```

## Getting Help

- Check existing documentation
- Search closed issues
- Ask in discussions
- Create a new issue if needed

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

## Questions?

Feel free to open an issue for any questions about contributing!
