# Contributing to Sierra Painting

Thanks for helping improve Sierra Painting! This guide explains the development setup, workflow, and
standards.

## Setup

1. Complete the quickstart in the [README](README.md)

2. Run tests to verify your setup:

   ```bash
   flutter test
   cd functions && npm test && cd ..
   ```

## Making changes

1. Create a feature branch:

   ```bash
   git checkout -b feature/your-feature
   ```

2. Make your changes following the coding style

3. Run quality checks:

   ```bash
   flutter analyze
   ./scripts/quality.sh
   ```

4. Run tests:

   ```bash
   flutter test
   cd functions && npm test && cd ..
   ```

5. Commit using Conventional Commits format:

   ```bash
   git commit -m "feat: add new feature"
   ```

## Pull requests

- Keep changes small and focused
- Include tests for new functionality
- Update documentation when relevant
- Ensure CI passes before requesting review

## Coding and documentation style

- **Docstrings**: Use Dart doc comments for public APIs
- **Markdown**: Lint with markdownlint and Vale (Google style)
- **Commit messages**: Follow Conventional Commits

## Conventional Commits

Use these prefixes:

- `feat: ...` - New feature
- `fix: ...` - Bug fix
- `docs: ...` - Documentation changes
- `test: ...` - Test changes
- `chore: ...` - Maintenance tasks
- `refactor: ...` - Code refactoring
- `ci: ...` - CI/CD changes

Example: `docs: rewrite README quickstart and add link checks`

## Security

- Never commit secrets or credentials
- See [SECURITY.md](SECURITY.md) for reporting vulnerabilities
- Follow deny-by-default security model

## Code of Conduct

By participating, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

---