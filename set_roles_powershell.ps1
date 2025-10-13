# PowerShell Script to Set User Roles
# Run from project root: .\set_roles_powershell.ps1

$adminUid = "yqLJSx5NH1YHKa9WxIOhCrqJcPp1"
$workerUid = "d5POlAllCoacEAN5uajhJfzcIJu2"
$companyId = "test-company-staging"

Write-Host "Setting admin role for UID: $adminUid" -ForegroundColor Cyan

# Create JSON file for admin
$adminJson = @{
    uid = $adminUid
    role = "admin"
    companyId = $companyId
} | ConvertTo-Json

$adminJson | Out-File -FilePath ".\admin_role.json" -Encoding utf8

# Call function with JSON file
firebase functions:call setUserRole --project sierra-painting-staging < admin_role.json

Write-Host "`nSetting worker role for UID: $workerUid" -ForegroundColor Cyan

# Create JSON file for worker
$workerJson = @{
    uid = $workerUid
    role = "worker"
    companyId = $companyId
} | ConvertTo-Json

$workerJson | Out-File -FilePath ".\worker_role.json" -Encoding utf8

# Call function with JSON file
firebase functions:call setUserRole --project sierra-painting-staging < worker_role.json

# Clean up JSON files
Remove-Item ".\admin_role.json" -ErrorAction SilentlyContinue
Remove-Item ".\worker_role.json" -ErrorAction SilentlyContinue

Write-Host "`nDone! Check output above for success messages." -ForegroundColor Green
