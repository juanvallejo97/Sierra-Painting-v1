# Service Account Examples

This directory contains **example templates only** - no real credentials.

## Usage

1. Copy an example file and remove the `.example` extension
2. Fill in your actual credentials
3. **Never commit the real file** - it's in `.gitignore`

## For CI/CD

**Do not use service account JSON files in CI/CD.**

Instead, use:
- GitHub Actions secrets
- OIDC Workload Identity Federation (preferred)
- Environment variables

## Local Development

For local development:

```bash
cp secrets/_examples/firebase-service-account.example.json secrets/firebase-service-account.json
# Edit secrets/firebase-service-account.json with your real credentials
export GOOGLE_APPLICATION_CREDENTIALS="secrets/firebase-service-account.json"
```

The `secrets/` directory (except `_examples/`) is gitignored.
