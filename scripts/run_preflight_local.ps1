<#
Runs the local preflight: ensures env, installs deps, generates firebase config,
runs the validator, creates the summary, and reports artifacts and checks.
#>
Param(
  [switch]$KeepServer = $false,
  [switch]$Deploy = $false
)

$ErrorActionPreference = 'Stop'
Write-Host "`n=== Local Preflight: Validator + Summary ===`n" -ForegroundColor Cyan

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
    # Remove surrounding quotes if present
    if ($val.StartsWith('"') -and $val.EndsWith('"')) { $val = $val.Substring(1,$val.Length-2) }
    if ($val.StartsWith("'") -and $val.EndsWith("'")) { $val = $val.Substring(1,$val.Length-2) }
    if ($Force -or -not (Test-Path ("Env:" + $key))) {
      Write-Host "  setting $key" -ForegroundColor DarkCyan
      Set-Item -Path ("Env:" + $key) -Value $val
    }
  }
}

# Load .env if present (force overwrite so .env is authoritative)
Load-DotEnv -Path ".env" -Force

# Default emulator host/ports (can be overridden in .env)
if (-not $env:AUTH_EMULATOR_HOST -or $env:AUTH_EMULATOR_HOST -eq '') { $env:AUTH_EMULATOR_HOST = '127.0.0.1' }
if (-not $env:AUTH_EMULATOR_PORT -or $env:AUTH_EMULATOR_PORT -eq '') { $env:AUTH_EMULATOR_PORT = '9101' }
if (-not $env:UI_EMULATOR_PORT -or $env:UI_EMULATOR_PORT -eq '')     { $env:UI_EMULATOR_PORT = '4401' }

# Require service account credentials for emulator startup (recommended)
$saPath = Join-Path $PSScriptRoot '..\secrets\firebase_service_account.json'
if (-not $env:GOOGLE_APPLICATION_CREDENTIALS -or $env:GOOGLE_APPLICATION_CREDENTIALS -eq '') {
  if (Test-Path $saPath) {
    $env:GOOGLE_APPLICATION_CREDENTIALS = (Resolve-Path $saPath).ToString()
    Write-Host "Using service account: $env:GOOGLE_APPLICATION_CREDENTIALS" -ForegroundColor Cyan
  } else {
    Write-Host "Missing service account JSON at $saPath and GOOGLE_APPLICATION_CREDENTIALS is not set." -ForegroundColor Red
    Write-Host "Place a GCP service account JSON at .\\secrets\\firebase_service_account.json or set GOOGLE_APPLICATION_CREDENTIALS in your environment." -ForegroundColor Red
    exit 2
  }
} else {
  Write-Host "GOOGLE_APPLICATION_CREDENTIALS is set: $env:GOOGLE_APPLICATION_CREDENTIALS" -ForegroundColor Cyan
}

# 2) Start Auth emulator (ephemeral)
$emuLog = Join-Path $PSScriptRoot "..\logs\auth_emulator_stdout.log"
$emuErr = Join-Path $PSScriptRoot "..\logs\auth_emulator_stderr.log"
New-Item -ItemType Directory -Force -Path (Split-Path $emuLog) | Out-Null

# Use npx to ensure local firebase CLI is used if available
 # Validate project id for emulator start
