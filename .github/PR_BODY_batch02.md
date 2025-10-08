**What**
- Add Jest teardown + runInBand/forceExit to fix open handles
- Harden smoke: require markers, configurable SMOKE_URL/STAGING_URL
- Add Functions artifacts cleanup policy in staging/prod/release
- Pin Node 20 + firebase-tools@13.23.1 everywhere; npm ci
- Concurrency: cancel overlapping deploys

**How to test**
- Verify CI shows Node 20 and firebase-tools 13.23.1
- Staging job builds (web + functions), deploys, then runs smoke
- Smoke target: `${{ vars.STAGING_URL }}`
- Jest rules tests exit cleanly (no worker-exit warning)

**Acceptance**
- All CI jobs green; smoke passes
- No interactive prompts in deploy logs
- Branch protection shows smoke as required check
