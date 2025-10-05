#!/usr/bin/env bash
set -euo pipefail

# --- Helpers ---
prompt() {
  local label="$1" default="${2:-}"
  local value
  read -rp "$label [${default}]: " value || true
  echo "${value:-$default}"
}

# --- Inputs (with sensible defaults) ---
REMOTE=$(prompt "Remote" "origin")
BASE_BRANCH=$(prompt "Base branch (the branch you pull from)" "main")
FEATURE_BRANCH=$(prompt "New branch name" "chore/cleanup-analyzer-warnings")
COMMIT_MSG=$(prompt "Commit message" "chore(lints): apply analyzer fixes and format")

echo ""
echo "=== Plan ==="
echo "Remote:         $REMOTE"
echo "Base branch:    $BASE_BRANCH"
echo "Feature branch: $FEATURE_BRANCH"
echo "Commit message: $COMMIT_MSG"
echo "=============="
read -rp "Continue? (y/N): " ok
[[ "${ok,,}" == "y" ]] || { echo "Aborted."; exit 1; }

# --- Workflow ---
git checkout "$BASE_BRANCH"
git pull --ff-only "$REMOTE" "$BASE_BRANCH"

git checkout -b "$FEATURE_BRANCH"

git add -A
git commit -m "$COMMIT_MSG" || echo "No changes to commit; continuing."

git push -u "$REMOTE" "$FEATURE_BRANCH"

# --- Open PR if gh is available ---
if command -v gh >/dev/null 2>&1; then
  read -rp "Create PR with GitHub CLI now? (y/N): " create
  if [[ "${create,,}" == "y" ]]; then
    # You can replace --fill with explicit title/body if you prefer
    gh pr create --fill --base "$BASE_BRANCH" --head "$FEATURE_BRANCH"
  fi
else
  echo "Tip: Install GitHub CLI (https://cli.github.com/) to open PRs from the terminal."
  echo "Or open a PR here:"
  echo "  https://github.com/$(git config --get remote.$REMOTE.url \
        | sed -E 's#.*/(.*)/(.*)\.git#\1/\2#' )/compare/$BASE_BRANCH...$FEATURE_BRANCH"
fi
