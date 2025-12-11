#------------------------------------------------------------------------------
# Create Test WSL Instance for Infrastructure Setup Testing
# Run in PowerShell (no Admin required)
#------------------------------------------------------------------------------

$ErrorActionPreference = "Stop"

# Configuration
$DistroName = "Debian-Test"
$InstallPath = "$env:USERPROFILE\wsl\debian-test"
$TarballPath = "$env:USERPROFILE\wsl\installer\debian.install.tar.gz"
$DefaultUser = "testuser"

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  Creating Test WSL Instance: $DistroName" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
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

# Create setup script without heredoc to avoid CRLF issues
$setupScript = @"
apt-get update -qq 2>/dev/null
apt-get install -y -qq sudo 2>/dev/null
useradd -m -s /bin/bash $DefaultUser 2>/dev/null || true
echo '$DefaultUser`:test123' | chpasswd
usermod -aG sudo $DefaultUser 2>/dev/null || true
echo '$DefaultUser ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$DefaultUser
echo '[user]' > /etc/wsl.conf
echo 'default=$DefaultUser' >> /etc/wsl.conf
echo '' >> /etc/wsl.conf
echo '[boot]' >> /etc/wsl.conf
echo 'systemd=true' >> /etc/wsl.conf
echo 'User setup complete'
"@

# Write script to temp file and execute (avoids CRLF issues)
$tempScript = [System.IO.Path]::GetTempFileName()
$setupScript | Out-File -FilePath $tempScript -Encoding ASCII -NoNewline
$setupScript -replace "`r`n", "`n" | Set-Content -Path $tempScript -NoNewline

wsl -d $DistroName -u root -- bash -c "cat /dev/stdin | tr -d '\r' | bash" < $tempScript
Remove-Item $tempScript

Write-Host "  User '$DefaultUser' created (password: test123)" -ForegroundColor Green

# Step 5: Add Windows Terminal profile
Write-Host "[5/5] Configuring Windows Terminal profile..." -ForegroundColor Yellow

$terminalSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

if (Test-Path $terminalSettingsPath) {
    $settingsContent = Get-Content $terminalSettingsPath -Raw
    $settings = $settingsContent | ConvertFrom-Json

    # Generate a new GUID
    $newGuid = "{$([guid]::NewGuid().ToString())}"

    # Check if our custom profile already exists
    $existingCustomProfile = $settings.profiles.list | Where-Object { $_.name -eq "Debian Test" -and $_.commandline -eq "wsl.exe -d $DistroName" }

    # Find and hide the auto-generated WSL profile
    $autoProfile = $settings.profiles.list | Where-Object { $_.name -eq $DistroName -and $_.source -eq "Windows.Terminal.Wsl" }
    if (-not $autoProfile) {
        $autoProfile = $settings.profiles.list | Where-Object { $_.name -eq $DistroName -and $_.source -eq "Microsoft.WSL" }
    }

    if ($autoProfile) {
        $autoProfile | Add-Member -NotePropertyName "hidden" -NotePropertyValue $true -Force
        Write-Host "  Hidden auto-generated profile for '$DistroName'" -ForegroundColor Gray
    }

    if (-not $existingCustomProfile) {
        # Create new profile
        $newProfile = [PSCustomObject]@{
            name = "Debian Test"
            guid = $newGuid
            commandline = "wsl.exe -d $DistroName"
            background = "#330000"
            tabTitle = "TEST"
            suppressApplicationTitle = $true
        }

        # Convert to array if needed and add profile
        $profileList = [System.Collections.ArrayList]@($settings.profiles.list)
        $profileList.Add($newProfile) | Out-Null
        $settings.profiles.list = $profileList.ToArray()

        Write-Host "  Added custom profile 'Debian Test'" -ForegroundColor Green
    } else {
        Write-Host "  Profile 'Debian Test' already exists" -ForegroundColor Yellow
    }

    # Save settings with UTF-8 encoding
    $settings | ConvertTo-Json -Depth 100 | Set-Content $terminalSettingsPath -Encoding UTF8

} else {
    Write-Host "  Windows Terminal not found - manual profile setup needed" -ForegroundColor Yellow
}

# Terminate WSL to apply wsl.conf changes
Write-Host ""
Write-Host "Applying WSL configuration..." -ForegroundColor Yellow
wsl --terminate $DistroName 2>$null

# Done
Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "  Test Instance Ready!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Instance:  $DistroName"
Write-Host "  Location:  $InstallPath"
Write-Host "  User:      $DefaultUser (password: test123)"
Write-Host ""
Write-Host "  IMPORTANT: Restart Windows Terminal to see the new profile!" -ForegroundColor Yellow
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
