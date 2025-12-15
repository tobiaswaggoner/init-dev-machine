#------------------------------------------------------------------------------
# Remove WSL Instance
# Cleanly removes a WSL instance and its files
#------------------------------------------------------------------------------

param(
    [string]$DistroName,
    [string]$ConfigFile,
    [switch]$Force,          # Skip confirmation
    [switch]$KeepFiles       # Keep the installation directory
)

$ErrorActionPreference = "Stop"

function Expand-EnvVars {
    param([string]$Path)
    return [Environment]::ExpandEnvironmentVariables($Path.Replace('%USERPROFILE%', $env:USERPROFILE))
}

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  WSL Instance Removal" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# Get distro name from config or parameter
if ($ConfigFile -and (Test-Path $ConfigFile)) {
    $config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
    $DistroName = $config.wsl.distro_name
    $installPath = Expand-EnvVars $config.wsl.install_path
    Write-Host "  Config:  $ConfigFile" -ForegroundColor Gray
} elseif ($DistroName) {
    $installPath = "$env:USERPROFILE\wsl\$($DistroName.ToLower())"
} else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\remove-wsl.ps1 -ConfigFile ..\config.json" -ForegroundColor White
    Write-Host "  .\remove-wsl.ps1 -DistroName Debian-Dev" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host "  Distro:  $DistroName" -ForegroundColor White
Write-Host "  Path:    $installPath" -ForegroundColor White
Write-Host ""

# Check if instance exists
$existingDistros = wsl --list --quiet 2>$null
if ($existingDistros -notcontains $DistroName) {
    Write-Host "Instance '$DistroName' does not exist." -ForegroundColor Yellow

    # Check if files exist anyway
    if (Test-Path $installPath) {
        if (-not $Force) {
            $response = Read-Host "Installation directory exists. Remove it? [y/N]"
            if ($response -ne 'y' -and $response -ne 'Y') {
                Write-Host "Aborted." -ForegroundColor Gray
                exit 0
            }
        }
        Remove-Item -Recurse -Force $installPath
        Write-Host "Removed directory: $installPath" -ForegroundColor Green
    }
    exit 0
}

# Confirm removal
if (-not $Force) {
    Write-Host "This will permanently delete the WSL instance and all its data." -ForegroundColor Red
    $response = Read-Host "Are you sure? [y/N]"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Aborted." -ForegroundColor Gray
        exit 0
    }
}

# Remove WSL instance
Write-Host "Unregistering WSL instance..." -ForegroundColor Yellow
wsl --unregister $DistroName

if ($LASTEXITCODE -eq 0) {
    Write-Host "  Instance unregistered" -ForegroundColor Green
} else {
    Write-Host "  Warning: Unregister may have failed" -ForegroundColor Yellow
}

# Remove installation directory
if (-not $KeepFiles -and (Test-Path $installPath)) {
    Write-Host "Removing installation directory..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $installPath
    Write-Host "  Directory removed" -ForegroundColor Green
}

# Remove Windows Terminal profile (optional cleanup)
$terminalSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (Test-Path $terminalSettingsPath) {
    try {
        $settings = Get-Content $terminalSettingsPath -Raw | ConvertFrom-Json

        # Find and remove our custom profile
        $profiles = [System.Collections.ArrayList]@($settings.profiles.list)
        $toRemove = $profiles | Where-Object { $_.commandline -eq "wsl.exe -d $DistroName" }

        if ($toRemove) {
            $profiles.Remove($toRemove) | Out-Null
            $settings.profiles.list = $profiles.ToArray()
            $settings | ConvertTo-Json -Depth 100 | Set-Content $terminalSettingsPath -Encoding UTF8
            Write-Host "  Removed Windows Terminal profile" -ForegroundColor Green
        }
    } catch {
        Write-Host "  Could not update Windows Terminal settings" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "  Instance Removed Successfully" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  To recreate: .\setup-wsl.ps1 -ConfigFile ..\config.json" -ForegroundColor Cyan
Write-Host ""
