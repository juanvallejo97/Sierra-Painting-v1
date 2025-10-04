# Web Routing Strategy

**Status:** In Transition  
**Last Updated:** October 2025

## Current State

Sierra Painting currently has two web targets:

### 1. Flutter Web (Canonical - Keep)

**Location:** `web/`  
**Build Output:** `build/web/`  
**Routes:** `/` (root and all routes except `/web/**`)  
**Status:** ✅ **Active and canonical**

**Purpose:**
- Primary web application
- Mobile-first responsive design
- Same codebase as Android/iOS apps
- Consistent UI/UX across all platforms

**Build:**
```bash
flutter build web --release
firebase deploy --only hosting
```

### 2. Next.js App (Deprecated - Remove)

**Location:** `webapp/`  
**Build Output:** `webapp/.next/`  
**Routes:** `/web/**` (deprecated routes)  
**Status:** ⚠️ **DEPRECATED** (see `webapp/DEPRECATION_NOTICE.md`)

**Purpose:**
- Originally intended for separate web-optimized routes
- Created code duplication and maintenance burden
- Inconsistent with mobile app experience

**Build:**
```bash
cd webapp && npm run build
# See scripts/build-and-deploy.sh (also deprecated)
```

## Migration Plan

### Phase 1: Deprecation (Current)

- ✅ Add deprecation notice: `webapp/DEPRECATION_NOTICE.md`
- ✅ Document routing strategy in this file
- ✅ Update build scripts with deprecation warnings
- ⏳ Monitor usage of `/web/**` routes

### Phase 2: Route Migration

- [ ] Audit all `/web/**` routes for usage
- [ ] Migrate critical functionality to Flutter web
- [ ] Add redirects from `/web/**` to corresponding Flutter routes
- [ ] Update firebase.json to redirect `/web/**` → `/`

### Phase 3: Removal

- [ ] Remove `webapp/` directory entirely
- [ ] Remove `/web/**` rewrites from firebase.json
- [ ] Remove Next.js headers from firebase.json
- [ ] Remove `scripts/build-and-deploy.sh`
- [ ] Update deployment documentation

## Firebase Hosting Configuration

Current rewrites in `firebase.json`:

```json
{
  "rewrites": [
    {
      "source": "/web/**",
      "destination": "/web/index.html"  // Next.js app (DEPRECATED)
    },
    {
      "source": "**",
      "destination": "/index.html"      // Flutter web (CANONICAL)
    }
  ]
}
```

**After migration:**

```json
{
  "rewrites": [
    {
      "source": "**",
      "destination": "/index.html"      // Flutter web only
    }
  ]
}
```

## Benefits of Single Web Target

1. **Consistent UX**: Same UI/UX across mobile and web
2. **Code Reuse**: Single codebase for all platforms
3. **Simplified Deployment**: One build process
4. **Reduced Maintenance**: No duplicate code
5. **Performance**: Flutter web is optimized for size
6. **Type Safety**: Dart compile-time checks

## Testing Strategy

Before removing webapp/:

1. **Analytics**: Check usage of `/web/**` routes (Firebase Analytics)
2. **User Testing**: Ensure Flutter web has feature parity
3. **Performance**: Compare bundle sizes and load times
4. **Accessibility**: Verify WCAG 2.2 AA compliance
5. **SEO**: Ensure proper meta tags and sitemap

## Related Documentation

- [webapp/DEPRECATION_NOTICE.md](../webapp/DEPRECATION_NOTICE.md)
- [ARCHITECTURE.md](../ARCHITECTURE.md#routing-strategy)
- [docs/web/IMPLEMENTATION_SUMMARY.md](web/IMPLEMENTATION_SUMMARY.md)

## Timeline

- **Q4 2025**: Deprecation notices and monitoring
- **Q1 2026**: Route migration and testing
- **Q2 2026**: Complete removal (target date)

## Questions or Concerns?

Contact project maintainers or open a GitHub issue using the Tech Task template.
