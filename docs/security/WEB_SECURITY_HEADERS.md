# Web Security Headers

**Version:** 1.0
**Last Updated:** 2025-10-12
**Status:** ✅ **IMPLEMENTED**

---

## Overview

This document describes the HTTP security headers configured for the Sierra Painting web application. These headers provide defense-in-depth protection against common web vulnerabilities.

**Configuration Location:** `firebase.json` (hosting.headers section)

---

## Implemented Headers

### 1. Content-Security-Policy (CSP)

**Purpose:** Prevents Cross-Site Scripting (XSS) and data injection attacks

**Value:**
```
default-src 'self' data: blob: https:;
script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' https://*.gstatic.com https://www.google.com https://www.gstatic.com;
style-src 'self' 'unsafe-inline';
img-src 'self' data: https://firebasestorage.googleapis.com https://lh3.googleusercontent.com;
font-src 'self' data: https://fonts.gstatic.com;
connect-src 'self' https://*.googleapis.com https://*.gstatic.com https://*.firebaseio.com https://firestore.googleapis.com https://firebasestorage.googleapis.com https://www.google-analytics.com https://www.googletagmanager.com https://firebaselogging-pa.googleapis.com https://firebaselogging.googleapis.com ws://localhost:* http://localhost:*;
worker-src 'self' blob:;
base-uri 'self';
object-src 'none';
frame-ancestors 'self';
manifest-src 'self';
frame-src 'self' https://www.google.com;
```

**Breakdown:**

| Directive | Value | Purpose |
|-----------|-------|---------|
| `default-src` | `'self' data: blob: https:` | Default policy for unlisted resources |
| `script-src` | `'self' 'unsafe-inline' 'wasm-unsafe-eval' *.gstatic.com` | Allow Flutter compiled JS + Google services |
| `style-src` | `'self' 'unsafe-inline'` | Allow inline styles (required for Flutter) |
| `img-src` | `'self' data: firebasestorage.googleapis.com` | Allow images from Firebase Storage + data URIs |
| `font-src` | `'self' data: fonts.gstatic.com` | Allow Google Fonts |
| `connect-src` | `'self' *.googleapis.com ...` | Allow Firebase/Google API connections |
| `worker-src` | `'self' blob:` | Allow service workers (PWA) |
| `base-uri` | `'self'` | Prevent base tag injection |
| `object-src` | `'none'` | Block plugins (Flash, Java, etc.) |
| `frame-ancestors` | `'self'` | Prevent embedding in iframes (clickjacking) |
| `manifest-src` | `'self'` | Allow PWA manifest |
| `frame-src` | `'self' www.google.com` | Allow Google reCAPTCHA frames |

**Security Notes:**
- ⚠️ `'unsafe-inline'` required for Flutter web (compiled CSS/JS includes inline styles)
- ⚠️ `'wasm-unsafe-eval'` required for WebAssembly (Dart compiled to Wasm)
- ✅ `object-src 'none'` blocks dangerous plugins
- ✅ `frame-ancestors 'self'` prevents clickjacking

**Testing CSP Violations:**
```javascript
// Open browser DevTools console
// CSP violations will be logged like:
// "Refused to load the script 'https://evil.com/script.js' because it violates
//  the following Content Security Policy directive: "script-src 'self' ..."
```

---

### 2. Strict-Transport-Security (HSTS)

**Purpose:** Forces browsers to use HTTPS, preventing SSL stripping attacks

**Value:** `max-age=31536000; includeSubDomains; preload`

**Breakdown:**
- `max-age=31536000`: HSTS policy lasts 1 year (31,536,000 seconds)
- `includeSubDomains`: Apply HSTS to all subdomains
- `preload`: Eligible for browser HSTS preload lists

**How It Works:**
1. First visit: Browser receives HSTS header over HTTPS
2. Subsequent visits: Browser automatically upgrades HTTP → HTTPS (even if user types `http://`)
3. Certificate errors: Browser blocks access (prevents MITM attacks)

**HSTS Preload List:**

To add to browsers' built-in HSTS preload lists (Chrome, Firefox, Safari):
1. Visit https://hstspreload.org
2. Submit domain: `sierrapainting.com`
3. Requirements:
   - Serve valid certificate
   - Redirect HTTP → HTTPS
   - Serve HSTS header on base domain and all subdomains
   - `max-age >= 31536000` (1 year)
   - `includeSubDomains` directive present
   - `preload` directive present

**⚠️ Warning:** Once preloaded, removal takes months. Test thoroughly before submitting.

---

