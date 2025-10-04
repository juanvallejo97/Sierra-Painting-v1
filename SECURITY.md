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
- **TruffleHog Secret Scanning**: Scans for verified secrets in commits (PR blocking)
- **Pre-commit Hooks**: Detects secrets before they are committed
- **JSON Credentials Check**: Prevents service account keys from being committed
- **Firestore Rules Tests**: Validates security rules for proper access control
- **Dependency Scanning**: Checks for known vulnerabilities in dependencies

## Secret Rotation Procedures

### If a Secret is Accidentally Committed

**CRITICAL:** If you discover that a secret has been committed to the repository, follow this procedure immediately:

#### 1. Rotate the Compromised Credential

Take immediate action based on the type of secret:

**For GCP/Firebase Service Account Keys:**
```bash
# 1. List service accounts
gcloud iam service-accounts list --project=<PROJECT_ID>

# 2. Find the compromised key
gcloud iam service-accounts keys list \
  --iam-account=<SERVICE_ACCOUNT_EMAIL>

# 3. Delete the compromised key
gcloud iam service-accounts keys delete <KEY_ID> \
  --iam-account=<SERVICE_ACCOUNT_EMAIL>

# 4. Create new key (if still needed - prefer Workload Identity)
gcloud iam service-accounts keys create new-key.json \
  --iam-account=<SERVICE_ACCOUNT_EMAIL>
```

**For Firebase API Keys:**
- Go to [Firebase Console](https://console.firebase.google.com) → Project Settings → General
- Under "Your apps" → Web App → Click the app
- Regenerate the API key or restrict it immediately
- Update App Check settings if needed

**For GitHub Personal Access Tokens:**
- Go to [GitHub Settings](https://github.com/settings/tokens) → Personal access tokens
- Delete the compromised token immediately
- Create a new token with minimum required scopes
- Update any systems using the old token

**For Third-Party API Keys (Stripe, etc.):**
- Go to the service's dashboard
- Revoke the compromised key
- Generate a new key
- Update all systems using the key

#### 2. Remove Secret from Git History

**WARNING:** This requires force-pushing and coordination with the team.

```bash
# Option A: Using git-filter-repo (recommended)
# Install: pip install git-filter-repo
git filter-repo --path <PATH_TO_SECRET_FILE> --invert-paths

# Option B: Using BFG Repo-Cleaner
# Download from: https://rtyley.github.io/bfg-repo-cleaner/
java -jar bfg.jar --delete-files <SECRET_FILE>
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Force push (coordinate with team!)
git push --force --all
git push --force --tags
```

#### 3. Notify and Document

1. **Notify the team** in Slack/Teams immediately
2. **File an incident report** documenting:
   - What secret was exposed
   - When it was committed
   - When it was discovered
   - What actions were taken
   - Impact assessment
3. **Update this document** if new patterns need to be blocked

#### 4. Post-Incident Review

- Review why the secret was committed (human error, missing .gitignore, etc.)
- Ensure pre-commit hooks are installed: `./scripts/install-hooks.sh`
- Verify GitHub Secret Scanning is enabled
- Consider additional tooling (git-secrets, detect-secrets)

### Credential Monitoring

**Daily:**
- Monitor GitHub Secret Scanning alerts: Settings → Security → Secret scanning
- Check for failed CI jobs related to secret detection

**Weekly:**
- Review GCP/Firebase audit logs for unauthorized access
- Check for anomalous API usage patterns

**Monthly:**
- Rotate all development/staging credentials
- Review and minimize service account permissions
- Audit who has access to production credentials

### Prevention Best Practices

1. **Never store secrets in code or config files**
   - Use environment variables
   - Use GCP Secret Manager
   - Use GitHub Actions secrets

2. **Always use `.gitignore`**
   ```gitignore
   # Secrets (NEVER COMMIT)
   **/*service-account*.json
   **/*credentials.json
   .env
   .env.*
   !.env.example
   ```

3. **Install and use pre-commit hooks**
   ```bash
   ./scripts/install-hooks.sh
   ```

4. **Enable GitHub security features**
   - Secret scanning + Push protection
   - Dependabot alerts
   - Code scanning (if available)

5. **Use Workload Identity Federation for CI/CD**
   - No long-lived service account keys
   - Automatic credential rotation
   - See: [docs/ops/gcp-workload-identity-setup.md](docs/ops/gcp-workload-identity-setup.md)

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
