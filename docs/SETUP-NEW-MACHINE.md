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
│  PHASE 2: Pre-Bootstrap (interactive script)               │
│  └─> Install git, create SSH key, clone repo               │
├─────────────────────────────────────────────────────────────┤
│  PHASE 3: Automated Bootstrap                              │
│  └─> Run bootstrap.sh (installs everything else)           │
├─────────────────────────────────────────────────────────────┤
│  PHASE 4: Post-Setup (manual)                              │
│  └─> Authenticate CLIs, create cluster                     │
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

# Phase 2: Pre-Bootstrap Setup (Interactive Script)

This interactive script prepares your system to clone the infrastructure repo.
**No manual editing required** - all values are prompted interactively.

## Step 2.1: Run the Pre-Bootstrap Script

**Copy-paste the entire script below** into your Debian terminal:

```bash
#!/bin/bash
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE 2: Pre-Bootstrap Setup
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
set -e

CONFIG_DIR="$HOME/.config/dev-setup"
CONFIG_FILE="$CONFIG_DIR/config"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Phase 2: Pre-Bootstrap Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Install prerequisites
echo "[1/5] Installing prerequisites..."
sudo apt update && sudo apt install -y git curl wget ca-certificates
echo ""

# Step 2: Collect configuration
echo "[2/5] Collecting your configuration..."
echo ""

if [ -f "$CONFIG_FILE" ]; then
    echo "Found existing configuration:"
    cat "$CONFIG_FILE"
    echo ""
    read -p "Use existing config? [Y/n]: " USE_EXISTING
    if [[ "$USE_EXISTING" =~ ^[Nn] ]]; then
        rm "$CONFIG_FILE"
    fi
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Please enter your details:"
    echo ""
    read -p "  Your full name (for Git): " DEV_NAME
    read -p "  Your email (for Git & SSH key): " DEV_EMAIL
    read -p "  GitHub username [tobiaswaggoner]: " GITHUB_USER
    GITHUB_USER=${GITHUB_USER:-tobiaswaggoner}

    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" << CONF
DEV_NAME="$DEV_NAME"
DEV_EMAIL="$DEV_EMAIL"
GITHUB_USER="$GITHUB_USER"
CONF
    echo "Configuration saved to $CONFIG_FILE"
fi

source "$CONFIG_FILE"
echo ""

# Step 3: Generate SSH key
echo "[3/5] Setting up SSH key..."

if [ -f "$HOME/.ssh/id_ed25519" ]; then
    echo "SSH key already exists at ~/.ssh/id_ed25519"
else
    ssh-keygen -t ed25519 -C "$DEV_EMAIL" -N "" -f "$HOME/.ssh/id_ed25519"
    echo "SSH key generated"
fi

eval "$(ssh-agent -s)" > /dev/null
ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ACTION REQUIRED: Add this SSH key to GitHub"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Copy the key below"
echo "2. Go to: https://github.com/settings/keys"
echo "3. Click 'New SSH key', paste and save"
echo ""
echo "━━━━━━━━━━━━ YOUR PUBLIC KEY ━━━━━━━━━━━━"
cat "$HOME/.ssh/id_ed25519.pub"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
read -p "Press Enter after adding the key to GitHub..."

# Step 4: Test GitHub connection
echo "[4/5] Testing GitHub connection..."
ssh -T git@github.com 2>&1 | grep -q "successfully authenticated" && echo "GitHub connection successful!" || ssh -T git@github.com || true
echo ""

# Step 5: Clone repository
echo "[5/5] Cloning infrastructure repository..."

REPO_URL="git@github.com:${GITHUB_USER}/init-dev-machine.git"
REPO_DIR="$HOME/src/infrastructure"

if [ -d "$REPO_DIR" ]; then
    echo "Repository already exists at $REPO_DIR"
    cd "$REPO_DIR" && git pull || true
else
    mkdir -p "$HOME/src"
    git clone "$REPO_URL" "$REPO_DIR"
    cd "$REPO_DIR"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Phase 2 Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next step:"
echo "  cd ~/src/infrastructure && ./scripts/bootstrap.sh"
echo ""
```

The script will:
1. Install minimal prerequisites (git, curl, wget)
2. Ask for your name, email, and GitHub username
3. Generate an SSH key for GitHub
4. Display the public key for you to add to GitHub
5. Wait for you to add the key, then verify the connection
6. Clone the infrastructure repository

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

## Step 3.2: Restart WSL (for systemd)

The bootstrap script enables systemd in WSL. To apply this:

**In PowerShell** (not Debian):
```powershell
wsl --shutdown
```

Then reopen Debian from Start menu.

## Step 3.3: Verify Installation

After reopening Debian, verify:

```bash
echo $SHELL           # Should show /usr/bin/zsh
docker --version      # Should show Docker version
kubectl version --client  # Should show kubectl version
```

---

# Phase 4: Post-Setup Configuration

## Step 4.1: Verify Docker (systemd)

With systemd enabled, Docker should auto-start. Verify:

```bash
docker ps   # Should work without errors
```

If Docker is not running:
```bash
sudo systemctl start docker
sudo systemctl enable docker   # Enable auto-start
```

## Step 4.2: Verify Git Identity

Git identity was configured automatically from Phase 2. Verify:

```bash
git config --global user.name   # Should show your name
git config --global user.email  # Should show your email
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

# Quick Setup (Experienced Users)

Both Phase 2 and Phase 3 are now single-command copy-paste scripts:

**Phase 2** (Pre-Bootstrap - fresh Debian):
```bash
curl -fsSL https://raw.githubusercontent.com/tobiaswaggoner/init-dev-machine/main/scripts/phase2-setup.sh | bash
```

**Phase 3** (Bootstrap - after Phase 2):
```bash
cd ~/src/infrastructure && ./scripts/bootstrap.sh
```

All configuration values are collected interactively - no manual editing required.

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
| Start Docker | `sudo systemctl start docker` |
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
sudo systemctl start docker
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
