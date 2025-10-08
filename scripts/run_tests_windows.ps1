$ErrorActionPreference = "Stop"
if (-not (Test-Path "C:\tmp")) { New-Item -ItemType Directory -Path "C:\tmp" | Out-Null }
$env:TEMP = "C:\tmp"; $env:TMP = "C:\tmp"
flutter format --set-exit-if-changed .
flutter analyze
# Unit + widget tests (serial to avoid temp-listener races)
flutter test --concurrency=1 -r expanded