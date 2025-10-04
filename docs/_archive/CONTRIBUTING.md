# Contributing to Sierra Painting

Thank you for your interest in contributing!

## Getting Started
- Read the README and docs/index.md for architecture and workflows.
- Set up your environment using the Quick Start in the README.
- Ensure Firebase emulators can run locally.

## Branching
- Create a feature branch from `main`: `git checkout -b feat/short-description`
- Use prefixes: `feat`, `fix`, `docs`, `chore`, `test`, `ci`.

## Commit Messages
- Follow Conventional Commits:
  - `feat(scope): add ...`
  - `fix(scope): correct ...`
  - `docs(scope): update ...`

## Tests & Lint
- Flutter: `flutter analyze && flutter test`
- Functions: `(cd functions && npm run typecheck && npm run lint && npm test)`

## Pull Requests
- Link relevant issues and user stories.
- Include screenshots or logs when helpful.
- Ensure CI passes and the PR template is filled out.

## Security
- Do not include secrets in code or PRs. See `docs/secrets/`.
- Sensitive operations must follow the deny-by-default model (see `docs/Security.md`).

## Code of Conduct
By participating, you agree to abide by the Code of Conduct (CODE_OF_CONDUCT.md).

---