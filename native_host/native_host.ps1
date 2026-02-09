# Chrome Native Messaging host for the extension updater.
# No Node.js or Python required - uses only PowerShell (built into Windows).
# Reads Chrome's length-prefixed JSON from stdin; on "run_update" runs update_extension.ps1.

$ErrorActionPreference = "Stop"
$HostDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Resolve-Path (Join-Path $HostDir "..")).Path
$UpdaterScript = Join-Path $ProjectRoot "update_extension.ps1"

$stdin = [System.Console]::OpenStandardInput()
$stdout = [System.Console]::OpenStandardOutput()

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
    if ($got -le 0) { exit 1 }
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
            if ($targetPathFromExtension -and $targetPathFromExtension.Trim()) {
                $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $UpdaterScript -TargetPath $targetPathFromExtension.Trim() 2>&1
            } else {
                $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $UpdaterScript 2>&1
            }
            $success = $LASTEXITCODE -eq 0
            $message = if ($output) { ($output | Out-String).Trim() } else { "Update complete. Reload the extension in chrome://extensions" }
            if (-not $success -and -not $message) { $message = "Updater exited with code $LASTEXITCODE" }
        } catch {
            $success = $false
            $message = $_.Exception.Message
        }
    } else {
        $success = $false
        $message = "update_extension.ps1 not found in project root"
    }
} else {
    $message = "Unknown action: $action"
}

$response = @{ success = $success; message = $message } | ConvertTo-Json -Compress
$responseBytes = [System.Text.Encoding]::UTF8.GetBytes($response)
$responseLenBytes = [System.BitConverter]::GetBytes([uint32]$responseBytes.Length)
$stdout.Write($responseLenBytes, 0, 4)
$stdout.Write($responseBytes, 0, $responseBytes.Length)
$stdout.Flush()
$stdout.Close()
