<#
Sierra Painting – Ship & Git (atomic)
Runs: tests → builds → deploys → git commit/push (optional branch delete)

Usage (PowerShell):
  ./scripts/ship_and_git.ps1 -ProjectAlias sierrapainting -HostingSite sierrapainting [-DeleteBranch]

Parameters:
  -ProjectAlias     Firebase alias to use (maps to project in .firebaserc). Default: sierrapainting
  -FirebaseProject  Optional explicit project id. If omitted, uses alias selection.
  -HostingSite      Firebase Hosting site id. Default: sierrapainting
  -DeleteBranch     If set, delete the current branch after successful push (skips main/master)
  -SkipTests        If set, skip test phase
  -SkipDeploy       If set, skip deploy phase (useful for local verify only)
#>
param(
  [string]$ProjectAlias = "sierrapainting",
  [string]$FirebaseProject = "",
  [string]$HostingSite = "sierrapainting",
  [switch]$DeleteBranch,
  [switch]$SkipTests,
  [switch]$SkipDeploy
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Section($title){ Write-Host "`n=== $title ===" -ForegroundColor Cyan }
function Run($cmd){
  Write-Host "› $cmd" -ForegroundColor DarkGray
  Invoke-Expression $cmd
  if ($LASTEXITCODE -ne 0) { throw "Command failed: $cmd (exit $LASTEXITCODE)" }
}
function Test-Cli($name,$check){
  try { & $check | Out-Null } catch { throw "$name CLI not found. Please install $name and retry." }
}

try {
  Write-Section "Sanity checks"
  Test-Cli "Git" { git --version }
  Test-Cli "Node" { node --version }
  Test-Cli "npm" { npm --version }
  Test-Cli "Firebase" { firebase --version }
  Test-Cli "Flutter" { flutter --version }

  # Select Firebase project via alias
  Run "firebase use $ProjectAlias"
  if ([string]::IsNullOrWhiteSpace($FirebaseProject)) {
    $FirebaseProject = $ProjectAlias
  }
  Write-Host "Project Id/Alias: $FirebaseProject" -ForegroundColor Green
  Write-Host "Hosting Site: $HostingSite" -ForegroundColor Green

  if (-not $SkipTests) {
    Write-Section "Tests"
    # Functions tests
    try { Run "npm --prefix functions ci --silent" } catch { Run "npm --prefix functions install" }
    Run "npm --prefix functions test -- --ci"

    # Flutter tests
    Run "flutter test"
  } else {
    Write-Host "Skipping tests (per flag)" -ForegroundColor Yellow
  }

  Write-Section "Build"
  Run "npm --prefix functions run build"
  Run "flutter build web --release"

  if (-not $SkipDeploy) {
    Write-Section "Deploy"
    $deployCmd = @(
      "firebase deploy",
      "--only `"functions,firestore:rules,firestore:indexes,storage,hosting:$HostingSite`"",
      "--project $FirebaseProject",
      "--non-interactive"
    ) -join ' '
    Run $deployCmd
  } else {
    Write-Host "Skipping deploy (per flag)" -ForegroundColor Yellow
  }

  Write-Section "Git commit & push"
  $branch = (git rev-parse --abbrev-ref HEAD).Trim()
  $msg = "chore(deploy): prod $(Get-Date -Format s) [branch:$branch]"
  Run "git add -A"
  # Use direct invocation so powershell handles argument quoting robustly
  Write-Host "› git commit -m '$msg' --allow-empty" -ForegroundColor DarkGray
  & git commit -m $msg --allow-empty
  if ($LASTEXITCODE -ne 0) {
    Write-Host "git commit returned exit code $LASTEXITCODE; continuing (no changes to commit)" -ForegroundColor Yellow
  }
  Run "git push origin $branch"

  if ($DeleteBranch) {
    if ($branch -in @('main','master')) {
      Write-Host "Refusing to delete protected branch '$branch'" -ForegroundColor Yellow
    } else {
      Write-Section "Delete branch ($branch)"
      Run "git checkout main"
      Run "git pull"
      Run "git push origin --delete $branch"
      Run "git branch -D $branch"
      Write-Host "Deleted branch $branch locally and on origin." -ForegroundColor Green
    }
  }

  Write-Host "`n✅ Ship & Git complete." -ForegroundColor Green
  Write-Host "Hosting URL: https://$HostingSite.web.app"
}
catch {
  Write-Host "`n❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
