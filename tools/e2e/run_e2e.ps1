###############################################################################
# E2E Test Runner (Windows PowerShell)
#
# PURPOSE:
# Automates the complete E2E demo test flow with Firebase emulators.
#
# USAGE:
# pwsh tools/e2e/run_e2e.ps1
#
# WHAT IT DOES:
# 1. Builds Cloud Functions (TypeScript → JavaScript)
# 2. Starts Firebase emulators in background
# 3. Waits for emulators to be ready
# 4. Runs E2E integration test
# 5. Stops emulators
# 6. Reports results
#
# REQUIREMENTS:
# - Node.js and npm installed
# - Firebase CLI installed (npm install -g firebase-tools)
# - Flutter SDK installed
# - Firebase emulators configured (firebase.json)
#
# ACCEPTANCE CRITERIA:
# - One command runs full demo path in <8 minutes
# - Emulators start/stop automatically
# - Clear pass/fail reporting
###############################################################################

$ErrorActionPreference = "Stop"

# Colors
function Write-Success { param($msg) Write-Host $msg -ForegroundColor Green }
function Write-Warning { param($msg) Write-Host $msg -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host $msg -ForegroundColor Red }

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "🧪 E2E Demo Test Runner" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Firebase CLI is installed
if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
    Write-Error "❌ Firebase CLI not found"
    Write-Host "Install with: npm install -g firebase-tools"
    exit 1
}

# Check if Flutter is installed
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "❌ Flutter not found"
    Write-Host "Install Flutter: https://flutter.dev/docs/get-started/install"
    exit 1
}

# Step 1: Build Cloud Functions
Write-Warning "📦 Step 1: Building Cloud Functions..."
npm --prefix functions run build

if ($LASTEXITCODE -ne 0) {
    Write-Error "❌ Functions build failed"
    exit 1
}

Write-Success "✓ Functions built"
Write-Host ""

# Step 2: Start Firebase Emulators
Write-Warning "🔥 Step 2: Starting Firebase emulators..."

# Kill any existing emulator processes
Get-Process | Where-Object { $_.ProcessName -like "*java*" -or $_.ProcessName -like "*firebase*" } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Start emulators in background
$emulatorJob = Start-Job -ScriptBlock {
    Set-Location $using:PWD
    firebase emulators:start --only firestore,functions,auth 2>&1 | Out-File -FilePath emulator.log
}

Write-Host "Emulator Job ID: $($emulatorJob.Id)"

# Wait for emulators to be ready (check Firestore endpoint)
Write-Warning "⏳ Waiting for emulators to start..."
$retryCount = 0
$maxRetries = 30
$emulatorsReady = $false

while ($retryCount -lt $maxRetries) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8080" -TimeoutSec 2 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Success "✓ Emulators ready"
            $emulatorsReady = $true
            break
        }
    } catch {
        # Emulators not ready yet
    }

    $retryCount++
    Write-Host "  Attempt $retryCount/$maxRetries..."
    Start-Sleep -Seconds 2
}

if (-not $emulatorsReady) {
    Write-Error "❌ Emulators failed to start"
    Write-Host "Check emulator.log for details"
    Stop-Job -Job $emulatorJob -ErrorAction SilentlyContinue
    Remove-Job -Job $emulatorJob -ErrorAction SilentlyContinue
    exit 1
}

Write-Host ""

# Step 3: Run E2E Test
Write-Warning "🧪 Step 3: Running E2E test..."
Write-Host ""

$startTime = Get-Date

# Run the integration test
flutter test integration_test/e2e_demo_test.dart `
    --dart-define=USE_EMULATORS=true `
    --dart-define=FLUTTER_TEST=true `
    --concurrency=1

$testExitCode = $LASTEXITCODE

$endTime = Get-Date
$duration = [math]::Round(($endTime - $startTime).TotalSeconds)

Write-Host ""

# Step 4: Stop Emulators
Write-Warning "🛑 Step 4: Stopping emulators..."
Stop-Job -Job $emulatorJob -ErrorAction SilentlyContinue
Remove-Job -Job $emulatorJob -ErrorAction SilentlyContinue

# Force kill any remaining processes
Get-Process | Where-Object { $_.ProcessName -like "*java*" } | Stop-Process -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 2

# Cleanup
Remove-Item -Path "emulator.log" -Force -ErrorAction SilentlyContinue

# Step 5: Report Results
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
if ($testExitCode -eq 0) {
    Write-Success "✅ E2E Test PASSED"
    Write-Host "Duration: ${duration}s"
    Write-Host "Acceptance: <480s (8 min)"

    if ($duration -lt 480) {
        Write-Success "✓ Within SLO"
    } else {
        Write-Warning "⚠ Exceeded SLO"
    }
} else {
    Write-Error "❌ E2E Test FAILED"
    Write-Host "Duration: ${duration}s"
    Write-Host ""
    Write-Host "Check test output above for details"
}
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

exit $testExitCode
