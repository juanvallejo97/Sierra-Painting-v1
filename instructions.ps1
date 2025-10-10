# Auto-generated from instructions.yaml
Set-StrictMode -Version Latest
Write-Host "Running fix_flutter_web_boot_and_csp script"

try {
    $root = (Get-Location).Path

    # Determine index.html to modify: prefer web/index.html, fallback to build/web/index.html
    $pWeb = Join-Path $root "web\index.html"
    $pBuild = Join-Path $root "build\web\index.html"
    $p = if (Test-Path $pWeb) { $pWeb } elseif (Test-Path $pBuild) { $pBuild } else { $null }
    if (-not $p) { throw "index.html not found in web/ or build/web/. Build or create first." }

    Copy-Item -Path $p -Destination "$p.bak" -Force

    $indexHtml = @'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <base href="/" />
    <meta name="flutter-service-worker-version" content="">
    <link rel="manifest" href="manifest.json" />
    <title>Sierra Painting</title>
  </head>
  <body>
    <!-- Load flutter.js FIRST, then bootstrap. Use defer to preserve order. -->
    <script src="flutter.js" defer></script>
    <script src="flutter_bootstrap.js" defer></script>
  </body>
</html>
'@

    Write-Host "Writing cleaned index to: $p"
    $indexHtml | Out-File -FilePath $p -Encoding utf8 -Force

    # Update firebase.json
    $fbPath = Join-Path $root 'firebase.json'
    if (-not (Test-Path $fbPath)) { throw "firebase.json not found at repo root." }

    $jsonRaw = Get-Content $fbPath -Raw
    $json = $jsonRaw | ConvertFrom-Json

    if ($null -eq $json.hosting) { $json | Add-Member -Name hosting -MemberType NoteProperty -Value (@{}) }
    $json.hosting.public = "build/web"
    $json.hosting.ignore = @("firebase.json", "**/.*", "**/node_modules/**")

    $csp = "default-src 'self' data: blob: https:; " +
    "script-src 'self' 'wasm-unsafe-eval'; " +
    "style-src 'self' 'unsafe-inline'; " +
    "img-src 'self' data: blob: https:; " +
    "font-src 'self' data: https:; " +
    "connect-src 'self' https://*.googleapis.com https://*.gstatic.com https://*.firebaseio.com https://firestore.googleapis.com https://firebasestorage.googleapis.com http://127.0.0.1:* http://localhost:* ws://127.0.0.1:* ws://localhost:*; " +
    "worker-src 'self' blob:; frame-src 'self' https://*.google.com https://*.firebaseapp.com;"

    $headers = @()
    $headers += @{ source = "/index.html"; headers = @(@{ key = "Content-Security-Policy"; value = $csp }) }
    $headers += @{ source = "**/*.js"; headers = @(@{ key = "X-Content-Type-Options"; value = "nosniff" }) }

    $json.hosting.headers = $headers

    if ($null -eq $json.emulators) { $json | Add-Member -Name emulators -MemberType NoteProperty -Value (@{}) }
    if ($null -eq $json.emulators.ui) { $json.emulators | Add-Member -Name ui -MemberType NoteProperty -Value (@{}) }
    $json.emulators.ui.enabled = $true
    $json.emulators.ui.port = 4500

    $json | ConvertTo-Json -Depth 20 | Out-File -FilePath $fbPath -Encoding utf8 -Force
    Write-Host "firebase.json updated."

    # Build Flutter web
    Write-Host "Running flutter clean && flutter build web --release"
    & flutter clean
    & flutter build web --release

    # Start hosting emulator in a detached process so the script exits and we can continue debugging
    Write-Host "Starting Firebase Hosting emulator in background (hosting only)"
    $proc = Start-Process -FilePath "firebase" -ArgumentList "emulators:start --only hosting" -NoNewWindow -PassThru
    Write-Host "Emulator process started (Id: $($proc.Id)). Give it a few seconds to become ready."

    Write-Host "Done."
}
catch {
    Write-Error "Error: $_"
    exit 1
}
# PowerShell script to patch firebase.json (CSP + emulator ports), clean CSP <meta>, and rebuild web

