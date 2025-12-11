#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Create Test WSL Instance for Infrastructure Setup Testing
# Run in PowerShell (no Admin required)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$ErrorActionPreference = "Stop"

# Configuration
$DistroName = "Debian-Test"
$InstallPath = "$env:USERPROFILE\wsl\debian-test"
$TarballPath = "$env:USERPROFILE\wsl\installer\debian.install.tar.gz"
$DefaultUser = "testuser"

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  Creating Test WSL Instance: $DistroName" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# Step 1: Verify tarball exists
Write-Host "[1/5] Checking tarball..." -ForegroundColor Yellow
if (-not (Test-Path $TarballPath)) {
    Write-Host "ERROR: Tarball not found at $TarballPath" -ForegroundColor Red
    exit 1
}
Write-Host "  Found: $TarballPath" -ForegroundColor Green

# Step 2: Check if instance already exists
Write-Host "[2/5] Checking for existing instance..." -ForegroundColor Yellow
$existingDistros = wsl --list --quiet 2>$null
if ($existingDistros -contains $DistroName) {
    Write-Host "  Instance '$DistroName' already exists." -ForegroundColor Yellow
    $response = Read-Host "  Delete and recreate? [y/N]"
    if ($response -eq 'y' -or $response -eq 'Y') {
        Write-Host "  Removing existing instance..." -ForegroundColor Yellow
        wsl --unregister $DistroName
        if (Test-Path $InstallPath) {
            Remove-Item -Recurse -Force $InstallPath
        }
    } else {
        Write-Host "  Aborted." -ForegroundColor Red
        exit 0
    }
}

# Step 3: Create directory and import
Write-Host "[3/5] Importing WSL instance..." -ForegroundColor Yellow
if (-not (Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
}
Write-Host "  Target: $InstallPath"
wsl --import $DistroName $InstallPath $TarballPath
Write-Host "  Import complete!" -ForegroundColor Green

# Step 4: Create user and configure
Write-Host "[4/5] Setting up user '$DefaultUser'..." -ForegroundColor Yellow

# Create user with sudo access
wsl -d $DistroName -u root -- bash -c @"
# Install sudo if not present
apt-get update -qq && apt-get install -y -qq sudo > /dev/null 2>&1

# Create user
useradd -m -s /bin/bash $DefaultUser 2>/dev/null || true
echo '${DefaultUser}:test123' | chpasswd
usermod -aG sudo $DefaultUser 2>/dev/null || true

# Allow passwordless sudo for easier testing
echo '$DefaultUser ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$DefaultUser

# Set as default user via wsl.conf
cat > /etc/wsl.conf << 'WSLCONF'
[user]
default=$DefaultUser

[boot]
systemd=true
WSLCONF

echo "User $DefaultUser created successfully"
"@

Write-Host "  User '$DefaultUser' created (password: test123)" -ForegroundColor Green

# Step 5: Add Windows Terminal profile
Write-Host "[5/5] Adding Windows Terminal profile..." -ForegroundColor Yellow

$terminalSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

if (Test-Path $terminalSettingsPath) {
    # Read current settings
    $settings = Get-Content $terminalSettingsPath -Raw | ConvertFrom-Json

    # Generate a new GUID
    $newGuid = "{$([guid]::NewGuid().ToString())}"

    # Check if profile already exists
    $existingProfile = $settings.profiles.list | Where-Object { $_.name -eq "Debian Test" }

    if (-not $existingProfile) {
        # Create new profile
        $newProfile = [PSCustomObject]@{
            name = "Debian Test"
            guid = $newGuid
            commandline = "wsl.exe -d $DistroName"
            icon = "ms-appx:///ProfileIcons/{9acb9455-7cd5-481c-ae2e-8ed9c41b7e14}.png"
            colorScheme = "Campbell"
            background = "#330000"
            tabTitle = "Debian TEST"
            suppressApplicationTitle = $true
        }

        # Add to profiles list
        $settings.profiles.list += $newProfile

        # Save settings
        $settings | ConvertTo-Json -Depth 100 | Set-Content $terminalSettingsPath -Encoding UTF8

        Write-Host "  Windows Terminal profile added!" -ForegroundColor Green
        Write-Host "  Profile GUID: $newGuid" -ForegroundColor Gray
    } else {
        Write-Host "  Profile 'Debian Test' already exists, skipping" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Windows Terminal settings not found, skipping profile creation" -ForegroundColor Yellow
    Write-Host "  Manual profile config:" -ForegroundColor Yellow
    Write-Host @"
    {
        "name": "Debian Test",
        "guid": "{$(([guid]::NewGuid().ToString()))}",
        "commandline": "wsl.exe -d $DistroName",
        "background": "#330000",
        "tabTitle": "Debian TEST"
    }
"@ -ForegroundColor Gray
}

# Done
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "  Test Instance Ready!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host ""
Write-Host "  Instance:  $DistroName"
Write-Host "  Location:  $InstallPath"
Write-Host "  User:      $DefaultUser (password: test123)"
Write-Host ""
Write-Host "  IMPORTANT: Restart Windows Terminal to see the new profile!"
Write-Host ""
Write-Host "  To start:" -ForegroundColor Cyan
Write-Host "    wsl -d $DistroName" -ForegroundColor White
Write-Host ""
Write-Host "  To test the infrastructure setup:" -ForegroundColor Cyan
Write-Host "    curl -fsSL https://raw.githubusercontent.com/tobiaswaggoner/init-dev-machine/main/scripts/phase2-setup.sh | bash" -ForegroundColor White
Write-Host ""
Write-Host "  To delete when done:" -ForegroundColor Cyan
Write-Host "    wsl --unregister $DistroName" -ForegroundColor White
Write-Host "    Remove-Item -Recurse $InstallPath" -ForegroundColor White
Write-Host ""
