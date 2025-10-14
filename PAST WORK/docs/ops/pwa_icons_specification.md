# PWA Icons Specification

**Purpose**: Generate and implement PWA icons for "Add to Home Screen" functionality
**Reference**: T-010 (P0-PLAT-002)
**Owner**: Frontend Team
**Last Updated**: 2025-10-13

---

## Overview

Progressive Web App (PWA) icons enable users to "Add to Home Screen" on mobile devices, providing an app-like experience. Currently, `web/manifest.json:11` has an empty `icons` array, blocking PWA installation.

**Issue**: P0-PLAT-002 - `"icons": []` (empty array)
**Impact**: Cannot "Add to Home Screen", fails PWA audit
**Priority**: T+0 Quick Win (1-2h effort)

---

## Required Icon Sizes

Per [PWA manifest spec](https://web.dev/add-manifest/), the following sizes are required:

### Minimum Required (MVP)
- **192x192** - Standard Android home screen icon
- **512x512** - Android splash screen, app drawer

### Recommended (Post-MVP)
- **72x72** - Low-res devices
- **96x96** - Medium-res devices
- **128x128** - High-res devices
- **144x144** - Extra-high-res devices
- **152x152** - iPad home screen
- **384x384** - Large format

### Optional (Future)
- **maskable icons** - Adaptive icons for Android 8+ (safe area design)
- **monochrome icons** - For theme-aware displays

---

## Icon Design Requirements

### Source Asset
1. **Format**: SVG (preferred) or PNG (min 1024x1024)
2. **Content**: Company logo with padding
3. **Background**: Use brand color (#0175C2 per manifest.json)
4. **Safe area**: Keep logo within 80% center area (for maskable icons)

### Design Specs
- **Padding**: 10% minimum around logo (prevents cropping)
- **Colors**: Use brand colors from manifest.json:
  - Primary: `#0175C2` (blue)
  - Background: `#0175C2`
  - Theme: `#0175C2`
- **Format**: PNG (lossy compression acceptable for icons)
- **Transparency**: Avoid transparent backgrounds (use brand color instead)

---

## Generation Methods

### Option 1: Online Tools (Fastest)
**Recommended for T+0 Quick Win**

1. **PWA Asset Generator** - https://www.pwabuilder.com/imageGenerator
   - Upload 512x512 PNG logo
   - Select "Generate icons"
   - Download zip with all sizes

2. **RealFaviconGenerator** - https://realfavicongenerator.net/
   - Upload high-res logo
   - Configure padding, background color
   - Generate all PWA icon sizes
   - Download package

3. **Favicon.io** - https://favicon.io/
   - Upload 512x512 PNG
   - Generate icons + manifest snippet
   - Download zip

**Pros**: Fast, no local tools required, generates all sizes
**Cons**: Requires internet, less customization

---

### Option 2: ImageMagick CLI (Automated)
**Recommended for CI/CD integration**

```bash
# Install ImageMagick (Windows)
choco install imagemagick

# Generate all sizes from source logo
magick source_logo.png -resize 192x192 web/icons/icon-192x192.png
magick source_logo.png -resize 512x512 web/icons/icon-512x512.png

# Optional: Generate all sizes in one command
for size in 72 96 128 144 152 192 384 512; do
  magick source_logo.png -resize ${size}x${size} web/icons/icon-${size}x${size}.png
done
```

**Pros**: Scriptable, repeatable, good for CI/CD
**Cons**: Requires ImageMagick installation

---

### Option 3: Flutter PWA Assets Package
**Recommended for Flutter-native approach**

```yaml
# pubspec.yaml (dev dependencies)
dev_dependencies:
  flutter_launcher_icons: ^0.13.1
```

```yaml
# flutter_launcher_icons-pwa.yaml
flutter_icons:
  image_path: "assets/images/logo.png"
  web:
    generate: true
    image_path: "assets/images/logo.png"
    background_color: "#0175C2"
    theme_color: "#0175C2"
```

```bash
# Generate icons
flutter pub run flutter_launcher_icons:main -f flutter_launcher_icons-pwa.yaml
```

**Pros**: Flutter-native, generates manifest JSON, easy to maintain
**Cons**: Requires package dependency

---

## Implementation Steps

### Step 1: Locate or Create Source Logo

**Check existing assets:**
```bash
# Search for logo files
dir /s /b assets\images\*.png | findstr /i "logo"
dir /s /b assets\images\*.svg | findstr /i "logo"
```

**If no logo exists:**
- Check with design team for brand assets
- Use placeholder logo for staging (can update later)
- Recommended placeholder: Blue square with "SP" text (Sierra Painting)

---

### Step 2: Generate Icon Files

**Using Option 1 (PWA Asset Generator):**
1. Go to https://www.pwabuilder.com/imageGenerator
2. Upload source logo (min 512x512)
3. Configure:
   - Padding: 10%
   - Background: #0175C2
   - Format: PNG
4. Click "Generate"
5. Download zip file

**Extract to project:**
```bash
# Create icons directory
mkdir web\icons

# Extract downloaded icons to web/icons/
# Expected files:
#   icon-192x192.png
#   icon-512x512.png
```

---

### Step 3: Update manifest.json

Replace empty `icons` array in `web/manifest.json`:

```json
{
  "name": "Sierra Painting",
  "short_name": "Sierra Painting",
  "start_url": ".",
  "display": "standalone",
  "background_color": "#0175C2",
  "theme_color": "#0175C2",
  "description": "Sierra Painting Business Management",
  "orientation": "portrait-primary",
  "prefer_related_applications": false,
  "icons": [
    {
      "src": "icons/icon-192x192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "any"
    },
    {
      "src": "icons/icon-512x512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "any"
    }
  ]
}
```

**Optional (maskable icons for Android 8+):**
```json
{
  "src": "icons/icon-192x192-maskable.png",
  "sizes": "192x192",
  "type": "image/png",
  "purpose": "maskable"
},
{
  "src": "icons/icon-512x512-maskable.png",
  "sizes": "512x512",
  "type": "image/png",
  "purpose": "maskable"
}
```

---

### Step 4: Test PWA Installation

#### Desktop Chrome (Testing)
1. Navigate to `http://localhost:8080` (or staging URL)
2. Open Chrome DevTools → Application tab
3. Click **Manifest** (left sidebar)
4. Verify:
   - ✅ Icons appear in preview
   - ✅ No manifest errors
   - ✅ "Add to Home Screen" button appears in URL bar

#### Android Chrome (Real Device)
1. Navigate to staging URL on Android device
2. Chrome menu → **"Add to Home Screen"**
3. Verify:
   - ✅ Install prompt appears
   - ✅ Branded icon shows in preview
   - ✅ App name displayed
4. After install:
   - ✅ Icon appears on home screen
   - ✅ Tapping icon opens app in standalone mode (no browser chrome)

#### Lighthouse Audit
```bash
# Run Lighthouse PWA audit
npm install -g lighthouse
lighthouse https://staging.example.com --view --only-categories=pwa
```

**Expected results:**
- ✅ PWA score ≥90
- ✅ "Installable" badge
- ✅ No icon warnings

---

## File Structure

After implementation:
```
sierra-painting-v1/
├── web/
│   ├── icons/
│   │   ├── icon-192x192.png          # Required
│   │   ├── icon-512x512.png          # Required
│   │   ├── icon-72x72.png            # Optional
│   │   ├── icon-96x96.png            # Optional
│   │   ├── icon-128x128.png          # Optional
│   │   ├── icon-144x144.png          # Optional
│   │   ├── icon-152x152.png          # Optional
│   │   └── icon-384x384.png          # Optional
│   ├── manifest.json                 # Updated with icon refs
│   └── index.html                    # Links to manifest
```

---

## Troubleshooting

### "Add to Home Screen" Not Appearing

**Checklist:**
- [ ] Is site served over HTTPS? (required for PWA)
- [ ] Is `manifest.json` linked in `index.html`? (`<link rel="manifest" href="manifest.json">`)
- [ ] Are icon files accessible? (check Network tab in DevTools)
- [ ] Is `start_url` correct in manifest?
- [ ] Is site visited multiple times? (Chrome requires engagement before showing prompt)

### Icons Not Loading

**Check:**
1. File paths relative to manifest location:
   - Manifest at: `web/manifest.json`
   - Icons at: `web/icons/icon-*.png`
   - Path in manifest: `"icons/icon-*.png"` (no leading slash)

2. MIME types correct:
   ```bash
   # Verify PNG files
   file web/icons/icon-192x192.png
   # Expected: PNG image data, 192 x 192
   ```

3. File sizes reasonable:
   - 192x192: <50 KB
   - 512x512: <200 KB
   - If larger, compress with https://tinypng.com/

### PWA Audit Failing

**Common issues:**
- Missing `theme_color` in manifest (already present: #0175C2)
- Missing `background_color` (already present: #0175C2)
- Missing `name` or `short_name` (already present)
- Icons not square (must be exact dimensions, e.g., 192x192)
- Icons missing `purpose` field (default: "any")

---

## Acceptance Criteria (T-010)

- [x] **Spec created**: This document
- [ ] Icon files generated (192x192, 512x512 minimum)
- [ ] Icons placed in `web/icons/` directory
- [ ] `manifest.json` updated with icon references
- [ ] PWA installs successfully on Chrome Android
- [ ] Branded icon shows on home screen
- [ ] Lighthouse PWA audit passes (score ≥90)

**Status**: 📋 Spec complete (awaiting icon asset from design team)

---

## Related Tasks

- **T-012**: Fix web bundle size (ensure icon files <200 KB total)
- **T-042**: Add Lighthouse CI budgets (includes PWA audit)

---

## Action Items

**Immediate** (within 24h):
1. [ ] Request logo asset from design team (min 512x512 PNG or SVG)
2. [ ] Generate icon files using PWA Asset Generator
3. [ ] Place icons in `web/icons/` directory
4. [ ] Update `manifest.json` with icon references
5. [ ] Test PWA installation on Android device

**Follow-up** (within 1 week):
1. [ ] Add maskable icons for Android 8+
2. [ ] Generate additional sizes (72, 96, 128, 144, 152, 384)
3. [ ] Add icon generation to CI/CD (using ImageMagick or flutter_launcher_icons)
4. [ ] Document icon update process in CONTRIBUTING.md

---

## Placeholder Logo (If No Asset Available)

**Temporary solution for unblocking PWA setup:**

Create simple placeholder using HTML Canvas or online tools:
- 512x512 PNG
- Blue background (#0175C2)
- White "SP" text (Sierra Painting initials)
- Center-aligned, large sans-serif font

**Online generator**: https://favicon.io/favicon-generator/
- Text: SP
- Background: Round, #0175C2
- Font: Roboto Bold
- Font size: 100
- Download and rename to icon-512x512.png

**NOTE**: Replace placeholder with real logo before production launch!

---

## References

- [PWA Manifest Spec (MDN)](https://developer.mozilla.org/en-US/docs/Web/Manifest)
- [Maskable Icons Guide](https://web.dev/maskable-icon/)
- [PWA Asset Generator Tool](https://www.pwabuilder.com/imageGenerator)
- [Lighthouse PWA Audit](https://web.dev/pwa-checklist/)

---

**Last Updated**: 2025-10-13
**Next Review**: After icon generation (T-010 completion)
