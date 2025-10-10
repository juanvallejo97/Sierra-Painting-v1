Param(
  [string]$Reporter   = "expanded",
  [int]   $Concurrency = 1,
  [string]$Timeout    = "3x",
  [string]$Project    = "demo-project",        # or your actual Firebase project id
  [switch]$InstallFirebaseCli                  # auto-install if missing
)

if ($InstallFirebaseCli -or !(Get-Command firebase -ErrorAction SilentlyContinue)) {
  Write-Host "Installing Firebase CLI..."
  iwr https://firebase.tools -UseBasicParsing | iex
}

$flutterLine = "flutter test integration_test -r $Reporter --concurrency=$Concurrency --timeout=$Timeout --dart-define=USE_EMULATORS=true"

Write-Host "firebase emulators:exec --project $Project --only firestore,functions,auth,storage -- cmd /c `"$flutterLine`""
firebase emulators:exec --project $Project --only firestore,functions,auth,storage -- `
  cmd /c "$flutterLine"
exit $LASTEXITCODE
