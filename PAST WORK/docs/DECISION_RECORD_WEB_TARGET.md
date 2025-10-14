# Decision Record — Canonical Web Target
**Status:** Accepted  
**Date:** 2025-10-08  
**Decision:** Use **Flutter Web** in `/web` as the *only* canonical web target.  
**Alternatives considered:** `/web_react`, `/webapp` folders maintained in parallel.  
**Rationale:** Single codebase, consistent UX, zero drift, simpler CI/CD and ownership.  
**Consequences:**  
- `/web_react` and `/webapp` are deprecated and **blocked** in CI.  
- Any web work must modify `/web` only.  
**Enforcement:**  
- CI job `path-guard` fails PRs that add/modify files under deprecated paths.  
- CODEOWNERS requires Platform review for changes to `/web/**`. 
