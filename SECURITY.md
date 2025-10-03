# Security Policy

## Secrets Handling

### Never Commit Secrets

**Critical:** Never commit real service account JSON files, API keys, or credentials to the repository.

### Prohibited Files

The following files must **never** be committed:
- `*service-account*.json`
- `*-service-account*.json`
- `firebase-adminsdk-*.json`
- `*credentials.json`
- Any file containing `private_key` or `"type": "service_account"`

### Best Practices

1. **Use GitHub Actions Secrets**: Store sensitive credentials in GitHub repository secrets
2. **Use OIDC Workload Identity**: Prefer Workload Identity Federation over service account keys
3. **Local Development**: Copy examples from `secrets/_examples/` and set environment variables
4. **Environment Variables**: Use `.env` files (which are gitignored) for local configuration

### Example Placeholder

For documentation purposes, use placeholder files like:

```json
{
  "type": "service_account",
  "project_id": "REDACTED",
  "private_key_id": "REDACTED",
  "private_key": "REDACTED",
  "client_email": "REDACTED",
  "client_id": "REDACTED"
}
```

## CI/CD Security

### Workload Identity Federation

All deployment workflows use OIDC Workload Identity Federation instead of service account keys:

```yaml
permissions:
  contents: read
  id-token: write

- uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: ${{ vars.GCP_WORKLOAD_IDENTITY_PROVIDER }}
    service_account: ${{ vars.GCP_SERVICE_ACCOUNT }}
```

### Automated Checks

The repository has automated security checks that run on every pull request:
- **JSON Credentials Check**: Prevents service account keys from being committed
- **Firestore Rules Tests**: Validates security rules for proper access control
- **Dependency Scanning**: Checks for known vulnerabilities in dependencies

## Reporting Security Issues

If you discover a security vulnerability, please:

1. **Do not** open a public issue
2. Email the maintainers directly at [security contact email]
3. Provide details about the vulnerability and potential impact
4. Allow reasonable time for a fix before public disclosure

## Firestore Security Rules

All Firestore security rules follow a **deny-by-default** policy:
- Authentication required for all operations
- Role-based access control (RBAC) via custom claims
- Organization-scoped data isolation
- Server-side only operations for sensitive data (payments, leads)

See `firestore.rules` for complete security rules.

## Firebase App Check

Firebase App Check is enabled in production to protect backend resources from abuse:
- **Android**: Play Integrity API (production) / Debug provider (development)
- **iOS**: App Attest (production) / Debug provider (development)
- **Web**: ReCaptcha v3

## References

- [GitHub OIDC Workload Identity Setup](docs/ops/gcp-workload-identity-setup.md)
- [Firebase Security Best Practices](https://firebase.google.com/docs/rules/best-practices)
- [Firestore Rules Reference](https://firebase.google.com/docs/firestore/security/rules-structure)
