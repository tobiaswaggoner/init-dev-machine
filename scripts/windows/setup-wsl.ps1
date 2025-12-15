#------------------------------------------------------------------------------
# Headless WSL Development Environment Setup
# Creates a fully configured WSL instance from a config file
#------------------------------------------------------------------------------

param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigFile,

    [switch]$Force,           # Delete existing instance if present
    [switch]$SkipBootstrap,   # Skip running bootstrap.sh
    [switch]$SkipClone,       # Skip repo cloning (for testing)
    [switch]$ShowErrors       # Show detailed error output
)

$ErrorActionPreference = "Stop"
$CredentialPrefix = "WSL-Setup"

#------------------------------------------------------------------------------
# Helper Functions
#------------------------------------------------------------------------------

function Write-Step {
    param([string]$Step, [string]$Message)
    Write-Host "[$Step] $Message" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host "  $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "  $Message" -ForegroundColor Gray
}

function Expand-EnvVars {
    param([string]$Path)
    return [Environment]::ExpandEnvironmentVariables($Path.Replace('%USERPROFILE%', $env:USERPROFILE))
}

# Read credential from Windows Credential Manager using .NET
function Get-StoredSecret {
    param([string]$Name)

    $targetName = "${CredentialPrefix}:${Name}"

    # Use PowerShell to query cmdkey and extract from the vault
    # Since cmdkey doesn't expose passwords, we use a different approach:
    # Store in a way we can retrieve using .NET CredentialManager

    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class CredentialManager {
    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool CredRead(string target, int type, int flags, out IntPtr credential);

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool CredFree(IntPtr credential);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CREDENTIAL {
        public int Flags;
        public int Type;
        public string TargetName;
        public string Comment;
        public long LastWritten;
        public int CredentialBlobSize;
        public IntPtr CredentialBlob;
        public int Persist;
        public int AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }

    public static string GetCredential(string target) {
        IntPtr credPtr;
        if (CredRead(target, 1, 0, out credPtr)) {
            try {
                CREDENTIAL cred = (CREDENTIAL)Marshal.PtrToStructure(credPtr, typeof(CREDENTIAL));
                if (cred.CredentialBlobSize > 0) {
                    return Marshal.PtrToStringUni(cred.CredentialBlob, cred.CredentialBlobSize / 2);
                }
            } finally {
                CredFree(credPtr);
            }
        }
        return null;
    }
}
"@ -ErrorAction SilentlyContinue

    return [CredentialManager]::GetCredential($targetName)
}

# Run command in WSL instance
function Invoke-WslCommand {
    param(
        [string]$DistroName,
        [string]$Command,
        [string]$User = "root",
        [switch]$PassThru
    )

    $prevErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"

    if ($PassThru) {
        $output = wsl -d $DistroName -u $User -- bash -c $Command 2>&1
    } else {
        $output = wsl -d $DistroName -u $User -- bash -c $Command 2>&1
    }
    $exitCode = $LASTEXITCODE

    $ErrorActionPreference = $prevErrorAction

    if ($exitCode -ne 0 -and -not $PassThru) {
        Write-Host "  ERROR: Command failed (exit $exitCode)" -ForegroundColor Red
        Write-Host "  Command: $Command" -ForegroundColor Red
        if ($ShowErrors) {
            Write-Host "  Output: $output" -ForegroundColor Red
        }
        throw "WSL command failed"
    }

    if ($PassThru) {
        return $output
    }
}

