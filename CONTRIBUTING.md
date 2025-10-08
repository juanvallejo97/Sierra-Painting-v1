# Contributing to Sierra Painting

Thank you for your interest in contributing to Sierra Painting!

## Getting Started

1. **Clone the repository**
   ```bash
   git clone https://github.com/juanvallejo97/Sierra-Painting-v1.git
   cd Sierra-Painting-v1
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   cd functions && npm install
   cd ../firestore-tests && npm install
   ```

3. **Setup Firebase** (if needed)
   ```bash
   flutterfire configure
   ```

## Development Workflow

### Branch, Commit, PR
- Branch format: `feat/<scope>`, `fix/<scope>`, `chore/<scope>`
- Conventional commits (enforced): `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`
- PRs must pass CI (analyze + tests), and include the PR checklist.

### Running tests locally (Windows-friendly)
```powershell
# Stable TEMP/TMP to avoid flutter_test_listener flake
$env:TEMP='C:\tmp'; $env:TMP='C:\tmp'
flutter clean; flutter pub get
flutter analyze
flutter test --concurrency=1 -r expanded
```

### Code Style
- Use **Conventional Commits** for commit messages
- Follow the existing code style (enforced by `analysis_options.yaml`)
- Always use package imports: `package:sierra_painting/...`
- Add trailing commas for better formatting
- Use single quotes for strings
- `flutter format` + `flutter analyze`
- Avoid `print`; use `debugPrint` or logging.
- Keep mobile vs web scaffolds gated via `core/platform.dart`.

### Before Committing
Run these commands to ensure code quality:

```bash
# Format code
dart format .

# Analyze for issues
flutter analyze

# Run tests
flutter test

# Optional: Run full test suite with coverage
make test
```

### Commit Message Format
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(auth): add biometric authentication

fix(timeclock): resolve clock-out timestamp issue

docs(readme): update installation instructions
```

## Pull Request Process

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following the code style guidelines

3. **Test thoroughly**
   - Unit tests for new logic
   - Integration tests for user flows
   - Update existing tests as needed

4. **Submit a pull request**
   - Provide clear description of changes
   - Reference any related issues
   - Ensure all CI checks pass

5. **Code review**
   - Address reviewer feedback
   - Keep commits focused and atomic

## Dependency Management

### Adding Dependencies
- Add necessary dependencies to `pubspec.yaml`
- Justify any `dependency_overrides` with comments
- Prefer stable, well-maintained packages
- Check for conflicts with existing dependencies

### Updating Dependencies
```bash
# See outdated packages
flutter pub outdated

# Update to latest compatible versions
flutter pub upgrade

# Update to major versions (use with caution)
flutter pub upgrade --major-versions
```

## Testing Guidelines

### Unit Tests
- Test file should mirror source file location
- Use descriptive test names
- Group related tests
- Mock external dependencies

### Integration Tests
- Place in `integration_test/` directory
- Test complete user flows
- Keep tests deterministic

### Test Coverage
- Aim for ≥60% coverage for core services
- Use `flutter test --coverage` to generate reports

## Architecture Decisions

Before making significant architectural changes:
1. Review existing Architecture Decision Records (ADRs) in `docs/adr/`
2. Discuss with maintainers
3. Document new decisions in an ADR

## Questions or Issues?

- Check existing issues and documentation
- Open a new issue for bugs or feature requests
- Join discussions in pull requests

## Code of Conduct

Please follow our [Code of Conduct](CODE_OF_CONDUCT.md) in all interactions.

---

Thank you for contributing to Sierra Painting! 🎨

# Contributing

- [ ] Run `flutter analyze` and ensure no errors/warnings
- [ ] All tests pass (unit, integration, rules)
- [ ] Rule tests green (no cross-user reads)
- [ ] Link to relevant blueprint/issue in PR
- [ ] Add runbook notes if new features or flows
