# Wrapper to set placeholder test env vars then run preflight
$env:TEST_EMAIL = 'test@example.com'
$env:TEST_PASS = 'Password123!'
$env:RECAPTCHA_SITE_KEY = 'test-recaptcha-key'
$env:TIMEOUT_MS = '120000'
# Keep emulator running for inspection (remove -KeepServer to let it teardown)
& "$PSScriptRoot\run_preflight_local.ps1" -KeepServer
