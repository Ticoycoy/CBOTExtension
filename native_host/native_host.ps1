# Chrome Native Messaging host for the extension updater.
# No Node.js or Python required - uses only PowerShell (built into Windows).
# Reads Chrome's length-prefixed JSON from stdin; on "run_update" runs update_extension.ps1.
# On any error we still send a JSON response so Chrome does not show "Error when communicating with the native messaging host".

$ErrorActionPreference = "Stop"
$HostDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile = Join-Path $HostDir "native_host_log.txt"

function Write-HostLog {
    param([string]$Text)
    try {
        $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Text"
        Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue
    } catch {}
}

function Send-Response {
    param([bool]$success, [string]$message)
    try {
        $response = @{ success = $success; message = $message } | ConvertTo-Json -Compress
        $responseBytes = [System.Text.Encoding]::UTF8.GetBytes($response)
        $responseLenBytes = [System.BitConverter]::GetBytes([uint32]$responseBytes.Length)
        $stdout.Write($responseLenBytes, 0, 4)
        $stdout.Write($responseBytes, 0, $responseBytes.Length)
        $stdout.Flush()
    } catch {
        Write-HostLog "Send-Response failed: $($_.Exception.Message)"
    }
    $stdout.Close()
}

$stdin = $null
$stdout = $null
try {
    $stdin = [System.Console]::OpenStandardInput()
    $stdout = [System.Console]::OpenStandardOutput()
} catch {
    Write-HostLog "Open stdin/stdout failed: $($_.Exception.Message)"
    exit 1
}

# Run updater from native_host folder (no project root file required on client)
$UpdaterScript = Join-Path $HostDir "update_extension.ps1"
if (-not (Test-Path $UpdaterScript)) {
    Write-HostLog "update_extension.ps1 not found: $UpdaterScript"
    Send-Response $false "Native host: update_extension.ps1 not found in native_host folder."
    exit 0
}

try {
    # Read 4-byte length (little-endian)
    $lenBuf = New-Object byte[] 4
    $n = $stdin.Read($lenBuf, 0, 4)
    if ($n -lt 4) { exit 0 }
    $length = [System.BitConverter]::ToUInt32($lenBuf, 0)
    if ($length -eq 0) { exit 0 }

    # Read message body
    $payload = New-Object byte[] $length
    $read = 0
    while ($read -lt $length) {
        $got = $stdin.Read($payload, $read, $length - $read)
        if ($got -le 0) { Send-Response $false "Native host: failed to read message"; exit 0 }
        $read += $got
    }

    $json = [System.Text.Encoding]::UTF8.GetString($payload)
    $msg = $json | ConvertFrom-Json
    $action = ($msg.action -as [string]).Trim().ToLower()

    $success = $false
    $message = ""

    if ($action -eq "run_update") {
        if (Test-Path $UpdaterScript) {
            try {
                $targetPathFromExtension = ($msg.target_path -as [string])
                $psArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $UpdaterScript)
                if ($targetPathFromExtension -and $targetPathFromExtension.Trim()) {
                    $psArgs += '-TargetPath'
                    $psArgs += $targetPathFromExtension.Trim()
                }
                $output = & powershell @psArgs 2>&1
                $success = $LASTEXITCODE -eq 0
                $message = if ($output) { ($output | Out-String).Trim() } else { "Update complete. Reload the extension in chrome://extensions" }
                if (-not $success -and -not $message) { $message = "Updater exited with code $LASTEXITCODE" }
            } catch {
                $success = $false
                $message = $_.Exception.Message
                Write-HostLog "run_update catch: $message"
            }
        } else {
            $success = $false
            $message = "update_extension.ps1 not found in native_host folder: $UpdaterScript"
            Write-HostLog $message
        }
    } else {
        $message = "Unknown action: $action"
    }

    Send-Response $success $message
} catch {
    $errMsg = $_.Exception.Message
    Write-HostLog "Unhandled error: $errMsg"
    Send-Response $false "Native host error: $errMsg"
}
