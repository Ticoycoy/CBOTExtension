# Extension updater - updates the extension folder from a GitHub repo (PowerShell only, no git required).
# Flow: download repo zip from GitHub -> extract to temp -> copy to target_path.
# Config: repo_url (required), branch (default main), target_path (where to deploy), source_subfolder (e.g. "public", default "public").

param([string]$TargetPath)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot

if ((Split-Path -Leaf $ScriptDir) -eq "native_host") {
    $ProjectRoot = Split-Path -Parent $ScriptDir
    $ConfigPath = Join-Path $ScriptDir "updater_config.json"
} else {
    $ProjectRoot = $ScriptDir
    $ConfigPath = Join-Path $ProjectRoot "updater_config.json"
}

# Load config
if (-not (Test-Path $ConfigPath)) {
    Write-Error "updater_config.json not found: $ConfigPath. Create it with repo_url and target_path (use double backslashes in paths)."
    exit 1
}
try {
    $config = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
    Write-Error "Invalid updater_config.json: $($_.Exception.Message). Use double backslashes in paths."
    exit 1
}

$repoUrl = ($config.repo_url -as [string]).Trim()
if (-not $repoUrl) {
    Write-Error "repo_url is required in updater_config.json. Example: ""repo_url"":""https://github.com/owner/repo"" or .git"
    exit 1
}

$branch = ($config.branch -as [string])
if (-not $branch) { $branch = "main" }
$branch = $branch.Trim()

$targetPath = $TargetPath
if (-not $targetPath -or -not $targetPath.Trim()) {
    $targetPath = ($config.target_path -as [string])
}
if (-not $targetPath -or -not $targetPath.Trim()) {
    # Default: project's public folder
    $targetPath = Join-Path $ProjectRoot "public"
}

$sourceSubfolder = ($config.source_subfolder -as [string])
if ($null -eq $sourceSubfolder) { $sourceSubfolder = "public" }
$sourceSubfolder = $sourceSubfolder.Trim()

# Parse GitHub URL: https://github.com/owner/repo or https://github.com/owner/repo.git
$repoUrl = $repoUrl -replace '\.git$', ''
if ($repoUrl -notmatch 'github\.com[/:]([^/]+)/([^/]+?)/?$') {
    Write-Error "repo_url must be a GitHub URL, e.g. https://github.com/owner/repo"
    exit 1
}
$owner = $Matches[1]
$repo = $Matches[2].TrimEnd('/')

$zipUrl = "https://github.com/$owner/$repo/archive/refs/heads/$branch.zip"
$resolvedTarget = [System.IO.Path]::GetFullPath($targetPath.Trim())

$tempDir = $null
try {
    Write-Host "Downloading from GitHub: $zipUrl"
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "extension-updater-$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    $zipPath = Join-Path $tempDir "repo.zip"
    try {
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing -MaximumRedirection 5
    } catch {
        Write-Error "Download failed: $($_.Exception.Message). Check repo_url, branch, and network."
        exit 1
    }

    if (-not (Test-Path $zipPath) -or (Get-Item $zipPath).Length -eq 0) {
        Write-Error "Download failed: empty or missing file."
        exit 1
    }

    $extractDir = Join-Path $tempDir "extract"
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

    # GitHub zip contains one folder: repo-branch (e.g. CBOTExtension-main)
    $extractedTop = Get-ChildItem -Path $extractDir -Directory | Select-Object -First 1
    if (-not $extractedTop) {
        Write-Error "Downloaded zip has unexpected structure (no top-level folder)."
        exit 1
    }

    $sourceDir = if ($sourceSubfolder) {
        Join-Path $extractedTop.FullName $sourceSubfolder
    } else {
        $extractedTop.FullName
    }

    if (-not (Test-Path $sourceDir)) {
        Write-Error "Source folder not found in repo: $sourceSubfolder (repo has: $($extractedTop.Name)). Check source_subfolder in config."
        exit 1
    }

    # Update files inside the existing folder (do not replace the folder — same as build tools).
    # Keeps the same folder so Chrome still recognizes it as the same unpacked extension.
    if (-not (Test-Path $resolvedTarget)) {
        New-Item -ItemType Directory -Path $resolvedTarget -Force | Out-Null
    }

    $robocopy = Get-Command robocopy -ErrorAction SilentlyContinue
    if ($robocopy) {
        $rc = & robocopy $sourceDir $resolvedTarget /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS
        if ($LASTEXITCODE -ge 8) {
            Write-Error "Robocopy failed (exit code $LASTEXITCODE). Copy to $resolvedTarget failed."
            exit 1
        }
    } else {
        Copy-Item -Path (Join-Path $sourceDir "*") -Destination $resolvedTarget -Recurse -Force
    }

    Write-Host "Updated from GitHub ($owner/$repo, branch: $branch) to: $resolvedTarget"
    Write-Host "Reload the extension in chrome://extensions."
    exit 0
} catch {
    Write-Error "Update failed: $($_.Exception.Message)"
    exit 1
} finally {
    if ($tempDir -and (Test-Path $tempDir)) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
