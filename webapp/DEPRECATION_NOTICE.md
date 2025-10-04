# Deprecation Notice: webapp/ Directory

**Status:** ⚠️ DEPRECATED  
**Replacement:** Use `web/` directory for Flutter web builds  
**Date:** October 2025  

## Background

This directory contained a Next.js web application that was running parallel to the Flutter web build. As part of the V1 ship-readiness refactor, we are consolidating to a single web target to:

- Reduce maintenance overhead
- Simplify deployment pipeline
- Ensure consistent user experience
- Reduce bundle size and build complexity

## Migration Path

The canonical web target is now `web/` which contains the Flutter web application. 

### For Routing

Previously:
- `/` → Flutter web
- `/web/**` → Next.js app (this directory)

After migration:
- `/` → Flutter web (all routes)

### For Deployment

The build and deployment script (`scripts/build-and-deploy.sh`) has been updated to remove references to this directory.

## Related Documentation

- [docs/web/IMPLEMENTATION_SUMMARY.md](../docs/web/IMPLEMENTATION_SUMMARY.md) - Previous Next.js integration details
- [docs/MIGRATION.md](../docs/MIGRATION.md) - General migration guide
- [firebase.json](../firebase.json) - Firebase Hosting configuration

## Support

If you need to access the previous Next.js implementation for reference:
1. Check git history: `git log -- webapp/`
2. See commit: [to be added when webapp is removed]
3. Contact: Project maintainers

**Note:** This directory will be removed in a future commit after the migration window closes.
