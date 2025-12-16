# Headless WSL Setup

Fully automated WSL development environment setup. Create, destroy, and recreate your dev environment in one command.

## Overview

```
┌─────────────────────────────────────────────────────────────────┐
│  One-Time Setup                                                 │
│  ├── 1. Create config.json from template                        │
│  └── 2. Store secrets (GitHub PAT) in Credential Manager        │
├─────────────────────────────────────────────────────────────────┤
│  Repeatable (run anytime)                                       │
│  └── setup-wsl.ps1 -ConfigFile config.json [-Force]             │
│       ├── Import WSL from tarball                               │
│       ├── Create user + SSH key                                 │
│       ├── Upload SSH key to GitHub (API)                        │
│       ├── Clone repo                                            │
│       ├── Run bootstrap.sh                                      │
│       └── Configure gh/glab CLI                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- Windows 11 with WSL2 enabled
- Debian tarball at `%USERPROFILE%\wsl\installer\debian.install.tar.gz`
- GitHub Personal Access Token with scopes: `repo`, `admin:public_key`

## Quick Start

### 1. Create Config File

```powershell
cd C:\path\to\init-dev-machine
Copy-Item config.example.json config.json
# Edit config.json with your details
```

### 2. Store Secrets (One-Time)

```powershell
.\scripts\windows\store-secrets.ps1
# Enter your GitHub PAT when prompted
```

Secrets are stored encrypted in Windows Credential Manager, tied to your Windows account.

### 3. Create WSL Instance

```powershell
.\scripts\windows\setup-wsl.ps1 -ConfigFile .\config.json
```

This takes ~15-20 minutes and runs fully unattended.

### 4. Final Manual Step

```bash
# In WSL
claude
# Authenticate via browser (only step that can't be automated)
```

## Commands Reference

### Create New Instance

```powershell
# First time
.\scripts\windows\setup-wsl.ps1 -ConfigFile .\config.json

# Recreate (delete existing first)
.\scripts\windows\setup-wsl.ps1 -ConfigFile .\config.json -Force
```

### Remove Instance

```powershell
# Interactive (asks for confirmation)
.\scripts\windows\remove-wsl.ps1 -ConfigFile .\config.json

# Force (no confirmation)
.\scripts\windows\remove-wsl.ps1 -ConfigFile .\config.json -Force
```

### Manage Secrets

```powershell
# Store/update secrets
.\scripts\windows\store-secrets.ps1

# View stored credential names
.\scripts\windows\store-secrets.ps1 -Show

# Update existing secrets
.\scripts\windows\store-secrets.ps1 -Force

