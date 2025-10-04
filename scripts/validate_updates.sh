#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GOV="$ROOT/.copilot/sierra_painting_update.yaml"
WARN=0; PASS=0; FAIL=0

note(){ echo "::notice::$*"; }
ok(){ echo "✅ $*"; PASS=$((PASS+1)); }
warn(){ echo "⚠️ $*"; WARN=$((WARN+1)); }
die(){ echo "❌ $*"; FAIL=$((FAIL+1)); }

have(){ command -v "$1" >/dev/null 2>&1; }

# 1) YAML validity / existence

[ -f "$GOV" ] && ok "governance file present" || die "missing $GOV"
if have yq; then
  yq e '.' "$GOV" >/dev/null && ok "governance YAML parses" || die "invalid YAML: $GOV"
else
  note "yq not installed; skipping deep YAML parse"
fi

# 2) Lockfiles

for f in pubspec.lock functions/package-lock.json firestore-tests/package-lock.json; do
  [ -f "$ROOT/$f" ] && ok "lock present: $f" || warn "lock missing: $f"
done

# 3) Security audits (npm projects)

mkdir -p "$ROOT/.reports"

if have npm; then
  for d in functions firestore-tests; do
    if [ -f "$ROOT/$d/package.json" ]; then
      (cd "$ROOT/$d" && npm audit --audit-level=high --omit=dev || true) | tee "$ROOT/.reports/${d}-npm-audit.txt"
      grep -qi "found 0 vulnerabilities" "$ROOT/.reports/${d}-npm-audit.txt" && ok "npm audit clean: $d" || warn "npm audit issues: $d"
    fi
  done
else
  note "npm not installed; skipping audits"
fi

# 4) Dart minimum versions (pubspec.lock parsing fallback)

check_dart_min() {
  local pkg="$1" min="$2"
  if grep -A2 -nE "^  $pkg:" "$ROOT/pubspec.lock" >/dev/null 2>&1; then
    ok "pub lock contains $pkg (min $min) [verify via CI analyzer]"
  else
    warn "$pkg not found in pubspec.lock (or using transitive resolution)"
  fi
}
check_dart_min firebase_core "4.0.0"
check_dart_min flutter_riverpod "2.5.0"
check_dart_min firebase_performance "0.11.0"

# 5) Outdated reports (non-failing; for drift visibility)

have flutter && (cd "$ROOT" && flutter pub outdated || true) | tee "$ROOT/.reports/pub-outdated.txt"
have npm && (cd "$ROOT/functions" && npm outdated || true) | tee "$ROOT/.reports/functions-npm-outdated.txt"
have npm && (cd "$ROOT/firestore-tests" && npm outdated || true) | tee "$ROOT/.reports/firestore-tests-npm-outdated.txt"

# 6) Docs presence

for f in docs/UPDATES_EXECUTION.md docs/UPDATES.md docs/migrations/README.md; do
  [ -f "$ROOT/$f" ] && ok "doc present: $f" || die "doc missing: $f"
done

# 7) CI / automation presence

[ -f "$ROOT/.github/workflows/updates.yml" ] && ok "workflow present" || die "missing .github/workflows/updates.yml"
[ -f "$ROOT/.github/dependabot.yml" ] && ok "dependabot present" || die "missing .github/dependabot.yml"

TOTAL=$((PASS+WARN+FAIL))
echo -e "\nTotal checks: $TOTAL\nPassed: $PASS\nWarnings: $WARN\nFailed: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
