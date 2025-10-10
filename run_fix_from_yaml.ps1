Set-StrictMode -Version Latest
Write-Host "Running YAML-derived fix: patch index.html, patch firebase.json, rebuild web, start hosting emulator"

try {
    $root = (Get-Location).Path
    Push-Location $root

    # Step 1: Patch web/index.html
    $p = Join-Path $root 'web\index.html'
    if (!(Test-Path $p)) { throw "Missing $p (Flutter web entry). Run from repo root." }
    $html = Get-Content $p -Raw

    # Remove surrounding markdown code fences if accidentally present
    $html = $html -replace '^(\s*```(?:html)?\r?\n)', ''
    $html = $html -replace '(\r?\n\s*```\s*)$', ''

    # CSP that allows Flutter inline boot + wasm-unsafe-eval (dev-friendly).
    $newMeta = '<meta http-equiv="Content-Security-Policy" content="default-src ''''self'''' data: blob: https:; script-src ''''self'''' ''''unsafe-inline'''' ''''wasm-unsafe-eval''''; style-src ''''self'''' ''''unsafe-inline''''; img-src ''''self'''' data: https:; font-src ''''self'''' data: https:; connect-src ''''self'''' https://*.googleapis.com https://*.firebaseio.com https://*.google-analytics.com ws://localhost:* http://localhost:*; worker-src ''''self'''' blob:; base-uri ''''self''''; object-src ''''none''''; frame-ancestors ''''self'''';">'

    if ($html -match '<meta\s+http-equiv="Content-Security-Policy"[^>]*>') {
        $html = [regex]::Replace($html, '<meta\s+http-equiv="Content-Security-Policy"[^>]*>', $newMeta, 'IgnoreCase')
    }
    else {
        $html = [regex]::Replace($html, '(?i)</head>', "  $newMeta`n</head>")
    }

    # Ensure <html> has a lang attribute
    if ($html -notmatch '<html[^>]*\blang=') {
        $html = [regex]::Replace($html, '<html(\s|>)', '<html lang="en"$1', 'IgnoreCase')
    }

    Set-Content -Path $p -Value $html -Encoding UTF8
    Write-Host "web/index.html patched."

    # Step 2: Patch firebase.json via Node (write a temporary JS file and run it)
    $patchJs = @'
const fs = require('fs');
const path = 'firebase.json';
if (!fs.existsSync(path)) throw new Error('firebase.json not found');
const j = JSON.parse(fs.readFileSync(path, 'utf8'));

// Ensure hosting block exists
j.hosting ??= {};
j.hosting.public ??= 'build/web';

// SPA rewrite so deep links render your Flutter app
j.hosting.rewrites ??= [];
if (!j.hosting.rewrites.find(r => r.source === '**')) {
  j.hosting.rewrites.push({ source: '**', destination: '/index.html' });
}

// Inject CSP header (mirrors the <meta>, covers prod & emulator)
const cspVal = "default-src 'self' data: blob: https:; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data: https:; connect-src 'self' https://*.googleapis.com https://*.firebaseio.com https://*.google-analytics.com ws://localhost:* http://localhost:*; worker-src 'self' blob:; base-uri 'self'; object-src 'none'; frame-ancestors 'self';";
j.hosting.headers ??= [];
// remove any existing CSP rule we previously set
j.hosting.headers = j.hosting.headers.filter(h =>
  !(h.headers?.some(x => x.key?.toLowerCase() === 'content-security-policy'))
);
j.hosting.headers.push({ source: '**', headers: [{ key: 'Content-Security-Policy', value: cspVal }] });

// Fix emulator ports (Hub must not equal UI)
j.emulators ??= {};
j.emulators.hub ??= {};
j.emulators.hub.port = 4400;
j.emulators.ui ??= {};
j.emulators.ui.enabled = true;
j.emulators.ui.port = 4500;

fs.writeFileSync(path, JSON.stringify(j, null, 2));
console.log('firebase.json patched.');
'@

    $tmpJs = Join-Path $root '._patch_firebase.js'
    $patchJs | Set-Content -Path $tmpJs -Encoding UTF8
    Write-Host "Running Node patch script to update firebase.json..."
    & node $tmpJs
    Remove-Item $tmpJs -Force

    # Step 3: Flutter rebuild
    Write-Host "Running flutter clean && flutter pub get && flutter build web --no-tree-shake-icons"
    & flutter clean
    & flutter pub get
    & flutter build web --no-tree-shake-icons

    # Step 4: Start the hosting emulator (blocking)
    Write-Host "Starting Firebase Hosting emulator -- only hosting (this will block until you Ctrl+C)..."
    & firebase emulators:start --only hosting

    Pop-Location
}
catch {
    Write-Error "Error: $_"
    Pop-Location -ErrorAction SilentlyContinue
    exit 1
}
