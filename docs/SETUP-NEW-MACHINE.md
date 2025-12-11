# New Machine Setup Guide

Complete step-by-step guide to set up a development environment from a fresh Windows 11 machine.

**Time required**: ~30-45 minutes
**Admin rights needed**: Only for WSL installation (Step 1)

---

## Prerequisites

- Windows 11 (or Windows 10 version 2004+)
- Local admin rights (only for WSL installation)
- Internet connection
- GitHub account with access to the init-dev-machine repo (or your fork)

---

## Step 1: Install WSL2 with Debian (requires Admin)

This is the **only step** that requires local administrator rights.

### Option A: PowerShell (Recommended)

1. Open **PowerShell as Administrator**
2. Run:
   ```powershell
   wsl --install -d Debian
   ```
3. **Restart your computer** when prompted

### Option B: Manual Installation

If the above doesn't work:

1. Open **PowerShell as Administrator**
2. Enable WSL:
   ```powershell
   dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
   dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
   ```
3. **Restart your computer**
4. Download and install the [WSL2 Linux kernel update](https://aka.ms/wsl2kernel)
5. Set WSL2 as default:
   ```powershell
   wsl --set-default-version 2
   ```
6. Install Debian from Microsoft Store or:
   ```powershell
   wsl --install -d Debian
   ```

### First Launch

After restart, Debian will launch automatically (or search for "Debian" in Start menu):

1. Wait for installation to complete
2. Create your UNIX username (e.g., your first name lowercase)
3. Create a password (can be simple, you'll use `sudo` with it)

**Verify installation**:
```bash
cat /etc/os-release  # Should show Debian
wsl.exe -l -v        # Should show Debian with VERSION 2
```

---

## Step 2: Initial System Update

In your new Debian terminal:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git
```

---

## Step 3: Clone the Infrastructure Repository

### Option A: HTTPS with GitHub Token (Private Repo)

1. **Create a GitHub Personal Access Token**:
   - Go to https://github.com/settings/tokens
   - Click "Generate new token (classic)"
   - Name: `wsl-setup`
   - Scopes: `repo` (full control)
   - Click "Generate token"
   - **Copy the token immediately!**

2. **Clone the repo**:
   ```bash
   mkdir -p ~/src
   cd ~/src
   git clone https://github.com/tobiaswaggoner/init-dev-machine.git infrastructure
   # Username: your-github-username
   # Password: paste-your-token-here
   ```

### Option B: SSH Key

1. **Generate SSH key**:
   ```bash
   ssh-keygen -t ed25519 -C "your-email@example.com"
   # Press Enter for default location
   # Enter passphrase (or leave empty)
   ```

2. **Add key to GitHub**:
   ```bash
   cat ~/.ssh/id_ed25519.pub
   # Copy the output
   ```
   - Go to https://github.com/settings/keys
   - Click "New SSH key"
   - Paste your public key
   - Save

3. **Clone the repo**:
   ```bash
   mkdir -p ~/src
   cd ~/src
   git clone git@github.com:tobiaswaggoner/init-dev-machine.git infrastructure
   ```

---

## Step 4: Run Bootstrap Script

```bash
cd ~/src/infrastructure
chmod +x scripts/bootstrap.sh
./scripts/bootstrap.sh
```

This will install (13 steps):
1. Essential system packages (curl, wget, build-essential, ...)
2. CLI utilities (htop, jq, tree, vim, ...)
3. ZSH shell
4. Oh My Zsh
5. Docker + Docker Compose
6. kubectl
7. k3d
8. Helm + k9s
9. uv (Python)
10. fnm + bun (Node.js)
11. Claude Code CLI
12. Git configuration + aliases
13. GitHub CLI (gh) + GitLab CLI (glab)

**Duration**: ~10-15 minutes depending on internet speed

---

## Step 5: Re-login to Apply Changes

The bootstrap script made changes that require a new session:

```bash
exit
```

Then reopen Debian from Start menu, or in PowerShell:
```powershell
wsl -d Debian
```

**Verify ZSH is active**:
```bash
echo $SHELL  # Should show /usr/bin/zsh
```

---

## Step 6: Configure Git Identity

```bash
git config --global user.name "Your Full Name"
git config --global user.email "your-email@example.com"
```

For work projects, use your work email.

---

## Step 7: Authenticate Claude Code

```bash
claude
```

Follow the prompts to:
1. Open the authentication URL in your browser
2. Log in with your Anthropic account
3. Authorize the CLI

After authentication, the ccstatusline will be active (configured in `~/.claude/settings.json`).

---

## Step 8: Start Docker Service

Docker needs to be started manually in WSL (no systemd by default):

```bash
sudo service docker start
```

**Verify Docker works**:
```bash
docker run hello-world
```

> **Tip**: Add to your shell startup if you want Docker to auto-start:
> ```bash
> echo 'sudo service docker start > /dev/null 2>&1' >> ~/.zshrc
> ```
> (This will prompt for password on first terminal open)

---

## Step 9: Create and Test the Kubernetes Cluster

```bash
cd ~/src/infrastructure
make cluster-up
```

**Verify cluster is running**:
```bash
kubectl get nodes
# Should show: my-dev-server-0 and my-dev-agent-0
```

---

## Step 10: Deploy Infrastructure Services (Optional)

If you need the databases right away:

```bash
make infra-up
```

This deploys:
- PostgreSQL (port 5432)
- MongoDB (port 27017)
- Redis (port 6379)
- Kafka via Strimzi (port 9092)

**Check status**:
```bash
make infra-status
```

---

## Step 11: Configure VS Code (Optional)

If using VS Code on Windows:

1. Install the **Remote - WSL** extension
2. In WSL terminal, navigate to your project and run:
   ```bash
   code .
   ```
3. VS Code will install the server component and open

Recommended extensions for the WSL environment:
- Python
- Pylance
- ESLint
- Prettier
- GitLens
- Kubernetes
- Docker

---

## Step 12: Authenticate Git CLIs (Optional)

### GitHub CLI
```bash
gh auth login
# Select: GitHub.com
# Select: HTTPS
# Authenticate via browser
```

### GitLab CLI
```bash
glab auth login
# Enter your GitLab instance URL (or press Enter for gitlab.com)
# Select: Token
# Paste your Personal Access Token (see GITLAB-SETUP.md)
```

For GitLab token creation, see [GITLAB-SETUP.md](GITLAB-SETUP.md).

---

## Post-Setup Checklist

- [ ] WSL2 with Debian installed
- [ ] Bootstrap script completed
- [ ] ZSH is default shell
- [ ] Git identity configured
- [ ] Claude Code authenticated
- [ ] Docker running
- [ ] k3d cluster created
- [ ] (Optional) Infrastructure services deployed
- [ ] (Optional) VS Code configured
- [ ] (Optional) GitLab access configured

---

## Quick Reference Commands

| Task | Command |
|------|---------|
| Start Docker | `sudo service docker start` |
| Start cluster | `make cluster-up` |
| Stop cluster | `make cluster-down` |
| Reset cluster | `make cluster-reset` |
| Deploy services | `make infra-up` |
| Check pods | `kubectl get pods -A` |
| K8s dashboard | `k9s` |
| Forward PostgreSQL | `make port-forward-postgres` |

---

## Troubleshooting

### WSL won't start
```powershell
# In PowerShell (Admin)
wsl --shutdown
wsl --update
```

### Docker permission denied
```bash
# Add yourself to docker group (should be done by bootstrap)
sudo usermod -aG docker $USER
# Then logout and login again
```

### Cluster won't start
```bash
# Check Docker is running
docker ps

# If not:
sudo service docker start

# Then retry
make cluster-up
```

### "command not found" after bootstrap
```bash
# Reload shell config
source ~/.zshrc

# Or restart terminal
exit
```

### Slow file access in WSL
Store your code in the Linux filesystem (`~/src/`), not in `/mnt/c/`. Windows filesystem access from WSL is significantly slower.

---

## Customizing for Different Clients

This setup is designed to be client-agnostic. To customize for a specific client:

1. **Fork or copy** this repo to a client-specific location
2. **Modify** `k8s/helm/*/values.yaml` for client-specific services
3. **Add** client-specific tools to `scripts/bootstrap.sh`
4. **Update** credentials in `docs/GITLAB-SETUP.md`

The core infrastructure (Docker, k3d, Helm, etc.) remains the same across all clients.

---

## Updating the Environment

To pull updates from the repo:

```bash
cd ~/src/infrastructure
git pull
```

To re-run bootstrap (safe to run multiple times):
```bash
./scripts/bootstrap.sh
```

The script skips already-installed components.