# Upload SSH key to GitHub via API
function Add-GitHubSshKey {
    param(
        [string]$Token,
        [string]$KeyTitle,
        [string]$PublicKey
    )

    $headers = @{
        "Authorization" = "Bearer $Token"
        "Accept" = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }

    $body = @{
        title = $KeyTitle
        key = $PublicKey
    } | ConvertTo-Json

    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/user/keys" -Method Post -Headers $headers -Body $body -ContentType "application/json"
        return $true
    } catch {
        if ($_.Exception.Response.StatusCode -eq 422) {
            # Key already exists
            return $true
        }
        Write-Host "  Error uploading SSH key: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

#------------------------------------------------------------------------------
# Main Script
#------------------------------------------------------------------------------

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  WSL Development Environment - Headless Setup" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Load and validate config
Write-Step "1/9" "Loading configuration..."

if (-not (Test-Path $ConfigFile)) {
    throw "Config file not found: $ConfigFile"
}

$config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
Write-Success "Loaded: $ConfigFile"

# Expand environment variables in paths
$distroName = $config.wsl.distro_name
$installPath = Expand-EnvVars $config.wsl.install_path
$tarballPath = Expand-EnvVars $config.wsl.tarball_path
$defaultUser = $config.wsl.default_user
$defaultPassword = if ($config.wsl.default_password) { $config.wsl.default_password } else { "password" }

Write-Info "Distro: $distroName"
Write-Info "User: $defaultUser"

# Step 2: Verify tarball
Write-Step "2/9" "Verifying tarball..."

if (-not (Test-Path $tarballPath)) {
    throw "Tarball not found: $tarballPath"
}
Write-Success "Found: $tarballPath"

# Step 3: Load secrets from Credential Manager
Write-Step "3/9" "Loading secrets from Credential Manager..."

$githubToken = Get-StoredSecret -Name "github-token"
$gitlabToken = Get-StoredSecret -Name "gitlab-token"

if (-not $githubToken) {
    throw "GitHub token not found. Run: .\store-secrets.ps1"
}
Write-Success "GitHub token loaded"

if ($gitlabToken) {
    Write-Success "GitLab token loaded"
} else {
    Write-Info "GitLab token not set (optional)"
}

# Step 4: Handle existing instance
Write-Step "4/9" "Checking for existing instance..."

$existingDistros = wsl --list --quiet 2>$null
if ($existingDistros -contains $distroName) {
    if ($Force) {
        Write-Info "Removing existing instance..."
        wsl --unregister $distroName 2>$null
        if (Test-Path $installPath) {
            Remove-Item -Recurse -Force $installPath
        }
        Write-Success "Removed: $distroName"
    } else {
        throw "Instance '$distroName' already exists. Use -Force to recreate."
    }
} else {
    Write-Success "No existing instance"
}

# Step 5: Import WSL instance
Write-Step "5/9" "Importing WSL instance..."

if (-not (Test-Path $installPath)) {
    New-Item -ItemType Directory -Path $installPath -Force | Out-Null
}

wsl --import $distroName $installPath $tarballPath
if ($LASTEXITCODE -ne 0) {
    throw "Failed to import WSL instance"
}
Write-Success "Imported: $distroName"

# Step 6: Configure user and system
Write-Step "6/9" "Configuring user and system..."

# Fix apt sources, install essentials
Invoke-WslCommand -DistroName $distroName -Command "sed -i '/bullseye-backports/d' /etc/apt/sources.list 2>/dev/null || true"
Invoke-WslCommand -DistroName $distroName -Command "apt-get update -qq"
Invoke-WslCommand -DistroName $distroName -Command "apt-get install -y -qq sudo git curl wget ca-certificates"

# Create user
Invoke-WslCommand -DistroName $distroName -Command "id $defaultUser >/dev/null 2>&1 || useradd -m -s /bin/bash $defaultUser"
Invoke-WslCommand -DistroName $distroName -Command "echo '${defaultUser}:${defaultPassword}' | chpasswd"
Invoke-WslCommand -DistroName $distroName -Command "usermod -aG sudo $defaultUser"
Invoke-WslCommand -DistroName $distroName -Command "echo '$defaultUser ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$defaultUser"

# Configure wsl.conf
$wslConf = "[user]`ndefault=$defaultUser`n`n[boot]`nsystemd=true`n`n[interop]`nenabled=true`nappendWindowsPath=true"
Invoke-WslCommand -DistroName $distroName -Command "printf '$wslConf' > /etc/wsl.conf"

Write-Success "User '$defaultUser' created"

# Step 7: Setup SSH key and GitHub
Write-Step "7/9" "Setting up SSH key and GitHub..."

$sshKeyPath = "/home/$defaultUser/.ssh/id_ed25519"
$userEmail = $config.user.email

# Create .ssh directory
Invoke-WslCommand -DistroName $distroName -User $defaultUser -Command "mkdir -p ~/.ssh && chmod 700 ~/.ssh"

# Check if we have a stored SSH key
$storedPrivateKey = Get-StoredSecret -Name "ssh-private-key"
$storedPublicKey = Get-StoredSecret -Name "ssh-public-key"

if ($storedPrivateKey -and $storedPublicKey) {
    # Use stored SSH key
    Write-Info "Using stored SSH key from Credential Manager..."

    # Decode from base64
    $privateKeyContent = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($storedPrivateKey))
    $publicKeyContent = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($storedPublicKey))

    # Write keys to WSL (use printf to handle newlines properly)
    $privateKeyEscaped = $privateKeyContent -replace "`r`n", "`n" -replace "'", "'\\''"
    $publicKeyEscaped = $publicKeyContent -replace "`r`n", "`n" -replace "'", "'\\''"

    # Write private key
    Invoke-WslCommand -DistroName $distroName -User $defaultUser -Command "cat > $sshKeyPath << 'SSHKEY'
