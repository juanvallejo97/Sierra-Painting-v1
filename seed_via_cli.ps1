# Seed Test Data via Firebase CLI
# Uses firestore:set commands to create job and assignment

$ErrorActionPreference = "Stop"

Write-Host "`n🌱 Seeding test data for staging...`n" -ForegroundColor Green

$TEST_USER_ID = "d5P01AlLCoaEAN5ua3hJFzcIJu2"
$TEST_COMPANY_ID = "test-company-staging"
$TEST_JOB_ID = "test-job-staging"
$JOB_LAT = 41.8825
$JOB_LNG = -71.3945

# Create job document
Write-Host "1️⃣ Creating job document..." -ForegroundColor Cyan
$jobData = @{
    companyId = $TEST_COMPANY_ID
    name = "Test Job Site - Staging"
    address = "123 Test Street, Providence, RI"
    geofence = @{
        lat = $JOB_LAT
        lng = $JOB_LNG
        radiusM = 150
    }
    status = "active"
} | ConvertTo-Json -Compress -Depth 10

Write-Host "   Job data: $jobData" -ForegroundColor Gray

# Use Firebase CLI to set the job
firebase firestore:set "jobs/$TEST_JOB_ID" "$jobData" --project sierra-painting-staging

Write-Host "   ✅ Job created: $TEST_JOB_ID`n" -ForegroundColor Green

# Create assignment document
Write-Host "2️⃣ Creating assignment document..." -ForegroundColor Cyan
$assignmentId = "test-assignment-staging"
$assignmentData = @{
    userId = $TEST_USER_ID
    companyId = $TEST_COMPANY_ID
    jobId = $TEST_JOB_ID
    active = $true
} | ConvertTo-Json -Compress -Depth 10

Write-Host "   Assignment data: $assignmentData" -ForegroundColor Gray

firebase firestore:set "assignments/$assignmentId" "$assignmentData" --project sierra-painting-staging

Write-Host "   ✅ Assignment created: $assignmentId`n" -ForegroundColor Green

Write-Host "✨ Seed operation completed!`n" -ForegroundColor Green
Write-Host "📍 Next Steps:" -ForegroundColor Yellow
Write-Host "   1. Refresh the browser (Ctrl+Shift+R)"
Write-Host "   2. Try clock-in again"
Write-Host "   3. Check console for 'Found 1 assignments' log`n"
