param([string]$Task = "help")
if (-not (Test-Path "C:\tmp")) { New-Item -ItemType Directory -Path "C:\tmp" | Out-Null }
$env:TEMP = "C:\tmp"; $env:TMP = "C:\tmp"
switch ($Task) {
    "web" { flutter run -d chrome --web-renderer html; break }
    "android" { flutter run -d emulator-5554; break }
    "test" { flutter test --concurrency=1 -r expanded; break }
    "fix" { flutter format .; dart fix --apply; flutter analyze; break }
    "smoke" { flutter test integration_test -d emulator-5554 -r compact; break }
    default { Write-Host "Use: pwsh scripts/dev.ps1 [web|android|test|fix|smoke]" }
}
