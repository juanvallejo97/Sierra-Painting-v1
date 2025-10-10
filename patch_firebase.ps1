# PowerShell script to patch firebase.json

# Ensure the script stops on errors
$ErrorActionPreference = "Stop"

# Define the path to firebase.json
$f = "firebase.json"

# Check if firebase.json exists
if (-Not (Test-Path $f)) {
    Write-Error "firebase.json not found in the current directory."
    exit 1
}

# Create a temporary file for intermediate changes
$tmp = [System.IO.Path]::GetTempFileName()

# Step 1: Remove invalid hosting.remoteConfig, enable Emulator UI, correct endpoints, and add headers
Get-Content $f | jq '.hosting |= (del(.remoteConfig)) |
    .emulators.ui.enabled = true |
    .emulators.ui.port = (.emulators.ui.port // 4400) |
    .functions[0].endpoints = {
    "createLead":   {"region":"us-east4","minInstances":0,"concurrency":40,"timeoutSeconds":30,"memory":"512MiB"},
        "createLead":   {"region":"us-east4","minInstances":0,"concurrency":40,"timeoutSeconds":30,"memory":"512MiB"},
        "healthCheck":  {"region":"us-east4",  "minInstances":0,"concurrency":5, "timeoutSeconds":10,"memory":"256MiB"}
    } |
    .hosting.headers += [
        {"source": "/flutter_bootstrap.js", "headers":[{"key":"Cache-Control","value":"no-cache"}]},
        {"source": "/flutter.js",           "headers":[{"key":"Cache-Control","value":"no-cache"}]},
        {"source": "/assets/**",            "headers":[{"key":"Cache-Control","value":"public, max-age=31536000, immutable"}]},
        {"source": "/canvaskit/**",         "headers":[{"key":"Cache-Control","value":"public, max-age=31536000, immutable"}]}
    ]' > $tmp

# Overwrite the original file
Move-Item -Force $tmp $f

# Step 2: Add a dev-safe Content-Security-Policy (CSP)
$tmp = [System.IO.Path]::GetTempFileName()
Get-Content $f | jq '.hosting.headers += [
    {
        "source": "/",
        "headers": [
            {
                "key": "Content-Security-Policy",
                "value": "default-src 'self' data: blob: https:; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' https://*.googleapis.com https://*.firebaseio.com ws: http: https:; worker-src 'self' blob:;"
            }
        ]
    }
]' > $tmp

# Overwrite the original file
Move-Item -Force $tmp $f

Write-Host "firebase.json has been successfully patched."