# Remove all secrets
.\scripts\windows\store-secrets.ps1 -Clear
```

## Config File Reference

```json
{
  "user": {
    "name": "Your Full Name",
    "email": "your.email@example.com"
  },
  "github": {
    "username": "your-github-username",
    "repo": "your-username/init-dev-machine"
  },
  "gitlab": {
    "host": "gitlab.com",
    "username": ""
  },
  "wsl": {
    "distro_name": "Debian-Dev",
    "install_path": "%USERPROFILE%\\wsl\\debian-dev",
    "tarball_path": "%USERPROFILE%\\wsl\\installer\\debian.install.tar.gz",
    "default_user": "devuser",
    "default_password": "password"
  },
  "registry": {
    "mode": "none",
    "host": "",
    "docker_port": 5000,
    "quay_port": 5001
  },
  "options": {
    "install_node_lts": true,
    "create_k8s_cluster": false,
    "deploy_infra_services": false
  }
}
```

### Config Fields

| Field | Description |
|-------|-------------|
| `user.name` | Your full name (for Git commits) |
| `user.email` | Your email (for Git and SSH key) |
| `github.username` | Your GitHub username |
| `github.repo` | Repository to clone (format: `user/repo`) |
| `wsl.distro_name` | Name of the WSL distribution |
| `wsl.install_path` | Where to store the WSL vhdx file |
| `wsl.tarball_path` | Path to Debian tarball for import |
| `wsl.default_user` | Linux username to create |
| `wsl.default_password` | Password for the Linux user (for sudo) |
| `registry.mode` | `none` (no cache), `local` (WSL containers), or `remote` (network server) |
| `registry.host` | IP/hostname for remote registry (empty for local) |
| `registry.docker_port` | Port for docker.io cache (default: 5000) |
| `registry.quay_port` | Port for quay.io cache (default: 5001) |

## Security

### Credential Storage

Secrets are stored in Windows Credential Manager using DPAPI encryption:
- Encrypted with your Windows user credentials
- Only accessible when logged in as that user
- Survives reboots
- Not accessible by other users on the machine

### GitHub Token Scopes

Minimum required scopes:
- `repo` - Clone private repositories
- `admin:public_key` - Upload SSH keys

### What Gets Stored Where

| Data | Location | Encrypted |
|------|----------|-----------|
| Name, Email, Username | `config.json` | No (not sensitive) |
| GitHub PAT | Credential Manager | Yes (DPAPI) |
| GitLab PAT | Credential Manager | Yes (DPAPI) |
| SSH Private Key | Credential Manager (optional) | Yes (DPAPI) |
| SSH Private Key | WSL `~/.ssh/` | No (copied or generated) |

### SSH Key Handling

Two modes:

1. **Stored key** (recommended for frequent recreates):
   - Run `store-secrets.ps1` and provide path to existing SSH key
   - Key is stored encrypted in Credential Manager
   - Same key is restored to each new WSL instance
   - No new keys accumulate in your GitHub account

2. **Generated key** (default):
   - New key generated for each WSL instance
   - Automatically uploaded to GitHub via API
   - Old keys accumulate (clean up manually in GitHub settings)

## Troubleshooting

### "GitHub token not found"

```powershell
.\scripts\windows\store-secrets.ps1
# Enter your GitHub PAT
```

### "Tarball not found"

Ensure you have a Debian tarball at the path specified in config.json.

To create one from an existing WSL instance:
```powershell
wsl --export Debian $env:USERPROFILE\wsl\installer\debian.install.tar.gz
```

### "Instance already exists"

Use `-Force` to delete and recreate:
```powershell
.\scripts\windows\setup-wsl.ps1 -ConfigFile .\config.json -Force
```

### SSH key not accepted by GitHub

Check that your GitHub PAT has the `admin:public_key` scope. Create a new token at:
https://github.com/settings/tokens/new

### Bootstrap fails

Run bootstrap manually to see detailed errors:
```bash
wsl -d Debian-Dev
cd ~/src/infrastructure
./scripts/bootstrap.sh
```

## Workflow Examples

### Daily Development

```powershell
# Start your dev environment
wsl -d Debian-Dev
```

### Fresh Start (Keep Secrets)

```powershell
# Nuke and recreate - takes ~15 min
.\scripts\windows\remove-wsl.ps1 -ConfigFile .\config.json -Force
.\scripts\windows\setup-wsl.ps1 -ConfigFile .\config.json
```

### Complete Reset (New Tokens)

```powershell
# Clear old secrets
.\scripts\windows\store-secrets.ps1 -Clear

# Store new secrets
.\scripts\windows\store-secrets.ps1

# Recreate instance
.\scripts\windows\setup-wsl.ps1 -ConfigFile .\config.json -Force
```

### Testing Bootstrap Changes

```powershell
# Quick iteration on bootstrap.sh changes
.\scripts\windows\remove-wsl.ps1 -ConfigFile .\config.json -Force
.\scripts\windows\setup-wsl.ps1 -ConfigFile .\config.json
```

## Network Registry (Optional)

For faster WSL resets, run a pull-through cache registry on a network server. This caches Docker/Quay images and survives WSL instance destruction.

### Server Setup (run once on your server)

```bash
# On your always-on Linux server
mkdir -p /opt/registry-cache/{docker,quay}

# docker.io cache (port 5000)
docker run -d \
  --name registry-docker \
  --restart=always \
  -p 5000:5000 \
  -v /opt/registry-cache/docker:/var/lib/registry \
  -e REGISTRY_PROXY_REMOTEURL=https://registry-1.docker.io \
  registry:2

# quay.io cache (port 5001)
docker run -d \
  --name registry-quay \
  --restart=always \
  -p 5001:5000 \
  -v /opt/registry-cache/quay:/var/lib/registry \
  -e REGISTRY_PROXY_REMOTEURL=https://quay.io \
  registry:2
```

### Client Config

In your `config.json`:

```json
{
  "registry": {
    "mode": "remote",
    "host": "192.168.1.100",
    "docker_port": 5000,
    "quay_port": 5001
  }
}
```

After the first WSL setup, subsequent resets will pull images from your local cache instead of the internet.