# Patch firebase.json (CSP + emulator ports)
$path = "firebase.json"
if (!(Test-Path $path)) { throw "firebase.json not found at $PWD" }

$json = Get-Content $path -Raw | ConvertFrom-Json

# Ensure hosting.headers exists
if (-not $json.hosting) { $json | Add-Member -NotePropertyName hosting   -NotePropertyValue (@{}) }
if (-not $json.hosting.headers) { $json.hosting | Add-Member -NotePropertyName headers -NotePropertyValue @() }

# Dev CSP (permits inline/eval so Flutter web + bootstrap can run)
$cspValue = @"
default-src 'self' data: blob: https:;
script-src 'self' 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval'
  https://www.gstatic.com/firebasejs/ https://www.googletagmanager.com
  https://www.google-analytics.com https://js.stripe.com;
connect-src 'self' https://*.googleapis.com https://*.firebaseio.com
  https://*.gstatic.com https://*.google-analytics.com
  http://127.0.0.1:* http://localhost:* ws: wss: https:;
img-src 'self' data: blob: https:;
style-src 'self' 'unsafe-inline' https:;
font-src 'self' data: https:;
frame-src 'self' https://js.stripe.com https://*.google.com https://*.firebaseapp.com;
worker-src 'self' blob:;
object-src 'none';
base-uri 'self';
frame-ancestors 'self';
manifest-src 'self'
"@.Trim()

# Remove any existing CSP header to avoid duplicates
$updated = @()
foreach ($entry in ($json.hosting.headers | ForEach-Object { $_ })) {
    if ($entry.source -in @("/", "**")) {
        $entry.headers = @($entry.headers | Where-Object { $_.key -ne "Content-Security-Policy" })
    }
    $updated += $entry
}

# Attach CSP to a catch-all source
$target = $updated | Where-Object { $_.source -eq "**" } | Select-Object -First 1
if (-not $target) {
    $target = [pscustomobject]@{
        source  = "**"
        headers = @()
    }
    $updated = , $target + $updated
}
$target.headers += [pscustomobject]@{ key = "Content-Security-Policy"; value = $cspValue }

$json.hosting.headers = $updated

# Clean emulator ports
if (-not $json.emulators) { $json | Add-Member -NotePropertyName emulators -NotePropertyValue (@{}) }
if (-not $json.emulators.ui) { $json.emulators | Add-Member -NotePropertyName ui -NotePropertyValue (@{}) }
$json.emulators.ui.enabled = $true
$json.emulators.ui.port = 4500     # avoid colliding with hub (4400)
if (-not $json.emulators.hub) { $json.emulators | Add-Member -NotePropertyName hub -NotePropertyValue (@{}) }
$json.emulators.hub.port = 4400
if (-not $json.emulators.hosting) { $json.emulators | Add-Member -NotePropertyName hosting -NotePropertyValue (@{}) }
$json.emulators.hosting.host = "127.0.0.1"
$json.emulators.hosting.port = 5000

$json | ConvertTo-Json -Depth 100 | Set-Content $path -NoNewline
Write-Host "firebase.json updated."

# Remove any CSP <meta> (optional but recommended)
$html = "web/index.html"
if (Test-Path $html) {
    (Get-Content $html -Raw) -replace '(?is)<meta\s+http-equiv\s*=\s*"Content-Security-Policy".*?>', '' |
    Set-Content $html -NoNewline
    Write-Host "Removed CSP <meta> from web/index.html"
}
else {
    Write-Host "web/index.html not found; skipping HTML CSP cleanup."
}

# Rebuild web & show how to test
flutter build web
Write-Host "`nNext: test locally with:"
Write-Host "  firebase emulators:start --only hosting"
Write-Host "Emulator UI: http://127.0.0.1:4500  •  Site: http://127.0.0.1:5000"
