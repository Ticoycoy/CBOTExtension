# Launcher: runs the updater script from native_host folder.
# Use this when running manually from project root (e.g. .\update_extension.ps1).
# The extension's Update button runs native_host\update_extension.ps1 directly (no root files needed on client).

$ScriptDir = $PSScriptRoot
$UpdaterScript = Join-Path $ScriptDir "native_host\update_extension.ps1"
if (-not (Test-Path $UpdaterScript)) {
    Write-Error "update_extension.ps1 not found in native_host folder: $UpdaterScript"
    exit 1
}
& $UpdaterScript @args
