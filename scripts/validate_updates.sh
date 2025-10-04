#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GOV="$ROOT/.copilot/sierra_painting_update.yaml"
mkdir -p "$ROOT/.reports"
PASS=0; WARN=0; FAIL=0
ok(){ echo "✅ $*"; PASS=$((PASS+1)); }
warn(){ echo "⚠️ $*"; WARN=$((WARN+1)); }
die(){ echo "❌ $*"; FAIL=$((FAIL+1)); }

[ -f "$GOV" ] && ok "governance present" || die "missing $GOV"

# Locks
for f in pubspec.lock functions/package-lock.json firestore-tests/package-lock.json; do
  [ -f "$ROOT/$f" ] && ok "lock present: $f" || warn "lock missing: $f"
done

# run_audit - JSON-based npm audit
run_audit () {
  local dir="$1"
  if [ -f "$ROOT/$dir/package.json" ]; then
    (cd "$ROOT/$dir" && npm ci && npm audit --audit-level=high --omit=dev --json > "$ROOT/.reports/${dir}-audit.json" || true)
    node - <<'NODE' "$ROOT/.reports/${dir}-audit.json" || exitcode=$?
const fs=require('fs');const f=process.argv[1];const j=JSON.parse(fs.readFileSync(f,'utf8'));
const meta=j.metadata||{};const vul=j.vulnerabilities||meta.vulnerabilities||{};
const total=Object.values(vul).map(v=>v.total||v).reduce((a,b)=>a+b,0);process.exit(total?2:0);
NODE
    if [ "${exitcode:-0}" -eq 0 ]; then ok "npm audit clean: $dir"; else warn "npm audit issues: $dir"; fi
  fi
}
run_audit functions
run_audit firestore-tests

# Major version checks (simple parse from pubspec.lock)
check_major () { pkg="$1"; major="$2"; v=$(awk "/^ $pkg:/,/version:/" "$ROOT/pubspec.lock" | awk '/version:/{print $2;exit}' || true); [[ "$v" =~ ^$major\. ]] && ok "$pkg $v is ${major}.x" || warn "$pkg $v not ${major}.x"; }
[ -f "$ROOT/pubspec.lock" ] || warn "pubspec.lock missing; cannot verify majors"
[ -f "$ROOT/pubspec.lock" ] && check_major firebase_core 4
[ -f "$ROOT/pubspec.lock" ] && check_major flutter_riverpod 2

echo -e "\nTotal checks: $((PASS+WARN+FAIL))\nPassed: $PASS\nWarnings: $WARN\nFailed: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
