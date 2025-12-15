#------------------------------------------------------------------------------
# Store Secrets in Windows Credential Manager
# Run once to securely store GitHub/GitLab tokens
# These are encrypted with DPAPI and tied to your Windows user account
#------------------------------------------------------------------------------

param(
    [switch]$Force,      # Overwrite existing credentials
    [switch]$Show,       # Show stored credential names (not values)
    [switch]$Clear       # Remove all WSL-Setup credentials
)

$ErrorActionPreference = "Stop"
$CredentialPrefix = "WSL-Setup"

# Credential Manager functions using cmdkey
function Set-StoredCredential {
    param([string]$Name, [string]$Secret)
    $targetName = "${CredentialPrefix}:${Name}"

    # cmdkey uses /user for the label and /pass for the secret
    $null = cmdkey /generic:$targetName /user:$Name /pass:$Secret 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to store credential: $Name"
    }
}

function Get-StoredCredential {
    param([string]$Name)
    $targetName = "${CredentialPrefix}:${Name}"

    # Check if credential exists
    $result = cmdkey /list:$targetName 2>&1
    return $result -match "Target: $targetName"
}

function Remove-StoredCredential {
    param([string]$Name)
    $targetName = "${CredentialPrefix}:${Name}"
    $null = cmdkey /delete:$targetName 2>&1
}

function Get-AllStoredCredentials {
    $result = cmdkey /list 2>&1
    $creds = $result | Select-String "Target: ${CredentialPrefix}:" | ForEach-Object {
        $_ -replace ".*Target: ${CredentialPrefix}:", ""
    }
    return $creds
}

# Header
Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  WSL Setup - Credential Manager" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# Show mode
if ($Show) {
    Write-Host "Stored credentials:" -ForegroundColor Yellow
    $creds = Get-AllStoredCredentials
    if ($creds) {
        $creds | ForEach-Object { Write-Host "  - $_" -ForegroundColor Green }
    } else {
        Write-Host "  (none)" -ForegroundColor Gray
    }
    Write-Host ""
    exit 0
}

# Clear mode
if ($Clear) {
    Write-Host "Removing all WSL-Setup credentials..." -ForegroundColor Yellow
    $creds = Get-AllStoredCredentials
    if ($creds) {
        $creds | ForEach-Object {
            Remove-StoredCredential -Name $_
            Write-Host "  Removed: $_" -ForegroundColor Gray
        }
        Write-Host "Done!" -ForegroundColor Green
    } else {
        Write-Host "  No credentials found." -ForegroundColor Gray
    }
    Write-Host ""
    exit 0
}

# Store mode (default)
Write-Host "This script stores secrets in Windows Credential Manager." -ForegroundColor Gray
Write-Host "They are encrypted and tied to your Windows account." -ForegroundColor Gray
Write-Host ""

# GitHub Token
Write-Host "[1/3] GitHub Personal Access Token" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Required scopes: repo, admin:public_key" -ForegroundColor Gray
Write-Host "  Create at: https://github.com/settings/tokens/new" -ForegroundColor Gray
Write-Host ""

$hasGitHub = Get-StoredCredential -Name "github-token"
if ($hasGitHub -and -not $Force) {
    Write-Host "  GitHub token already stored. Use -Force to overwrite." -ForegroundColor Green
} else {
    $ghToken = Read-Host "  Enter GitHub PAT (or press Enter to skip)"
    if ($ghToken) {
        Set-StoredCredential -Name "github-token" -Secret $ghToken
        Write-Host "  Stored!" -ForegroundColor Green
    } else {
        Write-Host "  Skipped." -ForegroundColor Gray
    }
}
Write-Host ""

# SSH Private Key (optional)
Write-Host "[2/3] SSH Private Key (optional)" -ForegroundColor Yellow
Write-Host ""
Write-Host "  If you have an existing SSH key for GitHub, you can store it here." -ForegroundColor Gray
Write-Host "  This avoids generating a new key for each WSL instance." -ForegroundColor Gray
Write-Host "  The key will be stored encrypted in Credential Manager." -ForegroundColor Gray
Write-Host ""

$hasSshKey = Get-StoredCredential -Name "ssh-private-key"
if ($hasSshKey -and -not $Force) {
    Write-Host "  SSH key already stored. Use -Force to overwrite." -ForegroundColor Green
} else {
    Write-Host "  Enter path to private key file (e.g., C:\Users\you\.ssh\id_ed25519)" -ForegroundColor Gray
    $sshKeyPath = Read-Host "  Path (or press Enter to skip)"
    if ($sshKeyPath -and (Test-Path $sshKeyPath)) {
        # Read key and encode as base64 (handles multi-line)
        $keyContent = Get-Content $sshKeyPath -Raw
        $keyBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($keyContent))
        Set-StoredCredential -Name "ssh-private-key" -Secret $keyBase64
        Write-Host "  Stored!" -ForegroundColor Green

        # Also store public key if it exists
        $pubKeyPath = "$sshKeyPath.pub"
        if (Test-Path $pubKeyPath) {
            $pubKeyContent = (Get-Content $pubKeyPath -Raw).Trim()
            $pubKeyBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($pubKeyContent))
            Set-StoredCredential -Name "ssh-public-key" -Secret $pubKeyBase64
            Write-Host "  Public key also stored!" -ForegroundColor Green
        }
    } elseif ($sshKeyPath) {
        Write-Host "  File not found: $sshKeyPath" -ForegroundColor Red
    } else {
        Write-Host "  Skipped (will generate new key for each instance)." -ForegroundColor Gray
    }
}
Write-Host ""

# GitLab Token (optional)
Write-Host "[3/3] GitLab Personal Access Token (optional)" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Required scopes: api, write_repository" -ForegroundColor Gray
Write-Host "  Create at: https://gitlab.com/-/user_settings/personal_access_tokens" -ForegroundColor Gray
Write-Host ""

$hasGitLab = Get-StoredCredential -Name "gitlab-token"
if ($hasGitLab -and -not $Force) {
    Write-Host "  GitLab token already stored. Use -Force to overwrite." -ForegroundColor Green
} else {
    $glToken = Read-Host "  Enter GitLab PAT (or press Enter to skip)"
    if ($glToken) {
        Set-StoredCredential -Name "gitlab-token" -Secret $glToken
        Write-Host "  Stored!" -ForegroundColor Green
    } else {
        Write-Host "  Skipped." -ForegroundColor Gray
    }
}
Write-Host ""

# Summary
Write-Host "========================================================" -ForegroundColor Green
Write-Host "  Credentials Stored!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  View stored:   .\store-secrets.ps1 -Show"
Write-Host "  Update:        .\store-secrets.ps1 -Force"
Write-Host "  Clear all:     .\store-secrets.ps1 -Clear"
Write-Host ""
Write-Host "  Next step:     .\setup-wsl.ps1 -ConfigFile ..\config.json"
Write-Host ""
