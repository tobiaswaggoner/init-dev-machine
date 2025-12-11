# New Machine Setup Guide

Complete step-by-step guide to set up a development environment from a fresh Windows 11 machine.

**Time required**: ~30-45 minutes
**Admin rights needed**: Only for WSL installation (Step 1)

---

## Overview

```
┌─────────────────────────────────────────────────────────────┐
│  PHASE 1: Windows (requires Admin)                         │
│  └─> Install WSL2 + Debian                                 │
├─────────────────────────────────────────────────────────────┤
│  PHASE 2: Pre-Bootstrap (manual, copy&paste)               │
│  └─> Install git, create SSH key, clone repo               │
├─────────────────────────────────────────────────────────────┤
│  PHASE 3: Automated Bootstrap                              │
│  └─> Run bootstrap.sh (installs everything else)           │
├─────────────────────────────────────────────────────────────┤
│  PHASE 4: Post-Setup (manual)                              │
│  └─> Configure identity, authenticate CLIs                 │
└─────────────────────────────────────────────────────────────┘
```

---

# Phase 1: Windows Setup (requires Admin)

## Step 1.1: Install WSL2 with Debian

Open **PowerShell as Administrator** and copy-paste:

```powershell
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 1.1: Install WSL2 with Debian (requires Admin)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
wsl --install -d Debian
```

**Restart your computer** when prompted.

### Troubleshooting: If the above doesn't work

Copy-paste this in PowerShell (Admin):

```powershell
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ALTERNATIVE: Manual WSL2 installation
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host "RESTART YOUR COMPUTER NOW" -ForegroundColor Yellow
Write-Host "Then run: wsl --set-default-version 2" -ForegroundColor Yellow
Write-Host "Then run: wsl --install -d Debian" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
```

## Step 1.2: First Debian Launch

After restart, Debian launches automatically (or search "Debian" in Start menu):

1. Wait for "Installing, this may take a few minutes..."
2. **Create UNIX username**: Use your first name lowercase (e.g., `tobias`)
3. **Create password**: Can be simple, you'll use it for `sudo`

### Verify Installation

In the Debian terminal:
```bash
cat /etc/os-release    # Should show Debian
```

In PowerShell:
```powershell
wsl -l -v              # Should show: Debian ... VERSION 2
```

---

# Phase 2: Pre-Bootstrap Setup

These steps prepare your system to clone the infrastructure repo.

## Step 2.1: Install Minimal Prerequisites

Copy and paste this entire block into your Debian terminal:

```bash
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 2.1: Install git and basic tools
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
sudo apt update && sudo apt install -y git curl wget ca-certificates
```

## Step 2.2: Generate SSH Key

Copy and paste (replace email with yours):

