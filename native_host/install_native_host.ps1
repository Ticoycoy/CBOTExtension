# One-time setup: register the native messaging host so the extension popup
# can trigger the updater. Run this once per machine after loading the extension.
# No Python required on Windows - use this script instead of install_native_host.py
#
# Usage (run in PowerShell, or right-click -> Run with PowerShell):
#   .\install_native_host.ps1
#
# You will be prompted for:
#   1. Extension ID - from chrome://extensions (enable Developer mode, copy ID under the extension)
#   2. Path to run_host.bat - default is the folder containing this script

$ErrorActionPreference = "Stop"
$HostName = "com.cbph.autofill.updater"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TemplatePath = Join-Path $ScriptDir "$HostName.json.template"
$ManifestPath = Join-Path $ScriptDir "$HostName.json"
$DefaultRunHostPath = Join-Path $ScriptDir "run_host.bat"

if (-not (Test-Path $TemplatePath)) {
    Write-Host "Template not found: $TemplatePath"
    exit 1
}

$extensionId = Read-Host "Extension ID (from chrome://extensions)"
if ([string]::IsNullOrWhiteSpace($extensionId)) {
    Write-Host "Extension ID is required."
    exit 1
}

$pathPrompt = "Full path to run_host.bat [$DefaultRunHostPath]"
$pathInput = Read-Host $pathPrompt
if ([string]::IsNullOrWhiteSpace($pathInput)) { $pathInput = $DefaultRunHostPath }
$pathInput = [System.IO.Path]::GetFullPath($pathInput)

if (-not (Test-Path $pathInput)) {
    Write-Host "File not found: $pathInput"
    exit 1
}

# In JSON, backslash must be escaped as \\
$pathForJson = $pathInput.Replace('\', '\\')
$template = Get-Content $TemplatePath -Raw
$template = $template -replace "ABSOLUTE_PATH_TO_RUN_HOST_BAT", $pathForJson
$template = $template -replace "EXTENSION_ID", $extensionId

Set-Content -Path $ManifestPath -Value $template -Encoding UTF8
Write-Host "Wrote: $ManifestPath"

$regPath = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\$HostName"
New-Item -Path $regPath -Force | Out-Null
Set-ItemProperty -Path $regPath -Name "(Default)" -Value $ManifestPath
Write-Host "Registered in Windows registry: $regPath"

Write-Host "Done. You can now use the Update button in the extension popup."