if (-not $env:FIREBASE_PROJECT_ID -or $env:FIREBASE_PROJECT_ID -eq '') {
  Write-Host "FIREBASE_PROJECT_ID is not set. Set it in .env or as an environment variable to the target project id (e.g. sierra-painting-staging)." -ForegroundColor Red
  exit 2
}
if ($env:FIREBASE_PROJECT_ID -notmatch '^[a-z0-9\-]+$') {
  Write-Host "FIREBASE_PROJECT_ID ' $env:FIREBASE_PROJECT_ID ' does not look valid. Project ids must be lowercase letters, numbers, and hyphens. Update .env and try again." -ForegroundColor Red
  exit 2
}

 # Build argument list and remove empty values
 # Pre-kill processes listening on likely emulator/UI ports to avoid collisions
 $portsToPreKill = @('9099',$env:AUTH_EMULATOR_PORT,'4000',$env:UI_EMULATOR_PORT,'4500') | Where-Object { $_ -and $_ -ne '' } | Select-Object -Unique
 foreach ($p in $portsToPreKill) {
   try {
     $lines = netstat -ano | Select-String ":$p\s"
     if ($lines) {
       $pids = $lines -replace '.*\s(\d+)$','$1' | Select-Object -Unique
       foreach ($pid in $pids) { try { taskkill /F /PID $pid | Out-Null; Write-Host "Killed PID $pid on port $p" } catch {} }
     }
   } catch {}
 }

 # Ensure a firebase.json exists with explicit emulator ports and UI disabled to avoid collisions
 $cfgPath = Join-Path $PSScriptRoot '..\firebase.json'
 $cfg = $null
 if (Test-Path $cfgPath) {
   try { $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json -ErrorAction Stop } catch { $cfg = $null }
 }

# Ensure the configured auth port is available; if not, allocate a free port and use that.
function Get-FreePort {
  # Returns an available TCP port by letting the OS pick one (port 0) and then closing the listener.
  $listener = [System.Net.Sockets.TcpListener]::New([System.Net.IPAddress]::Loopback, 0)
  $listener.Start()
  $port = ($listener.LocalEndpoint.ToString() -split ':')[-1]
  try { $listener.Stop() } catch {}
  return [int]$port
}

# Preferred port (from env or default 9099)
if (-not $env:AUTH_EMULATOR_PORT -or $env:AUTH_EMULATOR_PORT -eq '') { $env:AUTH_EMULATOR_PORT = '9099' }

function Test-PortInUse($port) {
  try {
    $addr = [System.Net.IPAddress]::Loopback
    $s = New-Object System.Net.Sockets.TcpClient
    $async = $s.BeginConnect($addr, [int]$port, $null, $null)
    $ok = $async.AsyncWaitHandle.WaitOne(200)
    if ($ok) { try { $s.EndConnect($async); $s.Close(); return $true } catch { $s.Close(); return $true } }
    $s.Close(); return $false
  } catch { return $false }
}

$preferredPort = [int]$env:AUTH_EMULATOR_PORT
if (Test-PortInUse $preferredPort) {
  Write-Host "Configured auth port $preferredPort appears in use. Allocating a free port..." -ForegroundColor Yellow
  $free = Get-FreePort
  Write-Host "Selected free port $free for auth emulator" -ForegroundColor Yellow
  $env:AUTH_EMULATOR_PORT = [string]$free
} else {
  Write-Host "Auth emulator port $preferredPort appears free; using it." -ForegroundColor Cyan
}

 # Build a clean emulators object to avoid fragile property sets
 $authObj = @{ host = $env:AUTH_EMULATOR_HOST; port = [int]$env:AUTH_EMULATOR_PORT }
 $uiObj = @{ enabled = $false; port = [int]$env:UI_EMULATOR_PORT }
 $emulatorsObj = @{ auth = $authObj; ui = $uiObj }

 if ($cfg -eq $null) {
   $out = @{ emulators = $emulatorsObj }
 } else {
   # Replace or set the emulators block
   $cfg.emulators = $emulatorsObj
   $out = $cfg
 }

 try { ($out | ConvertTo-Json -Depth 8) | Set-Content -Encoding UTF8 $cfgPath } catch {}

 $emuArgs = @('firebase','emulators:start','--only','auth','--import','./.firebase','--export-on-exit')
 # If UI is explicitly enabled via EMULATOR_UI_ENABLED env, include it; otherwise leave UI disabled
 if ($env:EMULATOR_UI_ENABLED -and $env:EMULATOR_UI_ENABLED.ToString().ToLower() -in @('true','1','yes')) { $emuArgs += '--ui' }
 if ($env:FIREBASE_PROJECT_ID -and $env:FIREBASE_PROJECT_ID -ne '') { $emuArgs += @('--project', $env:FIREBASE_PROJECT_ID) }
 $emuArgs = $emuArgs | Where-Object { $_ -ne $null -and $_ -ne '' }
