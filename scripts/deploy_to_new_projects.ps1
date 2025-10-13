# Deploy to New Firebase Projects
# Run this AFTER creating sierra-painting-staging and sierra-painting-prod in Firebase Console
# This script will deploy indexes and rules to both projects

param(
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Firebase Deployment to New Projects" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Verify projects exist
Write-Host "Step 1: Verifying project access..." -ForegroundColor Yellow
firebase projects:list

$projects = firebase projects:list 2>&1 | Out-String
if ($projects -notmatch "sierra-painting-staging") {
    Write-Host "ERROR: sierra-painting-staging not found!" -ForegroundColor Red
    Write-Host "Please create the project first:" -ForegroundColor Red
    Write-Host "  1. Go to https://console.firebase.google.com/" -ForegroundColor Yellow
    Write-Host "  2. Click 'Add project'" -ForegroundColor Yellow
    Write-Host "  3. Project name: 'Sierra Painting Staging'" -ForegroundColor Yellow
    Write-Host "  4. Project ID: 'sierra-painting-staging'" -ForegroundColor Yellow
    exit 1
}

if ($projects -notmatch "sierra-painting-prod") {
    Write-Host "ERROR: sierra-painting-prod not found!" -ForegroundColor Red
    Write-Host "Please create the project first (see instructions above)" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Both projects found" -ForegroundColor Green
Write-Host ""

# Step 2: Apply fixed rules
Write-Host "Step 2: Applying fixed Firestore rules..." -ForegroundColor Yellow
if (Test-Path "firestore.rules.fixed") {
    Copy-Item "firestore.rules" "firestore.rules.backup" -Force
    Copy-Item "firestore.rules.fixed" "firestore.rules" -Force
    Write-Host "✓ Rules updated (backup saved to firestore.rules.backup)" -ForegroundColor Green
} else {
    Write-Host "WARNING: firestore.rules.fixed not found, using existing rules" -ForegroundColor Yellow
}
Write-Host ""

# Step 3: Deploy to staging
Write-Host "Step 3: Deploying to STAGING..." -ForegroundColor Yellow
firebase use staging

if ($DryRun) {
    Write-Host "[DRY RUN] Would deploy indexes to staging" -ForegroundColor Cyan
    Write-Host "[DRY RUN] Would deploy rules to staging" -ForegroundColor Cyan
} else {
    Write-Host "  Deploying indexes..." -ForegroundColor Gray
    firebase deploy --only firestore:indexes --project sierra-painting-staging

    Write-Host "  Deploying rules..." -ForegroundColor Gray
    firebase deploy --only firestore:rules --project sierra-painting-staging

    Write-Host "✓ Staging deployment complete" -ForegroundColor Green
}
Write-Host ""

# Step 4: Wait for staging indexes
Write-Host "Step 4: Waiting for staging indexes to build..." -ForegroundColor Yellow
Write-Host "  Check status: https://console.firebase.google.com/project/sierra-painting-staging/firestore/indexes" -ForegroundColor Gray
Write-Host ""
Write-Host "  Press Enter when all indexes show 'Enabled' status..." -ForegroundColor Yellow
if (-not $DryRun) {
    Read-Host
}
Write-Host ""

# Step 5: Deploy to production
Write-Host "Step 5: Deploying to PRODUCTION..." -ForegroundColor Yellow
firebase use production

if ($DryRun) {
    Write-Host "[DRY RUN] Would deploy indexes to production" -ForegroundColor Cyan
    Write-Host "[DRY RUN] Would deploy rules to production" -ForegroundColor Cyan
} else {
    Write-Host "  Deploying indexes..." -ForegroundColor Gray
    firebase deploy --only firestore:indexes --project sierra-painting-prod

    Write-Host "  Deploying rules..." -ForegroundColor Gray
    firebase deploy --only firestore:rules --project sierra-painting-prod

    Write-Host "✓ Production deployment complete" -ForegroundColor Green
}
Write-Host ""

# Step 6: Verification
Write-Host "Step 6: Verification checklist" -ForegroundColor Yellow
Write-Host "  [ ] Staging indexes enabled: https://console.firebase.google.com/project/sierra-painting-staging/firestore/indexes" -ForegroundColor Gray
Write-Host "  [ ] Production indexes enabled: https://console.firebase.google.com/project/sierra-painting-prod/firestore/indexes" -ForegroundColor Gray
Write-Host "  [ ] Rules deployed with 0 warnings (check output above)" -ForegroundColor Gray
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Enable Authentication (Email/Password) in both projects" -ForegroundColor Gray
Write-Host "  2. Enable Storage in both projects" -ForegroundColor Gray
Write-Host "  3. Configure App Check in both projects" -ForegroundColor Gray
Write-Host "  4. Run tests: npm --prefix functions run test" -ForegroundColor Gray
Write-Host ""
