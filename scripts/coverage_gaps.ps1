# Identify files with low test coverage

$lcovFile = "coverage\lcov.info"

if (!(Test-Path $lcovFile)) {
    Write-Host "Coverage file not found: $lcovFile"
    exit 1
}

$content = Get-Content $lcovFile

$files = @()
$currentFile = $null

foreach ($line in $content) {
    if ($line -match '^SF:(.+)$') {
        $currentFile = @{
            Path = $matches[1]
            TotalLines = 0
            HitLines = 0
            Coverage = 0
        }
    }
    if ($line -match '^LF:(\d+)$') {
        $currentFile.TotalLines = [int]$matches[1]
    }
    if ($line -match '^LH:(\d+)$') {
        $currentFile.HitLines = [int]$matches[1]
    }
    if ($line -eq 'end_of_record') {
        if ($currentFile.TotalLines -gt 0) {
            $currentFile.Coverage = [math]::Round(($currentFile.HitLines / $currentFile.TotalLines) * 100, 2)
        }
        $files += $currentFile
        $currentFile = $null
    }
}

# Sort by coverage (ascending) and show files with < 60% coverage
Write-Host "`nFiles with < 60% coverage (sorted by coverage):`n"
Write-Host "{0,-80} {1,8} {2,8} {3,8}" -f "File", "Lines", "Hit", "Coverage"
Write-Host ("{0}" -f ("-" * 110))

$files | Where-Object { $_.Coverage -lt 60 -and $_.TotalLines -gt 0 } | Sort-Object Coverage | ForEach-Object {
    $shortPath = $_.Path -replace '.*\\lib\\', 'lib\'
    Write-Host ("{0,-80} {1,8} {2,8} {3,7}%" -f $shortPath, $_.TotalLines, $_.HitLines, $_.Coverage)
}