$privateKeyContent
SSHKEY"
    Invoke-WslCommand -DistroName $distroName -User $defaultUser -Command "chmod 600 $sshKeyPath"

    # Write public key
    Invoke-WslCommand -DistroName $distroName -User $defaultUser -Command "cat > ${sshKeyPath}.pub << 'SSHKEY'
$publicKeyContent
SSHKEY"
    Invoke-WslCommand -DistroName $distroName -User $defaultUser -Command "chmod 644 ${sshKeyPath}.pub"

    Write-Success "SSH key restored from Credential Manager"
    Write-Info "(Key should already be registered with GitHub)"

} else {
    # Generate new SSH key
    Write-Info "Generating new SSH key..."

    Invoke-WslCommand -DistroName $distroName -User $defaultUser -Command "ssh-keygen -t ed25519 -C '$userEmail' -N '' -f $sshKeyPath -q"
    Invoke-WslCommand -DistroName $distroName -User $defaultUser -Command "chmod 600 $sshKeyPath && chmod 644 ${sshKeyPath}.pub"

    # Get public key
    $publicKey = Invoke-WslCommand -DistroName $distroName -User $defaultUser -Command "cat ${sshKeyPath}.pub" -PassThru
    $publicKey = ($publicKey | Out-String).Trim()

    Write-Success "SSH key generated"

    # Upload to GitHub
    $keyTitle = "WSL-$distroName-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $uploaded = Add-GitHubSshKey -Token $githubToken -KeyTitle $keyTitle -PublicKey $publicKey

    if ($uploaded) {
        Write-Success "SSH key uploaded to GitHub"
    } else {
        Write-Host "  WARNING: Could not upload SSH key. You may need to add it manually." -ForegroundColor Yellow
    }
}

# Configure SSH for GitHub
Invoke-WslCommand -DistroName $distroName -User $defaultUser -Command "echo 'Host github.com`n  StrictHostKeyChecking accept-new' >> ~/.ssh/config"

# Step 8: Clone repo and save config
Write-Step "8/9" "Cloning repository..."

