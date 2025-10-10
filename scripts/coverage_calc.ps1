# Calculate test coverage from lcov.info

$lcovFile = "coverage\lcov.info"

if (!(Test-Path $lcovFile)) {
    Write-Host "Coverage file not found: $lcovFile"
    exit 1
}

$content = Get-Content $lcovFile

$totalLines = 0
$hitLines = 0

foreach ($line in $content) {
    if ($line -match '^LF:(\d+)$') {
        $totalLines += [int]$matches[1]
    }
    if ($line -match '^LH:(\d+)$') {
        $hitLines += [int]$matches[1]
    }
}

if ($totalLines -gt 0) {
    $coverage = [math]::Round(($hitLines / $totalLines) * 100, 2)
    Write-Host "Total Lines: $totalLines"
    Write-Host "Hit Lines: $hitLines"
    Write-Host "Coverage: $coverage%"
} else {
    Write-Host "No coverage data found"
}
