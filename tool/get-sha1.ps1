# Prints every SHA-1 / SHA-256 fingerprint Google needs for sign-in.
#
#   pwsh tool/get-sha1.ps1
#
# Debug key  -> for local testing (Firebase console, Google Cloud console)
# Upload key -> for release builds (must be registered too, or sign-in breaks
#               the moment you ship from CI / a release build)

$ErrorActionPreference = "Stop"

function Show-Fingerprint($label, $keystore, $alias, $storepass) {
    if (-not (Test-Path $keystore)) {
        Write-Host "$label : keystore not found at $keystore" -ForegroundColor Yellow
        return
    }

    Write-Host "`n$label" -ForegroundColor Cyan
    Write-Host "  keystore: $keystore"

    $lines = & keytool -list -v -keystore $keystore -storepass $storepass -alias $alias 2>$null
    $lines | Select-String "SHA1:|SHA256:" | ForEach-Object { Write-Host "  $_" }
}

# 1. Debug key (Flutter/Android Studio local runs)
$debugKs = Join-Path $env:USERPROFILE ".android\debug.keystore"
Show-Fingerprint "DEBUG key" $debugKs "androiddebugkey" "android"

# 2. Upload key (release builds)
$repoRoot = Split-Path -Parent $PSScriptRoot
$uploadKs = Join-Path $repoRoot "android\app\upload-keystore.jks"
$propsFile = Join-Path $repoRoot "android\key.properties"

if (Test-Path $propsFile) {
    $props = @{}
    Get-Content $propsFile | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') { $props[$Matches[1]] = $Matches[2] }
    }
    Show-Fingerprint "UPLOAD key" $uploadKs $props["keyAlias"] $props["storePassword"]
} else {
    Write-Host "`nUPLOAD key : android/key.properties not present (release falls back to debug key)" -ForegroundColor Yellow
}

Write-Host @"

Where to paste these:
  Firebase console  -> Project settings -> Your apps -> Add fingerprint
  Google Cloud      -> APIs & Services -> Credentials -> OAuth client (Android)
"@
