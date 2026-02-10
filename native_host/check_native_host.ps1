# Run this on the CLIENT machine (where you see "Error when communicating with the native messaging host").
# It checks registry, manifest path, run_host.bat, and extension ID.
# Usage: powershell -ExecutionPolicy Bypass -File .\check_native_host.ps1

$HostName = "com.cbph.autofill.updater"
$errors = @()
$ok = @()

# 1. Registry
$regPath = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\$HostName"
if (-not (Test-Path $regPath)) {
    $errors += "Registry key not found: $regPath"
    $errors += "  -> Run install_native_host.ps1 on this machine first."
} else {
    $manifestPath = (Get-ItemProperty -Path $regPath -Name "(Default)" -ErrorAction SilentlyContinue)."(Default)"
    if (-not $manifestPath) {
        $errors += "Registry key exists but (Default) value is missing."
    } else {
        $ok += "Registry: $regPath -> $manifestPath"
    }
}

# 2. Manifest file exists and path inside it
$manifestPath = $null
try { $manifestPath = (Get-ItemProperty -Path $regPath -Name "(Default)" -ErrorAction Stop)."(Default)" } catch {}
if ($manifestPath -and (Test-Path $manifestPath)) {
    $ok += "Manifest file exists: $manifestPath"
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    $runHostPath = $manifest.path
    if (-not $runHostPath) {
        $errors += "Manifest has no 'path' field."
    } elseif (-not (Test-Path $runHostPath)) {
        $errors += "run_host.bat NOT FOUND at path in manifest: $runHostPath"
        $errors += "  -> Path is from when you ran the installer. Re-run install_native_host.ps1 on this machine with the correct path."
    } else {
        $ok += "run_host.bat exists: $runHostPath"
        # Check content - must use PowerShell, not Python
        $batContent = Get-Content $runHostPath -Raw
        if ($batContent -match "python\s+.*native_host\.py") {
            $errors += "run_host.bat still calls PYTHON. It must call PowerShell (native_host.ps1). Replace with the version that uses: powershell ... native_host.ps1"
        } else {
            $ok += "run_host.bat uses PowerShell (not Python)."
        }
    }
    $allowedOrigin = $manifest.allowed_origins
    if ($allowedOrigin) { $ok += "Allowed origin in manifest: $($allowedOrigin[0])" }
} elseif ($manifestPath) {
    $errors += "Manifest file NOT FOUND: $manifestPath"
}

# 3. native_host.ps1 and update_extension.ps1
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$hostPs1 = Join-Path $scriptDir "native_host.ps1"
$updaterPs1 = Join-Path $scriptDir "update_extension.ps1"
if (Test-Path $hostPs1) { $ok += "native_host.ps1 exists: $hostPs1" } else { $errors += "native_host.ps1 not found: $hostPs1" }
if (Test-Path $updaterPs1) { $ok += "update_extension.ps1 exists: $updaterPs1" } else { $errors += "update_extension.ps1 not found in native_host folder: $updaterPs1" }

# 4. Extension ID reminder
$ok += "Extension ID: Get it from chrome://extensions on THIS machine and ensure it matches the 'allowed_origins' in the manifest (chrome-extension://YOUR_ID/). Unpacked extensions get different IDs on different machines."

Write-Host ""
Write-Host "=== Native host check ===" -ForegroundColor Cyan
foreach ($line in $ok)  { Write-Host "  [OK] $line" -ForegroundColor Green }
foreach ($line in $errors) { Write-Host "  [FAIL] $line" -ForegroundColor Red }
Write-Host ""

if ($errors.Count -gt 0) {
    Write-Host "Fix the issues above, then run install_native_host.ps1 again on this machine. Reload the extension and try Update." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "All checks passed. If you still get the error: reload the extension, ensure Chrome is restarted after installing the host, and try Update again." -ForegroundColor Green
    exit 0
}
