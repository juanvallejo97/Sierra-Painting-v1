# Security Policy

## Reporting vulnerabilities

If you discover a security issue, please email the maintainers directly. We will acknowledge
receipt within 3 business days.

**Do not open public issues for sensitive security reports.**

**Contact**: Create a private security advisory at
<https://github.com/juanvallejo97/Sierra-Painting-v1/security/advisories>

## Supported versions

We support security fixes for the latest released version only.

## Security best practices

### Secrets handling

Never commit secrets or credentials to the repository:

- Service account JSON files
- API keys
- Private keys
- Database credentials
- Environment variables with sensitive data

**For CI/CD**: Use GitHub Actions secrets and OIDC Workload Identity Federation instead of service
account keys.

**For local development**: Copy examples from `secrets/_examples/` and use `.env` files (which are
gitignored).

### Firebase security

All Firebase services use deny-by-default security rules:

- Authentication required for all operations
- Role-based access control (RBAC) with custom claims
- Organization-scoped data isolation
- Server-side only operations for payments and sensitive data

See `firestore.rules` and `storage.rules` for complete rules.

### App Check

Firebase App Check protects backend resources from abuse:

- **Android**: Play Integrity API (production), debug provider (development)
- **iOS**: App Attest (production), debug provider (development)
- **Web**: reCAPTCHA v3

## Automated security checks

The repository runs automated security checks on every pull request:

- JSON credentials check (prevents committing service accounts)
- Firestore rules tests (validates access control)
- Dependency scanning (checks for known vulnerabilities)

## References

- [Firebase Security Best Practices](https://firebase.google.com/docs/rules/best-practices)
- [Firestore Rules Reference](https://firebase.google.com/docs/firestore/security/rules-structure)

---