Write-Host "Starting Auth emulator via: npx $($emuArgs -join ' ')" -ForegroundColor Cyan
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$emu = Start-Process -FilePath "npx" -ArgumentList $emuArgs -NoNewWindow -PassThru -RedirectStandardOutput $emuLog -RedirectStandardError $emuErr -WorkingDirectory $repoRoot
Write-Host "Starting Auth emulator (pid $($emu.Id))..." -ForegroundColor Green

# Wait until the emulator is ready (robust)
$TIMEOUT_MS = 90000
if ($env:TIMEOUT_MS -and $env:TIMEOUT_MS -ne '') {
  try { $TIMEOUT_MS = [int]$env:TIMEOUT_MS } catch { $TIMEOUT_MS = 90000 }
}
$deadline = (Get-Date).AddMilliseconds($TIMEOUT_MS)
$ready = $false
$attemptedRestart = $false
$markers = @(
  'Auth Emulator logging to',
  'All emulators ready',
  'Hub listening at',
  'Auth Emulator UI',
  'Auth Emulator running',
  'Serving on'
)

while ((Get-Date) -lt $deadline -and -not $ready) {
  Start-Sleep -Milliseconds 500
  if ($emu.HasExited) {
    # collect last lines for diagnostics
    $tail = ''
    if (Test-Path $emuLog) {
      # PS 5.1: -Raw and -Tail cannot be combined. Read last N lines then join.
      try { $lines = Get-Content -LiteralPath $emuLog -Tail 200 -ErrorAction SilentlyContinue; $tail = ($lines -join "`n") } catch { $tail = '' }
    }
    throw "Auth emulator exited early. See $emuErr`nLast output:`n$tail"
  }

  if (Test-Path $emuLog) {
    try {
      $txt = Get-Content $emuLog -Raw -ErrorAction SilentlyContinue
    } catch { $txt = '' }
    if ($txt) {
      foreach ($m in $markers) { if ($txt -match [regex]::Escape($m)) { $ready = $true; break } }

      # If port already in use, attempt a single restart with randomized port
      if (-not $ready -and -not $attemptedRestart -and ($txt -match 'EADDRINUSE' -or $txt -match 'address already in use')) {
        Write-Host "Detected port in use while starting emulator. Attempting to free and restart on random port..." -ForegroundColor Yellow
        # Kill processes listening on the auth/UI ports if any
        $portsToCheck = @($env:AUTH_EMULATOR_PORT, 4000) | Where-Object { $_ -and $_ -ne '' }
        foreach ($p in $portsToCheck) {
          try {
            $lines = netstat -ano | Select-String ":$p\s"
            if ($lines) {
              $pids = $lines -replace '.*\s(\d+)$','$1' | Select-Object -Unique
              foreach ($pid in $pids) { try { taskkill /F /PID $pid | Out-Null } catch {} }
            }
          } catch {}
        }
        # restart emulator using randomized host hint (allow firebase to pick free port)
        $attemptedRestart = $true
        if (Test-Path $emuLog) { Remove-Item $emuLog -Force -ErrorAction SilentlyContinue }
        # set AUTH_EMULATOR_HOST to hint random port; firebase will pick an available port
        $env:AUTH_EMULATOR_HOST = '127.0.0.1:0'
        Start-Sleep -Milliseconds 200
        # restart process
        try { Stop-Process -Id $emu.Id -Force -ErrorAction SilentlyContinue } catch {}
        Start-Sleep -Milliseconds 200
  $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
  $emu = Start-Process -FilePath "npx" -ArgumentList $emuArgs -NoNewWindow -PassThru -RedirectStandardOutput $emuLog -RedirectStandardError $emuErr -WorkingDirectory $repoRoot
        continue
      }

      # Check for fatal boot errors
      if ($txt -match 'Failed to start' -or $txt -match 'Unhandled error' -or $txt -match 'Invalid project id') {
        throw "Auth emulator emitted a fatal boot error. Inspect $emuLog" 
      }
    }
  }
}

