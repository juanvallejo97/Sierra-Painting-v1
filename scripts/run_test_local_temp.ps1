Param(
  [string]$TestPath   = "test",                # e.g. test/layout_probe_test.dart
  [string]$Reporter   = "expanded",
  [int]   $Concurrency = 1,
  [string]$Timeout    = "2x",
  [switch]$Coverage,
  [string[]]$Extra    = @()                    # any extra flutter test flags
)

# Stable TEMP/TMP so cleanup doesn’t blow up
$td = Join-Path (Get-Location) '.test_temp'
if (-not (Test-Path $td)) { New-Item -ItemType Directory -Path $td | Out-Null }
$env:TEMP = $td; $env:TMP = $td
Write-Host ("Using TEMP=" + $env:TEMP)

# Build arguments (avoid the reserved $args)
$flutterArgs = @("test")
if ($Coverage) { $flutterArgs += "--coverage" }
$flutterArgs += @(
  $TestPath,
  "-r", $Reporter,
  "--concurrency=$Concurrency",
  "--timeout=$Timeout",
  "--dart-define=FLUTTER_TEST=true"
) + $Extra

Write-Host "flutter $($flutterArgs -join ' ')"
& flutter @flutterArgs
exit $LASTEXITCODE
