# Capture setup-related syslog without assuming that Desktop exists locally.
# Run from Windows PowerShell with the iPhone attached over USB.
# Press Ctrl+C after the setup attempt finishes or fails.
$ErrorActionPreference = 'Stop'

if (-not (Get-Command pymobiledevice3 -ErrorAction SilentlyContinue)) {
    throw 'pymobiledevice3 is not installed or is not available on PATH.'
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$file = Join-Path (Get-Location).Path ("homepod-setup-$stamp.txt")

Write-Host "Recording setup diagnostics to: $file"
Write-Host 'Start a fresh HomePod setup attempt. Press Ctrl+C when it finishes.'
Write-Warning 'The resulting log may contain identifiers, serial numbers, network details and account metadata. Review before sharing.'

# Match the entire HDSViewService process rather than selected error strings:
# this retains CoreUtils transition messages *before* the final timeout.
pymobiledevice3 syslog live |
    Select-String -Pattern 'HDSViewService|HomePodBridge|sharingd.*(Setup2|HomePodSetup)|homed.*(HomeKit|HomePod)' |
    Tee-Object -FilePath $file