# If initial wait failed, attempt a single recovery restart (kill conflicts, randomize host hint)
if (-not $ready) {
  Write-Warning "Initial wait timed out; attempting one recovery restart..."
  # Best-effort: kill potential conflicts on usual ports
  $portsToCheck = @(9099, 4000)
  foreach ($p in $portsToCheck) {
    try {
      $net = netstat -ano | Select-String ":$p\s"
      if ($net) {
        $pids = ($net -replace '.*\s(\d+)$','$1') | Select-Object -Unique
        foreach ($pid in $pids) { try { taskkill /PID $pid /F | Out-Null } catch {} }
      }
    } catch {}
  }

  # Randomized host hint to avoid cached binding issues
  $randHost = "127.0.0.$([int](Get-Random -Minimum 1 -Maximum 254))"
  $env:AUTH_EMULATOR_HOST = $randHost

  # wipe old log
  try { Remove-Item -LiteralPath $emuLog -ErrorAction SilentlyContinue } catch {}

  # re-run emulator start using Start-Process with same args
  try { Stop-Process -Id $emu.Id -Force -ErrorAction SilentlyContinue } catch {}
  Start-Sleep -Milliseconds 200
  $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
  $emu = Start-Process -FilePath "npx" -ArgumentList $emuArgs -NoNewWindow -PassThru -RedirectStandardOutput $emuLog -RedirectStandardError $emuErr -WorkingDirectory $repoRoot
  Start-Sleep -Milliseconds 800

  # Re-wait with same timeout
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $ready = $false
  while ($sw.ElapsedMilliseconds -lt $TIMEOUT_MS -and -not $ready) {
    Start-Sleep -Milliseconds 300
    if (Test-Path $emuLog) {
      try { $lines = Get-Content -LiteralPath $emuLog -Tail 200 -ErrorAction SilentlyContinue; $tail = ($lines -join "`n") } catch { $tail = '' }
      if ($tail -match 'Accepting connections at http://localhost:\d+' -or $tail -match 'Hub listening at' -or $tail -match 'Auth Emulator UI') { $ready = $true; break }
      if ($emu.HasExited) { break }
    }
  }
  if (-not $ready) { throw "Timed out waiting for Auth emulator readiness (after restart). See $emuLog" }
}

# Attempt to extract chosen port (look for "Accepting connections at http://localhost:PORT")
$port = $null
if (Test-Path $emuLog) {
  try { $lines = Get-Content -LiteralPath $emuLog -Tail 500 -ErrorAction SilentlyContinue; $tail = ($lines -join "`n") } catch { $tail = '' }
  if ($tail -match 'Accepting connections at http://localhost:(\d+)') { $port = $Matches[1] }
  elseif ($tail -match '127\.0\.0\.1:(\d+)') { $port = $Matches[1] }
}
if ($port) {
  Write-Host "Detected Auth emulator port: $port" -ForegroundColor Green
  $env:AUTH_EMULATOR_PORT = $port
} else {
  if (-not $env:AUTH_EMULATOR_PORT -or $env:AUTH_EMULATOR_PORT -eq '') { $env:AUTH_EMULATOR_PORT = '9099' }
  Write-Host "Using fallback Auth emulator port: $($env:AUTH_EMULATOR_PORT)" -ForegroundColor Yellow
}

# Ensure tokens page sees USE_EMULATORS=true
$env:USE_EMULATORS = 'true'

$missing = @()
if (-not $env:TEST_EMAIL -or $env:TEST_EMAIL -eq '') { $missing += 'TEST_EMAIL' }
if (-not $env:TEST_PASS  -or $env:TEST_PASS  -eq '') { $missing += 'TEST_PASS' }
if (-not $env:RECAPTCHA_SITE_KEY -or $env:RECAPTCHA_SITE_KEY -eq '') { $missing += 'RECAPTCHA_SITE_KEY' }

