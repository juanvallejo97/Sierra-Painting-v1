param(
  [Parameter(Mandatory=$false)][string]$Email,
  [Parameter(Mandatory=$false)][string]$Pass,
  [Parameter(Mandatory=$false)][string]$Site,
  [switch]$HeadlessNew,
  [switch]$KeepServer
)

# Helper: load .env file into process env vars (does not overwrite existing vars)
function Load-DotEnv {
  param(
    [string]$Path = '.env',
    [switch]$Force
  )
  if (-not (Test-Path $Path)) { return }
  Write-Host "Loading environment variables from $Path" -ForegroundColor Cyan
  Get-Content $Path | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq '') { return }
    if ($line.StartsWith('#')) { return }
    if ($line -notmatch '=') { return }
    $parts = $line -split('=',2)
    $key = $parts[0].Trim()
    $val = $parts[1].Trim()
    if ($val.StartsWith('"') -and $val.EndsWith('"')) { $val = $val.Substring(1,$val.Length-2) }
    if ($val.StartsWith("'") -and $val.EndsWith("'")) { $val = $val.Substring(1,$val.Length-2) }
    if ($Force -or -not (Test-Path ("Env:" + $key))) {
      Write-Host "  setting $key" -ForegroundColor DarkCyan
      Set-Item -Path ("Env:" + $key) -Value $val
    }
  }
}

# Load .env into env vars before filling defaults (force overwrite)
Load-DotEnv -Path ".env" -Force

# set default param values from env if not supplied
if (-not $Email) { $Email = $env:TEST_EMAIL }
if (-not $Pass)  { $Pass  = $env:TEST_PASS }
if (-not $Site)  { $Site  = $env:RECAPTCHA_SITE_KEY }

$ErrorActionPreference = "Stop"
Write-Host "`n=== Sierra Painting - Local CI Harness ===`n" -ForegroundColor Cyan
Write-Host ("Email: {0}" -f (if ($Email -ne $null -and $Email -ne "") { $Email } else { "<missing>" }))
Write-Host ("Site key: {0}" -f (if ($Site -ne $null -and $Site -ne "") { $Site } else { "<missing>" }))

# 1) Ensure deps
if (!(Test-Path package-lock.json) -and !(Test-Path pnpm-lock.yaml) -and !(Test-Path yarn.lock)) {
  Write-Host "No lockfile found; running 'npm i'..." -ForegroundColor Yellow
  npm i
} else {
  Write-Host "Lockfile found; running 'npm ci'..." -ForegroundColor Green
  try { npm ci } catch { npm i }
}

# 2) Generate Firebase config json (writes scripts/firebase_config.json)
node scripts/generate_firebase_config.js

# 3) Run validator via the cross-platform wrapper
$argsList = @(
  "--port=3000",
  ("--email={0}" -f $Email),
  ("--pass={0}"  -f $Pass),
  ("--recaptcha={0}" -f $Site),
  "--debug=true"
)
if ($HeadlessNew) { $argsList += "--headless=new" }
if ($KeepServer)  { $argsList += "--keep-server"  }

Write-Host "`n--- Running validator (validate_runner.js) ---" -ForegroundColor Cyan
node scripts/validate_runner.js $argsList

# 4) Produce HTML report (embeds screenshot)
Write-Host "`n--- Generating summary (reports/firebase_validation_summary.html) ---" -ForegroundColor Cyan
node scripts/generate_summary.js

# 5) Verify artifacts and print standardized output for CI-local harness
Write-Host "`nArtifacts present:`n" -ForegroundColor Cyan

$artifacts = @(
  "logs/token_validation_log.txt",
  "reports/firebase_validation_capture.png",
  "reports/firebase_validation_summary.html"
)

$missing = @()
foreach ($a in $artifacts) {
  if (-not (Test-Path $a)) { $missing += $a }
}

if ($missing.Count -gt 0) {
  Write-Host "Missing artifacts:" -ForegroundColor Red
  foreach ($m in $missing) { Write-Host "  $m" -ForegroundColor Red }
  Write-Error "Required artifacts not produced. Exiting with failure."
  exit 1
}

foreach ($a in $artifacts) { Write-Host "  $a" }

# 6) Quick content checks against the generated summary
$summaryPath = "reports/firebase_validation_summary.html"
if (Test-Path $summaryPath) {
  try {
    $content = Get-Content $summaryPath -Raw -ErrorAction Stop
  } catch {
    Write-Error "Failed to read summary file: $summaryPath"
    exit 1
  }

  $hasSignedIn = $content -match "Signed in as"
  $hasAppCheck = $content -match "App Check: reCAPTCHA v3 enabled\."

  if ($hasSignedIn -and $hasAppCheck) {
    Write-Host "Summary shows 'Signed in as' and 'App Check: reCAPTCHA v3 enabled.'" -ForegroundColor Green
  } else {
    Write-Host "Summary did not contain the expected text." -ForegroundColor Yellow
    if (-not $hasSignedIn) { Write-Host "  - Missing: 'Signed in as'" -ForegroundColor Yellow }
    if (-not $hasAppCheck)  { Write-Host "  - Missing: 'App Check: reCAPTCHA v3 enabled.'" -ForegroundColor Yellow }
    exit 1
  }
} else {
  Write-Error "Summary file not found: $summaryPath"
  exit 1
}
