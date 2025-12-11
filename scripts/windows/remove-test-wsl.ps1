#------------------------------------------------------------------------------
# Remove Test WSL Instance
# Run in PowerShell (no Admin required)
#------------------------------------------------------------------------------

$DistroName = "Debian-Test"
$InstallPath = "$env:USERPROFILE\wsl\debian-test"

Write-Host ""
Write-Host "========================================================" -ForegroundColor Yellow
Write-Host "  Removing Test WSL Instance: $DistroName" -ForegroundColor Yellow
Write-Host "========================================================" -ForegroundColor Yellow
Write-Host ""

$response = Read-Host "Are you sure you want to delete '$DistroName'? [y/N]"
if ($response -ne 'y' -and $response -ne 'Y') {
    Write-Host "Aborted." -ForegroundColor Red
    exit 0
}

# Unregister WSL instance
Write-Host "Unregistering WSL instance..." -ForegroundColor Yellow
wsl --unregister $DistroName 2>$null

# Remove directory
if (Test-Path $InstallPath) {
    Write-Host "Removing directory $InstallPath..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $InstallPath
}

Write-Host ""
Write-Host "Done! Instance '$DistroName' removed." -ForegroundColor Green
Write-Host ""
Write-Host "Note: The Windows Terminal profile remains. Remove manually if desired." -ForegroundColor Gray