### 3. X-Frame-Options

**Purpose:** Prevents clickjacking attacks (embedding site in malicious iframes)

**Value:** `SAMEORIGIN`

**Options:**
- `DENY`: Never allow framing (most secure)
- `SAMEORIGIN`: Allow framing by same origin only (our setting)
- `ALLOW-FROM uri`: Allow specific origin (deprecated)

**Why SAMEORIGIN:**
- Allows embedding in our own site (if needed for admin tools)
- Blocks external sites from framing us

**Modern Alternative:** CSP `frame-ancestors` directive (also configured)

---

### 4. X-Content-Type-Options

**Purpose:** Prevents MIME type sniffing attacks

**Value:** `nosniff`

**How It Works:**
- Without `nosniff`: Browser might execute a file sent as `text/plain` if it looks like JavaScript
- With `nosniff`: Browser strictly follows `Content-Type` header

**Attack Scenario Prevented:**
```
Attacker uploads malicious.txt to user profile
Browser sniffs content, detects JavaScript, executes it
Result: XSS attack

With nosniff: Browser refuses to execute (Content-Type is text/plain)
```

---

### 5. X-XSS-Protection

**Purpose:** Enables browser's built-in XSS filter

**Value:** `1; mode=block`

**Breakdown:**
- `1`: Enable XSS filter
- `mode=block`: Block page rendering if XSS detected (don't try to sanitize)

**⚠️ Deprecation Note:**
- Modern browsers rely on CSP instead
- Included for backward compatibility with older browsers
- Not a replacement for proper CSP

---

### 6. Referrer-Policy

**Purpose:** Controls how much referrer information is sent with requests

**Value:** `strict-origin-when-cross-origin`

**Behavior:**
- Same-origin requests: Send full URL as referrer
- Cross-origin HTTPS → HTTPS: Send origin only (no path)
- Cross-origin HTTPS → HTTP: Send nothing (security downgrade)

**Example:**
```
User on: https://sierrapainting.com/admin/users/123
Clicks link to: https://google.com

Referrer sent to Google: https://sierrapainting.com
(Path /admin/users/123 is stripped)
```

**Privacy Benefit:** Prevents leaking sensitive URL paths to third parties

---

### 7. Permissions-Policy

**Purpose:** Controls which browser features can be used

**Value:** `geolocation=(self), camera=(), microphone=(), payment=(), usb=()`

**Breakdown:**

| Feature | Policy | Meaning |
|---------|--------|---------|
| `geolocation` | `(self)` | Allow geolocation API (needed for timeclock geofencing) |
| `camera` | `()` | Block camera access (not used) |
| `microphone` | `()` | Block microphone access (not used) |
| `payment` | `()` | Block Payment Request API (not used) |
| `usb` | `()` | Block USB device access (not used) |

**Security Benefit:** Limits attack surface if XSS vulnerability exists

**Example Attack Prevented:**
```
Attacker injects XSS payload:
<script>navigator.mediaDevices.getUserMedia({audio: true})</script>

With Permissions-Policy: Browser blocks microphone access
Without: Attacker could eavesdrop on user
```

---

## Header Priority

Headers are applied in order:

1. **index.html**: `Cache-Control: no-cache` (always fresh)
2. **Static assets** (*.js, *.css, etc.): `Cache-Control: public, max-age=31536000` (1 year)
3. **All routes** (`**`): Security headers (CSP, HSTS, etc.)

---

## Testing Security Headers

### Browser DevTools

**Check Headers:**
1. Open site in Chrome/Firefox
2. Press F12 → Network tab
3. Refresh page
4. Click on main document request (usually first row)
5. View Response Headers section

**Expected Headers:**
```
content-security-policy: default-src 'self' ...
strict-transport-security: max-age=31536000; includeSubDomains; preload
x-frame-options: SAMEORIGIN
x-content-type-options: nosniff
x-xss-protection: 1; mode=block
referrer-policy: strict-origin-when-cross-origin
permissions-policy: geolocation=(self), camera=(), ...
```

### Online Security Scanners

**1. SecurityHeaders.com**
```
https://securityheaders.com/?q=https://sierrapainting.com
```
- Grades headers A-F
- Expected grade: **A** or **A+**

**2. Mozilla Observatory**
```
https://observatory.mozilla.org/analyze/sierrapainting.com
```
- Comprehensive security scan
- Expected score: **90+/100**

**3. SSL Labs**
```
https://www.ssllabs.com/ssltest/analyze.html?d=sierrapainting.com
```
- Tests SSL/TLS configuration
- Expected grade: **A** or **A+**

### Manual CSP Testing

**Test CSP blocks unauthorized scripts:**
```javascript
// Open browser console on site
// Try to inject script from unauthorized domain
var script = document.createElement('script');
script.src = 'https://evil.com/malicious.js';
document.body.appendChild(script);

// Expected: CSP violation error in console
// Refused to load the script 'https://evil.com/malicious.js' because it
// violates the following Content Security Policy directive: "script-src 'self' ..."
```

---

## Troubleshooting

### Issue: HSTS Certificate Error

**Symptom:** Browser shows "Your connection is not private" error and won't let user bypass

**Cause:** HSTS header was previously sent, but certificate is now invalid/expired

**Fix:**
1. Renew certificate immediately
2. Or clear HSTS cache:
   - Chrome: `chrome://net-internals/#hsts` → Delete domain
   - Firefox: Clear all browsing data → Check "Active Logins"

**Prevention:** Monitor certificate expiration (Firebase Hosting auto-renews)

---

### Issue: CSP Blocks Required Resource

**Symptom:** Console shows CSP violation for legitimate resource

**Example:**
```
Refused to load the image 'https://cdn.example.com/logo.png' because it violates
the following Content Security Policy directive: "img-src 'self' data: ..."
```

**Fix:** Add domain to appropriate CSP directive in `firebase.json`:
```json
{
  "key": "Content-Security-Policy",
  "value": "... img-src 'self' data: https://cdn.example.com; ..."
}
```

**Deploy:** `firebase deploy --only hosting`

---

### Issue: iframe Not Loading (X-Frame-Options)

**Symptom:** Cannot embed site in iframe, even from same domain

**Cause:** `X-Frame-Options: DENY` (too restrictive)

**Current Setting:** `SAMEORIGIN` (allows same-origin iframes)

**If Need External Embedding:** Remove `X-Frame-Options`, rely on CSP `frame-ancestors` only

---

## Deployment

### Staging Deployment

```bash
# Deploy hosting configuration
firebase deploy --only hosting --project sierra-painting-staging

# Test headers
curl -I https://sierra-painting-staging.web.app | grep -i "strict-transport"
# Expected: strict-transport-security: max-age=31536000; includeSubDomains; preload
```

### Production Deployment

```bash
# Deploy hosting configuration
firebase deploy --only hosting --project sierra-painting-prod

# Verify headers
curl -I https://sierrapainting.com | grep -i "security"
```

---

## Maintenance

### Annual Review Checklist

- [ ] Review CSP directives (remove unused domains)
- [ ] Check for CSP violations in browser logs
- [ ] Run SecurityHeaders.com scan (maintain A+ grade)
- [ ] Review Permissions-Policy (add restrictions for new features)
- [ ] Verify HSTS preload status (if submitted)
- [ ] Update documentation with any header changes

### When Adding New Third-Party Service

1. Identify domains used by service (check Network tab)
2. Update CSP directives in `firebase.json`
3. Test in staging environment
4. Check browser console for CSP violations
5. Deploy to production
6. Update this documentation

---

## Compliance

### OWASP Top 10

These headers mitigate:

- **A03:2021 - Injection** (CSP prevents XSS)
- **A05:2021 - Security Misconfiguration** (Headers enforce secure defaults)
- **A07:2021 - Identification and Authentication Failures** (HSTS prevents session hijacking)

### PCI-DSS

- **6.5.7**: Prevent XSS (CSP)
- **4.1**: Use strong cryptography for data transmission (HSTS)

### NIST Cybersecurity Framework

- **PR.AC-5**: Protect network integrity (HSTS, CSP)
- **PR.DS-5**: Protections against data leaks (Referrer-Policy)

---

## References

### Standards

- [CSP Level 3 Specification](https://www.w3.org/TR/CSP3/)
- [RFC 6797: HTTP Strict Transport Security](https://tools.ietf.org/html/rfc6797)
- [OWASP Secure Headers Project](https://owasp.org/www-project-secure-headers/)

### Tools

- [CSP Evaluator (Google)](https://csp-evaluator.withgoogle.com/)
- [SecurityHeaders.com](https://securityheaders.com/)
- [Mozilla Observatory](https://observatory.mozilla.org/)

### Best Practices

- [MDN Web Docs: HTTP Headers](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers)
- [OWASP Cheat Sheet: Security Headers](https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Headers_Cheat_Sheet.html)

---

**Approved By:**
- Engineering: TBD
- Security: TBD

**Next Review Date:** 2026-10-12