```bash
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 2.2: Generate SSH key for GitHub
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ssh-keygen -t ed25519 -C "your-email@example.com" -N "" -f ~/.ssh/id_ed25519
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Copy this PUBLIC KEY and add it to GitHub:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat ~/.ssh/id_ed25519.pub
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

## Step 2.3: Add SSH Key to GitHub

1. Copy the public key output from above
2. Go to: **https://github.com/settings/keys**
3. Click **"New SSH key"**
4. Title: `WSL Debian` (or any name)
5. Paste the key
6. Click **"Add SSH key"**

### Verify GitHub Connection

```bash
ssh -T git@github.com
# Should say: "Hi username! You've successfully authenticated..."
```

## Step 2.4: Clone the Infrastructure Repo

```bash
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 2.4: Clone infrastructure repo
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
mkdir -p ~/src
cd ~/src
git clone git@github.com:tobiaswaggoner/init-dev-machine.git infrastructure
cd infrastructure
```

---

# Phase 3: Automated Bootstrap

## Step 3.1: Run Bootstrap Script

```bash
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 3.1: Run full bootstrap
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
cd ~/src/infrastructure
chmod +x scripts/bootstrap.sh
./scripts/bootstrap.sh
```

This installs (13 steps, ~10-15 min):

| Step | Component |
|------|-----------|
| 1-2 | System packages + CLI tools |
| 3-4 | ZSH + Oh My Zsh |
| 5 | Docker + Docker Compose |
| 6-7 | kubectl + k3d |
| 8 | Helm + k9s |
| 9 | uv (Python) |
| 10 | fnm + bun (Node.js) |
| 11 | Claude Code CLI |
| 12 | Git configuration + aliases |
| 13 | GitHub CLI (gh) + GitLab CLI (glab) |

## Step 3.2: Apply Changes (Re-login)

```bash
exit
```

Reopen Debian from Start menu, then verify:

```bash
echo $SHELL           # Should show /usr/bin/zsh
docker --version      # Should show Docker version
kubectl version --client  # Should show kubectl version
```

---

# Phase 4: Post-Setup Configuration

## Step 4.1: Start Docker

Docker needs to be started manually in WSL:

```bash
sudo service docker start
```

**Optional**: Auto-start Docker on terminal open:
```bash
echo 'sudo service docker start 2>/dev/null' >> ~/.zshrc
```

## Step 4.2: Configure Git Identity

```bash
git config --global user.name "Your Full Name"
git config --global user.email "your-email@example.com"
```

## Step 4.3: Authenticate Claude Code

```bash
claude
# Follow browser authentication prompts
```

## Step 4.4: Authenticate GitHub CLI

```bash
gh auth login
# Select: GitHub.com → HTTPS → Login with browser
```

## Step 4.5: Authenticate GitLab CLI (if needed)

```bash
glab auth login
# Enter GitLab instance URL (or Enter for gitlab.com)
# Select: Token → Paste your Personal Access Token
```

For GitLab token creation, see [GITLAB-SETUP.md](GITLAB-SETUP.md).

## Step 4.6: Create Kubernetes Cluster

```bash
cd ~/src/infrastructure
make cluster-up
kubectl get nodes    # Verify nodes are ready
```

## Step 4.7: Deploy Infrastructure Services (Optional)

```bash
make infra-up        # PostgreSQL, MongoDB, Redis, Kafka
make infra-status    # Check deployment status
```

---

# Quick Setup Script (All of Phase 2)

For experienced users, here's Phase 2 as a single copy-paste block:

```bash
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# COMPLETE PHASE 2: Pre-Bootstrap Setup
# Run this after fresh Debian WSL installation
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Install prerequisites
sudo apt update && sudo apt install -y git curl wget ca-certificates

# Generate SSH key (press Enter for defaults, or customize)
read -p "Enter your email for SSH key: " EMAIL
ssh-keygen -t ed25519 -C "$EMAIL" -N "" -f ~/.ssh/id_ed25519
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Display public key
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ACTION REQUIRED: Add this key to GitHub"
echo "→ https://github.com/settings/keys"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat ~/.ssh/id_ed25519.pub
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
read -p "Press Enter after adding key to GitHub..."

# Test GitHub connection
ssh -T git@github.com

# Clone repo
mkdir -p ~/src
git clone git@github.com:tobiaswaggoner/init-dev-machine.git ~/src/infrastructure

echo ""
echo "✓ Phase 2 complete! Now run:"
echo "  cd ~/src/infrastructure && ./scripts/bootstrap.sh"
```

---

# Post-Setup Checklist

- [ ] WSL2 with Debian installed
- [ ] SSH key added to GitHub
- [ ] Infrastructure repo cloned
- [ ] Bootstrap script completed
- [ ] ZSH is default shell
- [ ] Docker running
- [ ] Git identity configured
- [ ] Claude Code authenticated
- [ ] gh CLI authenticated
- [ ] (Optional) glab CLI authenticated
- [ ] (Optional) k3d cluster created
- [ ] (Optional) Infrastructure services deployed

---

# Quick Reference

| Task | Command |
|------|---------|
| Start Docker | `sudo service docker start` |
| Start cluster | `make cluster-up` |
| Stop cluster | `make cluster-down` |
| Reset cluster | `make cluster-reset` |
| Deploy services | `make infra-up` |
| Check pods | `kubectl get pods -A` |
| K8s dashboard | `k9s` |

---

# Troubleshooting

### Docker permission denied
```bash
sudo usermod -aG docker $USER
# Then logout and login again
```

### "command not found" after bootstrap
```bash
source ~/.zshrc
# Or restart terminal
```

### Cluster won't start
```bash
sudo service docker start
make cluster-up
```

### Slow file access
Store code in Linux filesystem (`~/src/`), not `/mnt/c/`.

---

# Customizing for Different Clients

1. **Fork** this repo to a client-specific location
2. **Modify** `k8s/helm/*/values.yaml` for client services
3. **Update** repo URL in this guide
4. **Add** client-specific tools to `bootstrap.sh`

---

# Updating the Environment

```bash
cd ~/src/infrastructure
git pull
./scripts/bootstrap.sh   # Safe to re-run
```
