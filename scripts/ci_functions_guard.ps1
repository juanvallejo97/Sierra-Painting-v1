$json = Get-Content firebase.json | ConvertFrom-Json
$min = $json.functions.endpoints.api.minInstances
if ($null -eq $min -or $min -lt 1) {
    Write-Error "CI guard: functions 'api.minInstances' must be >= 1."
    exit 1
}