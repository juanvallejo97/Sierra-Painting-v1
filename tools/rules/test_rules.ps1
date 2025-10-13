###############################################################################
# Firestore Rules Test Runner (Windows PowerShell)
#
# PURPOSE:
# Runs Firestore security rules tests with emulators.
#
# USAGE:
# pwsh tools/rules/test_rules.ps1
#
# WHAT IT DOES:
# 1. Starts Firestore emulator in background
# 2. Waits for emulator to be ready
# 3. Runs rules matrix tests
# 4. Runs timekeeping rules tests
# 5. Stops emulator
# 6. Reports results
#
# ACCEPTANCE:
# - All rules tests pass
# - 100% coverage of security rules
###############################################################################

$ErrorActionPreference = "Stop"

# Colors
function Write-Success { param($msg) Write-Host $msg -ForegroundColor Green }
function Write-Warning { param($msg) Write-Host $msg -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host $msg -ForegroundColor Red }

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "🔒 Firestore Rules Tests" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Firebase CLI is installed
if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
    Write-Error "❌ Firebase CLI not found"
    Write-Host "Install with: npm install -g firebase-tools"
    exit 1
}

# Step 1: Start Firestore Emulator
Write-Warning "🔥 Step 1: Starting Firestore emulator..."

# Kill any existing emulator processes
Get-Process | Where-Object { $_.ProcessName -like "*java*" } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Start emulator in background
$emulatorJob = Start-Job -ScriptBlock {
    Set-Location $using:PWD
    firebase emulators:start --only firestore 2>&1 | Out-File -FilePath emulator.log
}

Write-Host "Emulator Job ID: $($emulatorJob.Id)"

# Wait for emulator to be ready
Write-Warning "⏳ Waiting for emulator to start..."
$retryCount = 0
$maxRetries = 30
$emulatorReady = $false

while ($retryCount -lt $maxRetries) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8080" -TimeoutSec 2 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Success "✓ Emulator ready"
            $emulatorReady = $true
            break
        }
    } catch {
        # Emulator not ready yet
    }

    $retryCount++
    Write-Host "  Attempt $retryCount/$maxRetries..."
    Start-Sleep -Seconds 2
}

if (-not $emulatorReady) {
    Write-Error "❌ Emulator failed to start"
    Write-Host "Check emulator.log for details"
    Stop-Job -Job $emulatorJob -ErrorAction SilentlyContinue
    Remove-Job -Job $emulatorJob -ErrorAction SilentlyContinue
    exit 1
}

Write-Host ""

# Step 2: Run Rules Tests
Write-Warning "🧪 Step 2: Running rules tests..."
Write-Host ""

Set-Location functions

# Run all rules tests
npm test -- --testPathPattern="rules.*test\.ts" --runInBand

$testExitCode = $LASTEXITCODE

Set-Location ..

Write-Host ""

# Step 3: Stop Emulator
Write-Warning "🛑 Step 3: Stopping emulator..."
Stop-Job -Job $emulatorJob -ErrorAction SilentlyContinue
Remove-Job -Job $emulatorJob -ErrorAction SilentlyContinue

# Force kill any remaining processes
Get-Process | Where-Object { $_.ProcessName -like "*java*" } | Stop-Process -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 2

# Cleanup
Remove-Item -Path "emulator.log" -Force -ErrorAction SilentlyContinue

# Step 4: Report Results
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
if ($testExitCode -eq 0) {
    Write-Success "✅ All Rules Tests PASSED"
} else {
    Write-Error "❌ Some Rules Tests FAILED"
    Write-Host ""
    Write-Host "Check test output above for details"
}
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

exit $testExitCode
