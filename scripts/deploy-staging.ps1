<#
Deploy to the staging Firebase project after running local preflight.

Usage:
  # Basic (uses .env for TEST_* and FIREBASE_SERVICE_ACCOUNT)
  .\scripts\deploy-staging.ps1

  # Skip preflight (not recommended)
  .\scripts\deploy-staging.ps1 -SkipPreflight

  # Provide a service account JSON file explicitly
  .\scripts\deploy-staging.ps1 -ServiceAccountPath C:\path\to\sa.json
#>
param(
  [switch]$SkipPreflight,
  [string]$ServiceAccountPath
)

$ErrorActionPreference = 'Stop'
Write-Host "`n=== Deploy: Staging (sierra-painting-staging) ===`n" -ForegroundColor Cyan

function Load-DotEnv {
  param(
    [string]$Path = '.env',
    [switch]$Force
  )
  if (-not (Test-Path $Path)) { return }
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
      Set-Item -Path ("Env:" + $key) -Value $val
    }
  }
}

# Ensure .env loaded and authoritative
Load-DotEnv -Path ".env" -Force

if (-not $SkipPreflight) {
  Write-Host "Running preflight checks (scripts/run_preflight_local.ps1)" -ForegroundColor Cyan
  $preflightCmd = @('powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',"scripts\run_preflight_local.ps1")
  $proc = Start-Process -FilePath powershell -ArgumentList ('-NoProfile','-ExecutionPolicy','Bypass','-File','scripts\run_preflight_local.ps1') -Wait -PassThru
  if ($proc.ExitCode -ne 0) {
    Write-Host "Preflight failed with exit code $($proc.ExitCode). Aborting deploy." -ForegroundColor Red
    exit $proc.ExitCode
  }
}

# Prepare service account file
if ($ServiceAccountPath) {
  if (-not (Test-Path $ServiceAccountPath)) { Write-Error "Service account file not found: $ServiceAccountPath"; exit 2 }
  $saPath = (Resolve-Path $ServiceAccountPath).Path
} elseif ($env:FIREBASE_SERVICE_ACCOUNT) {
  $saPath = Join-Path $env:TEMP 'firebase_sa.json'
  Set-Content -Path $saPath -Value $env:FIREBASE_SERVICE_ACCOUNT -Encoding utf8
} else {
  Write-Error "No service account provided. Set FIREBASE_SERVICE_ACCOUNT in .env or provide -ServiceAccountPath."; exit 3
}

$env:GOOGLE_APPLICATION_CREDENTIALS = $saPath
Write-Host "Using service account: $saPath" -ForegroundColor Green

# Install firebase tools check
try {
  npx firebase --version | Out-Null
} catch {
  Write-Host "Installing firebase-tools globally (temporary)..." -ForegroundColor Yellow
  npm i -g firebase-tools
}

Write-Host "Building project (npm run build if present)" -ForegroundColor Cyan
npm run build --if-present

Write-Host "Deploying to staging (sierra-painting-staging)..." -ForegroundColor Cyan
try {
  npx firebase deploy --project "sierra-painting-staging" --only hosting,functions --non-interactive
  $rc = $LASTEXITCODE
} catch {
  Write-Error "firebase deploy failed: $_"
  exit 5
}

if ($rc -eq 0) {
  Write-Host "Deploy succeeded to sierra-painting-staging." -ForegroundColor Green
  exit 0
} else {
  Write-Error "Deploy failed with exit code $rc"
  exit $rc
}