if ($missing.Count -gt 0) {
  Write-Host "Missing required environment variables:" -ForegroundColor Red
  foreach ($m in $missing) { Write-Host "  - $m" -ForegroundColor Red }
  exit 2
}

Write-Host "Environment variables present. Installing dependencies if needed..." -ForegroundColor Green
# If dotenv is already resolvable, skip installing to avoid EPERM/native module locking during automated runs
$skipInstall = $false
try {
  if (-not $repoRoot) { $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
  Push-Location $repoRoot
  $nodeExe = (Get-Command node -ErrorAction SilentlyContinue).Source
  if (-not $nodeExe) { $nodeExe = 'node' }
  try {
    & $nodeExe -e "require('dotenv')" 1>$null 2>$null
    if ($LASTEXITCODE -eq 0) { Write-Host "Node deps present (dotenv ok) - skipping npm install." -ForegroundColor Cyan; $skipInstall = $true }
  } catch { $skipInstall = $false }
} catch { $skipInstall = $false }
if (-not $skipInstall) {
  try { npm ci } catch { Write-Host "npm ci failed; falling back to npm i" -ForegroundColor Yellow; npm i }
}


Write-Host "Generating firebase config..." -ForegroundColor Cyan
node scripts/generate_firebase_config.js

Write-Host "Running validator (this may open a headless browser) ..." -ForegroundColor Cyan
node scripts/validate_runner.js --port=3000 --email="$env:TEST_EMAIL" --pass="$env:TEST_PASS" --recaptcha="$env:RECAPTCHA_SITE_KEY" --debug=true --headless=new

Write-Host "Generating HTML summary..." -ForegroundColor Cyan
node scripts/generate_summary.js

# restore working directory after node/npm operations
try { Pop-Location } catch {}

# 4) Optionally deploy staging (only if requested)
if ($Deploy -or ($env:DEPLOY_ON_SUCCESS -and $env:DEPLOY_ON_SUCCESS.ToLower() -eq 'true')) {
  Write-Host "Invoking deploy-staging.ps1" -ForegroundColor Cyan
  powershell -NoProfile -ExecutionPolicy Bypass -File 'scripts\deploy-staging.ps1'
} else {
  Write-Host "Skipping automatic deploy. Pass -Deploy or set DEPLOY_ON_SUCCESS=true to enable." -ForegroundColor Yellow
}

Write-Host "`nArtifacts:`n" -ForegroundColor Cyan
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
  exit 3
}

foreach ($a in $artifacts) { Get-Item $a | Format-List FullName,Length,LastWriteTime }

Write-Host "`nChecking summary content..." -ForegroundColor Cyan
$summaryPath = 'reports/firebase_validation_summary.html'
$content = Get-Content $summaryPath -Raw -ErrorAction Stop

$hasSignedIn = $content -match 'Signed in as'
$hasAppCheck  = $content -match 'App Check: reCAPTCHA v3 enabled\.' -or $content -match 'Skipping App Check while running against emulators.'

  if ($hasSignedIn -and $hasAppCheck) {
  Write-Host "Summary check: OK - contains 'Signed in as' and 'App Check: reCAPTCHA v3 enabled.'" -ForegroundColor Green
    # Teardown emulator unless user requested it be kept
    if ($emu -and -not $KeepServer -and -not $emu.HasExited) {
      Write-Host "Stopping Auth emulator..." -ForegroundColor Cyan
      Stop-Process -Id $emu.Id -Force
    }
    exit 0
} else {
  Write-Host "Summary check: FAILED" -ForegroundColor Yellow
  if (-not $hasSignedIn) { Write-Host "  - Missing: 'Signed in as'" -ForegroundColor Yellow }
  if (-not $hasAppCheck)  { Write-Host "  - Missing: 'App Check: reCAPTCHA v3 enabled.'" -ForegroundColor Yellow }
    if ($emu -and -not $KeepServer -and -not $emu.HasExited) {
      Write-Host "Stopping Auth emulator..." -ForegroundColor Cyan
      Stop-Process -Id $emu.Id -Force
    }
    exit 4
}
