# Serve Flutter Web App
# Usage: pwsh ./scripts/serve_web.ps1 [port]
# Example: pwsh ./scripts/serve_web.ps1 9000

param(
    [int]$Port = 9000,
    [switch]$Build = $false,
    [switch]$Release = $true
)

Write-Host "=== Flutter Web Server ===" -ForegroundColor Cyan
Write-Host ""

# Change to project root
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

# Build if requested or if build doesn't exist
$BuildPath = "build\web"
if ($Build -or !(Test-Path $BuildPath)) {
    Write-Host "Building Flutter web app..." -ForegroundColor Yellow
    if ($Release) {
        flutter build web --release
    } else {
        flutter build web
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Build failed!" -ForegroundColor Red
        exit 1
    }
    Write-Host "Build complete!" -ForegroundColor Green
    Write-Host ""
}

# Find available port if specified port is in use
$OriginalPort = $Port
$MaxAttempts = 10
$PortFound = $false

for ($i = 0; $i -lt $MaxAttempts; $i++) {
    $TestPort = $Port + $i

    # Check if port is available
    $Connection = Get-NetTCPConnection -LocalPort $TestPort -ErrorAction SilentlyContinue

    if (!$Connection) {
        $Port = $TestPort
        $PortFound = $true
        break
    }
}

if (!$PortFound) {
    Write-Host "Could not find available port in range $OriginalPort-$($OriginalPort + $MaxAttempts - 1)" -ForegroundColor Red
    exit 1
}

if ($Port -ne $OriginalPort) {
    Write-Host "Port $OriginalPort in use, using port $Port instead" -ForegroundColor Yellow
    Write-Host ""
}

# Serve the app
Write-Host "Starting server on port $Port..." -ForegroundColor Green
Write-Host "App URL: http://localhost:$Port" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Gray
Write-Host ""

Set-Location $BuildPath

# Use npx http-server (cross-platform)
npx http-server -p $Port -o --cors
