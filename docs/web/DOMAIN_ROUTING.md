# Domain Routing Configuration

> **Version:** 1.0.0  
> **Status:** Active  
> **Last Updated:** 2025  
> **Author:** Development Team

---

## Overview

This document describes the domain routing strategy for the Sierra Painting application, which serves both a Flutter mobile web app and a Next.js web application from a single domain.

---

## Routing Strategy

### Chosen Approach: Path-Based Routing

We use Firebase Hosting with path-based routing to serve different applications from a single domain:

```
https://sierrapainting.com/
├── /                          → Flutter web build (mobile-first landing)
├── /web/**                    → Next.js web application
├── /api/**                    → Firebase Cloud Functions (backend)
└── /static/**                 → Static assets (images, documents)
```

### Rationale

**Advantages:**
- ✅ Single domain = simpler SSL/CDN management
- ✅ No CORS issues (same origin)
- ✅ Shared auth cookies work seamlessly
- ✅ Easier deployment (single Firebase project)
- ✅ Better for SEO (unified domain authority)

**Disadvantages:**
- ⚠️ Path prefix required for web app (`/web/*`)
- ⚠️ Need to configure routing carefully to avoid conflicts

### Alternative Considered: Subdomain Routing

**Not chosen** but documented for future reference:

```
https://sierrapainting.com/        → Flutter web
https://web.sierrapainting.com/    → Next.js web app
https://api.sierrapainting.com/    → Backend APIs
```

Would require:
- Cookie domain: `.sierrapainting.com`
- CORS configuration
- Multiple SSL certificates
- More complex DNS setup

---

## Firebase Hosting Configuration

### Current firebase.json

```json
{
  "hosting": {
    "public": "build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "/web/**",
        "destination": "/web/index.html"
      },
      {
        "source": "/api/**",
        "function": "api"
      },
      {
        "source": "**",
        "destination": "/index.html"
      }
    ],
    "headers": [
      {
        "source": "/web/**",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "public, max-age=0, must-revalidate"
          }
        ]
      },
      {
        "source": "/web/_next/static/**",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "public, max-age=31536000, immutable"
          }
        ]
      }
    ]
  }
}
```

### Rewrite Rules Explanation

