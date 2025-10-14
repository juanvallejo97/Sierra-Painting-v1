# CI/CD recommendations for documentation

This document provides recommendations for integrating documentation quality checks into CI/CD
pipelines.

## Overview

Documentation linting helps maintain consistency, readability, and quality. This project includes
configurations for multiple linters that can be integrated into GitHub Actions.

## Linter configurations

The following linter configurations are included:

- **`.vale.ini`**: Vale with Google Developer Documentation Style Guide
- **`.markdownlint.json`**: Markdown syntax and style checking
- **`.codespellrc`**: Spell checking for documentation
- **`.prettierrc.json`**: Formatting for Markdown files

## Recommended CI workflow

Add a documentation quality workflow to `.github/workflows/docs-lint.yml`:

```yaml
name: Documentation Quality

on:
  pull_request:
    paths:
      - '**.md'
      - 'docs/**'
      - '.vale.ini'
      - '.markdownlint.json'
      - '.codespellrc'
  push:
    branches: [main]
    paths:
      - '**.md'
      - 'docs/**'

jobs:
  lint-markdown:
    name: Lint Markdown files
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run markdownlint
        uses: nosborn/github-action-markdown-cli@v3.3.0
        with:
          files: .
          config_file: .markdownlint.json
          ignore_files: node_modules/ dist/ build/

  vale:
    name: Vale style guide
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Download Vale styles
        run: |
          mkdir -p .vale/styles
          cd .vale/styles
          wget -q https://github.com/errata-ai/Google/releases/latest/download/Google.zip
          unzip -q Google.zip
          rm Google.zip
      
      - uses: errata-ai/vale-action@v2
        with:
          files: docs README.md CONTRIBUTING.md
          fail_on_error: true
        env:
          GITHUB_TOKEN: ${{secrets.GITHUB_TOKEN}}

  spell-check:
    name: Spell check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install codespell
        run: pip install codespell
      
      - name: Run codespell
        run: codespell --config .codespellrc

  link-check:
    name: Check links
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Link checker
        uses: lycheeverse/lychee-action@v1
        with:
          args: --verbose --no-progress '**/*.md' --exclude-path docs/_archive
          fail: true
```

## Pre-commit hooks

For local development, add pre-commit hooks:

1. Install pre-commit:

   ```bash
   pip install pre-commit
   ```

2. Create `.pre-commit-config.yaml`:

   ```yaml
   repos:
     - repo: https://github.com/pre-commit/mirrors-prettier
       rev: v3.1.0
       hooks:
         - id: prettier
           types_or: [markdown]
     
     - repo: https://github.com/codespell-project/codespell
       rev: v2.2.6
       hooks:
         - id: codespell
           args: [--config, .codespellrc]
   ```

3. Install hooks:

   ```bash
   pre-commit install
   ```

## Tool installation

### Vale

```bash
# macOS
brew install vale

# Linux
wget https://github.com/errata-ai/vale/releases/download/v2.29.6/vale_2.29.6_Linux_64-bit.tar.gz
tar -xvzf vale_2.29.6_Linux_64-bit.tar.gz -C /usr/local/bin

# Windows
choco install vale
```

### markdownlint-cli

```bash
npm install -g markdownlint-cli
```

### codespell

```bash
pip install codespell
```

### prettier

```bash
npm install -g prettier
```

## Running locally

### Check Markdown syntax

```bash
markdownlint '**/*.md' --ignore node_modules --ignore dist
```

### Check style guide

```bash
# Download styles first (one-time)
mkdir -p .vale/styles
cd .vale/styles
wget https://github.com/errata-ai/Google/releases/latest/download/Google.zip
unzip Google.zip
rm Google.zip
cd ../..

# Run Vale
vale docs README.md CONTRIBUTING.md SECURITY.md
```

### Check spelling

```bash
codespell --config .codespellrc
```

### Format Markdown

```bash
prettier --write '**/*.md'
```

### Check links

```bash
# Install lychee
cargo install lychee
# or: brew install lychee

# Check links
lychee '**/*.md' --exclude-path docs/_archive
```

## Quality gates

Recommended quality gates for documentation:

- **Markdown linting**: 0 errors
- **Spell checking**: 0 errors (maintain ignore list in `.codespellrc`)
- **Link health**: 0 broken links in active documentation
- **Style guide**: 0 errors, warnings allowed with justification

## Ignoring false positives

### Vale

Add exceptions to `.vale.ini`:

```ini
[*.md]
BasedOnStyles = Google
# Ignore specific rules
Google.Headings = NO
```

### codespell

Add words to ignore list in `.codespellrc`:

```ini
ignore-words-list = crate,fo,ba,te,customword
```

### markdownlint

Disable rules in `.markdownlint.json`:

```json
{
  "MD013": false,  // line length
  "MD033": false   // inline HTML
}
```

## Documentation review checklist

Before merging documentation changes:

- [ ] markdownlint passes
- [ ] Vale passes (or warnings justified)
- [ ] codespell passes
- [ ] Links are valid
- [ ] Code examples tested
- [ ] Screenshots current (if applicable)

## Automated fixes

Most tools support automatic fixes:

```bash
# Fix Markdown formatting
prettier --write '**/*.md'

# Fix some markdownlint issues
markdownlint '**/*.md' --fix

# Fix common spelling mistakes
codespell --write-changes
```

## Next steps

- Review [CONTRIBUTING.md](../CONTRIBUTING.md) for contribution guidelines
- See [docs quality checks](QUALITY_CHECKS.md) for code quality
- Consult [Vale documentation](https://vale.sh/) for style customization

---