if (-not $SkipClone) {
    # Save dev config for bootstrap
    $configDir = "/home/$defaultUser/.config/dev-setup"
    $userName = $config.user.name
    $userEmail = $config.user.email
    $githubUser = $config.github.username

    Invoke-WslCommand -DistroName $distroName -User $defaultUser -Command "mkdir -p $configDir"

    # Registry config (defaults if not specified)
    $registryMode = if ($config.registry.mode) { $config.registry.mode } else { "local" }
    $registryHost = if ($config.registry.host) { $config.registry.host } else { "localhost" }
    $dockerPort = if ($config.registry.docker_port) { $config.registry.docker_port } else { 5000 }
    $quayPort = if ($config.registry.quay_port) { $config.registry.quay_port } else { 5001 }

    # Write config file using heredoc to avoid escaping issues with spaces and quotes
    $configContent = @"
DEV_NAME="$userName"
DEV_EMAIL="$userEmail"
GITHUB_USER="$githubUser"

# Registry configuration (for k3d image caching)
REGISTRY_MODE="$registryMode"
REGISTRY_HOST="$registryHost"
DOCKER_REGISTRY_PORT="$dockerPort"
QUAY_REGISTRY_PORT="$quayPort"
"@
    # Write via stdin to avoid shell escaping issues
    $configContent | wsl -d $distroName -u $defaultUser -- tee "$configDir/config" > $null

    # Clone repo
    $repoUrl = "git@github.com:$($config.github.repo).git"
    $repoDir = "/home/$defaultUser/src/infrastructure"

    # Clone with SSH (key has no passphrase, so no agent needed)
    Invoke-WslCommand -DistroName $distroName -User $defaultUser -Command "mkdir -p ~/src && GIT_SSH_COMMAND='ssh -i $sshKeyPath -o StrictHostKeyChecking=accept-new' git clone $repoUrl $repoDir"

    Write-Success "Repository cloned"
} else {
    Write-Info "Skipped (--SkipClone)"
}

# Step 9: Run bootstrap
Write-Step "9/9" "Running bootstrap..."

if (-not $SkipBootstrap -and -not $SkipClone) {
    # Terminate and restart to enable systemd before bootstrap
    Write-Info "Restarting instance for systemd..."
    wsl --terminate $distroName
    Start-Sleep -Seconds 2

    # Run bootstrap
    Write-Info "Running bootstrap.sh (this takes ~10-15 minutes)..."
    $bootstrapCmd = "cd ~/src/infrastructure && chmod +x scripts/bootstrap.sh && ./scripts/bootstrap.sh"

    # Run bootstrap - output will be visible
    wsl -d $distroName -u $defaultUser -- bash -c $bootstrapCmd

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  WARNING: Bootstrap may have encountered issues" -ForegroundColor Yellow
    } else {
        Write-Success "Bootstrap completed"
    }

    # Configure gh CLI with token
    Write-Info "Configuring GitHub CLI..."
    Invoke-WslCommand -DistroName $distroName -User $defaultUser -Command "echo '$githubToken' | /usr/bin/gh auth login --with-token 2>/dev/null || true"

    # Configure glab if token exists
    if ($gitlabToken -and $config.gitlab.host) {
        Write-Info "Configuring GitLab CLI..."
        $glHost = $config.gitlab.host
        Invoke-WslCommand -DistroName $distroName -User $defaultUser -Command "echo '$gitlabToken' | /usr/local/bin/glab auth login --hostname $glHost --stdin 2>/dev/null || true"
    }
} else {
    Write-Info "Skipped (--SkipBootstrap)"
}

# Terminate to apply all changes
wsl --terminate $distroName

# Done!
Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Instance:  $distroName" -ForegroundColor White
Write-Host "  User:      $defaultUser" -ForegroundColor White
Write-Host "  Location:  $installPath" -ForegroundColor White
Write-Host ""
Write-Host "  Start:     wsl -d $distroName" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Remaining manual steps:" -ForegroundColor Yellow
Write-Host "    1. Run 'claude' and authenticate via browser" -ForegroundColor White
Write-Host "    2. (Optional) Run 'make cluster-up' to create k8s cluster" -ForegroundColor White
Write-Host ""