1. **`/web/** → Next.js App**
   - All paths starting with `/web/` are served by Next.js
   - Next.js handles its own routing internally
   - Static assets served from `/web/_next/static/`

2. **`/api/** → Cloud Functions**
   - API calls routed to Firebase Cloud Functions
   - Maintains existing mobile app compatibility
   - No changes to backend contracts

3. **`/** → Flutter Web**
   - Catch-all for mobile web experience
   - Serves Flutter's build/web output
   - Maintains mobile-first approach

---

## URL Mapping

### External URLs (User-Facing)

| URL | Served By | Purpose |
|-----|-----------|---------|
| `/` | Flutter | Landing page (mobile-first) |
| `/login` | Flutter | Mobile app login |
| `/web` | Next.js | Web app home |
| `/web/login` | Next.js | Web app login |
| `/web/timeclock` | Next.js | Time clock interface |
| `/web/invoices` | Next.js | Invoice management |
| `/web/estimates` | Next.js | Estimate management |
| `/web/admin` | Next.js | Admin dashboard |
| `/api/clockIn` | Cloud Functions | Clock in API |
| `/api/clockOut` | Cloud Functions | Clock out API |
| `/api/createLead` | Cloud Functions | Lead creation API |

### Internal Next.js Routes

Within the Next.js app (`/web/`), routes are defined in `src/app/`:

```
webapp/src/app/
├── layout.tsx              # Root layout
├── page.tsx                # /web → Home/redirect
├── login/
│   └── page.tsx           # /web/login → Login page
├── (authenticated)/        # Route group with auth middleware
│   ├── layout.tsx         # Authenticated layout
│   ├── timeclock/
│   │   └── page.tsx       # /web/timeclock
│   ├── invoices/
│   │   └── page.tsx       # /web/invoices
│   ├── estimates/
│   │   └── page.tsx       # /web/estimates
│   └── admin/
│       └── page.tsx       # /web/admin
└── error.tsx              # Error boundary
```

---

## Cookie & Session Management

### Cookie Domain

**Setting:** `domain=sierrapainting.com` (or appropriate domain)

**Scope:** Accessible to:
- Flutter web at `/`
- Next.js web at `/web/*`
- APIs at `/api/*`

### Session Cookie Details

```javascript
{
  name: '__session',
  secure: true,                    // HTTPS only
  httpOnly: true,                  // No JS access
  sameSite: 'lax',                // CSRF protection
  path: '/',                       // Available everywhere
  maxAge: 1209600,                // 14 days
  domain: 'sierrapainting.com'    // Shared across paths
}
```

### Authentication Flow

1. **User logs in** (via Firebase Auth SDK)
2. **Client receives ID token** from Firebase
3. **Next.js middleware verifies token** on protected routes
4. **Token stored in httpOnly cookie** for subsequent requests
5. **Server-side verification** on each protected page load

---

## CORS Configuration

### Not Required for Path-Based Routing

Since all requests are same-origin, no CORS configuration needed.

### If Subdomain Were Used (Future)

Would require:
```javascript
{
  origin: [
    'https://sierrapainting.com',
    'https://web.sierrapainting.com',
    'https://api.sierrapainting.com'
  ],
  credentials: true
}
```

---

## CDN & Caching Strategy

### Firebase Hosting CDN

Firebase Hosting automatically provides:
- Global CDN distribution
- SSL certificate management
- HTTP/2 and HTTP/3 support
- Automatic compression (gzip, brotli)

### Cache Headers by Path

| Path | Cache-Control | Rationale |
|------|---------------|-----------|
| `/web/*.html` | `public, max-age=0, must-revalidate` | Always fresh HTML |
| `/web/_next/static/**` | `public, max-age=31536000, immutable` | Hashed assets, cache forever |
| `/web/_next/image/**` | `public, max-age=31536000` | Optimized images |
| `/api/**` | `private, no-cache` | Dynamic API responses |
| `/**` (Flutter) | Per Flutter build config | Mobile web assets |

### Next.js Static Assets

Next.js automatically generates content-hashed filenames for static assets:
- `_next/static/chunks/[hash].js`
- `_next/static/css/[hash].css`
- `_next/static/media/[hash].[ext]`

These can be cached indefinitely (`immutable`).

---

## Deployment Process

### Build Order

1. **Build Flutter web** (if mobile web changes)
   ```bash
   flutter build web
   ```

2. **Build Next.js app**
   ```bash
   cd webapp
   npm run build
   ```

3. **Copy Next.js build to hosting directory**
   ```bash
   cp -r webapp/.next/standalone/* build/web/web/
   cp -r webapp/.next/static build/web/web/_next/
   cp -r webapp/public/* build/web/web/
   ```

4. **Deploy to Firebase**
   ```bash
   firebase deploy --only hosting
   ```

### Staging vs Production

**Staging:**
- Firebase project: `sierra-painting-staging`
- Domain: `staging.sierrapainting.com`
- Test with canary flags enabled

**Production:**
- Firebase project: `sierra-painting-prod`
- Domain: `sierrapainting.com`
- Gradual rollout with monitoring

---

## Testing & Verification

### Local Development

1. **Start Firebase emulators**
   ```bash
   firebase emulators:start
   ```

2. **Start Next.js dev server**
   ```bash
   cd webapp
   npm run dev
   ```

3. **Access at:**
   - Flutter: http://localhost:5000
   - Next.js: http://localhost:3000
   - APIs: http://localhost:5001

### Routing Tests

Verify these scenarios:
- ✅ `/` loads Flutter web
- ✅ `/web` redirects to Next.js home
- ✅ `/web/login` loads Next.js login
- ✅ `/web/timeclock` requires auth
- ✅ `/api/clockIn` calls Cloud Function
- ✅ Auth cookie accessible across paths
- ✅ Deep links work correctly
- ✅ Back/forward navigation works
- ✅ 404 errors handled gracefully

---

## Monitoring & Debugging

### Key Metrics

**Per Route:**
- Request count
- Response time (P50, P95, P99)
- Error rate
- Cache hit rate

**Firebase Hosting:**
- Total requests
- Bandwidth usage
- CDN cache hit ratio
- SSL/TLS version distribution

### Debugging Tools

1. **Firebase Hosting logs**
   ```bash
   firebase hosting:logs
   ```

2. **Browser DevTools**
   - Network tab: Check headers, caching
   - Application tab: Inspect cookies
   - Console: Check for errors

3. **Lighthouse**
   - Run on `/web/*` routes
   - Check for routing issues
   - Verify caching strategy

---

## Rollback Procedure

### If Routing Issues Occur

1. **Immediate:** Remove `/web/**` rewrite from `firebase.json`
2. **Redeploy hosting:**
   ```bash
   firebase deploy --only hosting
   ```
3. **Verify:** All mobile paths still work
4. **Investigate:** Check logs, test locally
5. **Fix and redeploy:** Once issue identified

### If Performance Degrades

1. **Check CDN cache hit rate**
2. **Verify cache headers** are set correctly
3. **Test with and without `/web` prefix**
4. **Roll back if necessary**

---

## Security Considerations

### Headers Applied

All routes receive:
- `X-Frame-Options: DENY`
- `X-Content-Type-Options: nosniff`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy: camera=(), microphone=(), geolocation=()`

### Cookie Security

- ✅ `HttpOnly`: Prevents XSS attacks
- ✅ `Secure`: HTTPS only
- ✅ `SameSite=Lax`: CSRF protection
- ✅ Proper domain scoping

### API Protection

- ✅ Firebase App Check on all functions
- ✅ Authentication verification
- ✅ Rate limiting via Firebase quota
- ✅ RBAC enforcement

---

## Future Considerations

### Custom Domain Setup

When moving from Firebase default domain to custom domain:

1. **Verify domain ownership**
2. **Set up DNS records** (A/AAAA or CNAME)
3. **Enable SSL** (automatic with Firebase)
4. **Update cookie domain** in code
5. **Test all paths** thoroughly

### Multi-Region Hosting

Firebase Hosting automatically uses multi-region CDN. For custom needs:
- Cloud Run for server-side rendering
- Cloud CDN for additional control
- Geo-routing if needed

### Path Prefix Removal (Future)

If we want to remove `/web` prefix:
1. Move Flutter web to `/mobile` or subdomain
2. Make Next.js the root (`/`)
3. Update all internal links
4. Set up redirects for SEO
5. Gradual migration with monitoring

---

## Conclusion

The path-based routing strategy provides a simple, secure, and performant way to serve both Flutter mobile web and Next.js web applications from a single domain. This approach minimizes configuration complexity while maintaining full compatibility with the existing mobile app and backend APIs.

**Key Benefits:**
- ✅ Zero CORS issues
- ✅ Shared authentication
- ✅ Simple deployment
- ✅ Good SEO potential
- ✅ Easy to monitor and debug

**Next Steps:**
- Implement in firebase.json
- Test routing in staging
- Deploy to production with canary
- Monitor and iterate
