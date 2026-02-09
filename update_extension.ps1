# Extension updater - no Node.js or Python required (PowerShell only, built into Windows).
# Copies public/ to the target folder. Path can come from:
#   1. -TargetPath parameter (sent by the extension when you set path in the popup)
#   2. updater_config.json in project root (fallback if extension doesn't send path)

param([string]$TargetPath)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
$ConfigPath = Join-Path $ProjectRoot "updater_config.json"
$PublicDir = Join-Path $ProjectRoot "public"

$targetPath = $TargetPath
if (-not $targetPath -or -not $targetPath.Trim()) {
    if (Test-Path $ConfigPath) {
        try {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $targetPath = $config.target_path
        } catch {
            Write-Error "Invalid updater_config.json: $($_.Exception.Message)"
            exit 1
        }
    }
    if (-not $targetPath -or ($targetPath -isnot [string]) -or -not $targetPath.Trim()) {
        Write-Error "Set extension folder path in the popup (Update area), or create updater_config.json with ""target_path""."
        exit 1
    }
}

$resolvedTarget = [System.IO.Path]::GetFullPath($targetPath.Trim())
if (-not (Test-Path $PublicDir)) {
    Write-Error "public/ folder not found in project root."
    exit 1
}

try {
    if (-not (Test-Path $resolvedTarget)) {
        New-Item -ItemType Directory -Path $resolvedTarget -Force | Out-Null
    }
    Copy-Item -Path (Join-Path $PublicDir "*") -Destination $resolvedTarget -Recurse -Force
    Write-Host "Updated extension files at: $resolvedTarget"
    exit 0
} catch {
    Write-Error "Copy failed: $($_.Exception.Message)"
    exit 1
}
