#!/bin/bash
# Bootstrap script for WSL Debian development environment
# Installs all required development tools
#
# Prerequisites (installed in Phase 2 of setup):
#   - git, curl, wget (for cloning this repo)
#   - SSH key added to GitHub
#
# Usage: ./scripts/bootstrap.sh
#
# Safe to re-run - skips already installed components
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# =============================================================================
# Helper: Check if a command exists as a native Linux binary
# This avoids false positives from Windows binaries exposed via WSL interop
# (e.g., /mnt/c/Program Files/Docker/Docker/resources/bin/docker)
# =============================================================================
is_native_linux_command() {
    local cmd="$1"
    local cmd_path
    cmd_path=$(command -v "$cmd" 2>/dev/null) || return 1

    # Reject if path starts with /mnt/ (Windows path)
    if [[ "$cmd_path" == /mnt/* ]]; then
        return 1
    fi

    return 0
}

echo "=========================================="
echo "WSL Development Environment Setup"
echo "=========================================="
echo ""

# Check if running on Debian/Ubuntu
if [ ! -f /etc/debian_version ]; then
    echo "Error: This script is designed for Debian-based systems"
    exit 1
fi

# =============================================================================
# Load configuration from Phase 2
# =============================================================================
CONFIG_FILE="$HOME/.config/dev-setup/config"
if [ -f "$CONFIG_FILE" ]; then
    # Export variables so they're available in subshells
    set -a
    source "$CONFIG_FILE"
    set +a
    if [ -n "$DEV_NAME" ] && [ -n "$DEV_EMAIL" ]; then
        echo "Loaded configuration for: $DEV_NAME <$DEV_EMAIL>"
    else
        echo "Warning: Config file exists but DEV_NAME/DEV_EMAIL not set"
        echo "Config contents:"
        cat "$CONFIG_FILE"
    fi
    echo ""
else
    echo "Warning: No configuration found at $CONFIG_FILE"
    echo "Git identity will need to be configured manually."
    echo ""
fi

# =============================================================================
# Step 0: Enable systemd (WSL2)
# =============================================================================
if grep -q "microsoft" /proc/version 2>/dev/null; then
    if ! grep -q "systemd=true" /etc/wsl.conf 2>/dev/null; then
        echo "[0/15] Enabling systemd for WSL..."
        sudo tee /etc/wsl.conf > /dev/null << 'WSLCONF'
[boot]
systemd=true

[interop]
enabled=true
appendWindowsPath=true
WSLCONF
        echo "systemd enabled. Will take effect after WSL restart."
        echo "After bootstrap completes, run: wsl --shutdown (in PowerShell)"
        echo ""
    elif ! grep -q "\[interop\]" /etc/wsl.conf 2>/dev/null; then
        echo "[0/15] Adding interop configuration to WSL..."
        sudo tee -a /etc/wsl.conf > /dev/null << 'WSLCONF'

[interop]
enabled=true
appendWindowsPath=true
WSLCONF
        echo "interop enabled. Will take effect after WSL restart."
        echo ""
    fi
fi

# =============================================================================
# Step 1: Essential System Packages
# =============================================================================
echo "[1/15] Installing essential system packages..."
sudo apt update
sudo apt install -y \
    curl \
    wget \
    git \
    unzip \
    zip \
    tar \
    gzip \
    build-essential \
    ca-certificates \
    gnupg \
    lsb-release \
    apt-transport-https \
    software-properties-common

# =============================================================================
# Step 2: Useful CLI Tools
# =============================================================================
echo "[2/15] Installing CLI utilities..."
sudo apt install -y \
    htop \
    tree \
    jq \
    vim \
    nano \
    less \
    man-db \
    rsync \
    openssh-client \
    iputils-ping \
    dnsutils \
    netcat-openbsd \
    procps \
    file

# =============================================================================
# Step 3: ZSH
# =============================================================================
echo "[3/15] Installing ZSH..."
if ! command -v zsh &> /dev/null; then
    sudo apt install -y zsh
    # Set ZSH as default shell
    sudo chsh -s $(which zsh) $USER
    echo "ZSH installed and set as default shell"
else
    echo "ZSH already installed, skipping"
fi

# =============================================================================
# Step 4: Oh My Zsh
# =============================================================================
echo "[4/15] Installing Oh My Zsh..."
if [ ! -d ~/.oh-my-zsh ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "Oh My Zsh already installed, skipping"
fi

# =============================================================================
# Step 5: Docker
# =============================================================================
echo "[5/15] Installing Docker..."
if ! is_native_linux_command docker; then
    # Remove old versions if any
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Add Docker's official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Add the repository to Apt sources
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Add current user to docker group
    sudo usermod -aG docker $USER

    # Start Docker service
    sudo service docker start || true

    echo "Docker installed. NOTE: Log out and back in for docker group to take effect"
else
    echo "Docker already installed (native Linux), skipping"
    # Ensure docker is running
    sudo service docker start 2>/dev/null || true
fi

# =============================================================================
# Step 6: kubectl
# =============================================================================
echo "[6/15] Installing kubectl..."
if ! is_native_linux_command kubectl; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
else
    echo "kubectl already installed (native Linux), skipping"
fi

# =============================================================================
# Step 7: k3d
# =============================================================================
echo "[7/15] Installing k3d..."
if ! command -v k3d &> /dev/null; then
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
else
    echo "k3d already installed, skipping"
fi

# =============================================================================
# Step 8: Helm + k9s
# =============================================================================
echo "[8/15] Installing Helm and k9s..."

# Ensure ~/.local/bin exists and is in PATH for this session
mkdir -p ~/.local/bin
export PATH="$HOME/.local/bin:$PATH"

if ! command -v helm &> /dev/null; then
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | \
        HELM_INSTALL_DIR=$HOME/.local/bin USE_SUDO=false bash

    # Add Helm repos
    ~/.local/bin/helm repo add bitnami https://charts.bitnami.com/bitnami
    ~/.local/bin/helm repo add strimzi https://strimzi.io/charts/
    ~/.local/bin/helm repo update
else
    echo "Helm already installed, skipping"
fi

if ! command -v k9s &> /dev/null; then
    K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d '"' -f 4)
    curl -sLO "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz"
    tar xzf k9s_Linux_amd64.tar.gz k9s
    mv k9s ~/.local/bin/
    rm k9s_Linux_amd64.tar.gz
else
    echo "k9s already installed, skipping"
fi

# =============================================================================
# Step 9: Python (uv)
# =============================================================================
echo "[9/15] Installing Python tools (uv)..."
if ! command -v uv &> /dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
else
    echo "uv already installed, skipping"
fi

# =============================================================================
# Step 10: Node.js (fnm + bun)
# =============================================================================
echo "[10/15] Installing Node.js tools (fnm, bun)..."
if ! command -v fnm &> /dev/null; then
    curl -fsSL https://fnm.vercel.app/install | bash
else
    echo "fnm already installed, skipping"
fi

if ! command -v bun &> /dev/null; then
    curl -fsSL https://bun.sh/install | bash
else
    echo "bun already installed, skipping"
fi

# =============================================================================
# Step 11: Claude Code CLI
# =============================================================================
echo "[11/15] Installing Claude Code..."
if ! is_native_linux_command claude; then
    # Native installation via official installer
    curl -fsSL https://claude.ai/install.sh | bash
    echo "Claude Code installed"
    echo "NOTE: Run 'claude' and authenticate with your Anthropic account"
else
    echo "Claude Code already installed (native Linux), skipping"
fi

# =============================================================================
# Step 12: Claude Code MCP Server Templates
# =============================================================================
echo "[12/16] Setting up MCP server templates..."

CLAUDE_TEMPLATES_DIR="$HOME/.claude/templates"
mkdir -p "$CLAUDE_TEMPLATES_DIR"

# Playwright MCP template (for browser automation)
# Projects can copy this to their root as .mcp.json to enable
if [ ! -f "$CLAUDE_TEMPLATES_DIR/mcp-playwright.json" ]; then
    cat > "$CLAUDE_TEMPLATES_DIR/mcp-playwright.json" << 'MCPTEMPLATE'
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest"]
    }
  }
}
MCPTEMPLATE
    echo "Playwright MCP template created at $CLAUDE_TEMPLATES_DIR/mcp-playwright.json"
    echo "  To enable in a project: cp ~/.claude/templates/mcp-playwright.json /path/to/project/.mcp.json"
else
    echo "MCP templates already exist, skipping"
fi

# Install Playwright browser (Chrome) for MCP server
# This is required for the Playwright MCP server to work
if ! command -v npx &> /dev/null; then
    echo "npx not found, skipping Playwright browser installation"
elif [ ! -d "$HOME/.cache/ms-playwright" ]; then
    echo "Installing Playwright browser (Chrome)..."
    npx playwright install chrome
    echo "Playwright Chrome browser installed"
else
    echo "Playwright browsers already installed, skipping"
fi

# =============================================================================
# Step 13: Git Configuration (aliases only - identity set after dotfiles)
# =============================================================================
echo "[13/16] Configuring Git..."

# Delta diff viewer (optional, if installed)
if command -v delta &> /dev/null; then
    git config --global core.pager delta
    git config --global interactive.diffFilter "delta --color-only"
    echo "Delta diff viewer configured"
fi

# =============================================================================
# Step 14: Tailscale
# =============================================================================
echo "[14/16] Installing Tailscale..."
if ! command -v tailscale &> /dev/null; then
    # Use official Tailscale installer (works on Debian/Ubuntu)
    curl -fsSL https://tailscale.com/install.sh | sh

    # Start tailscaled service (requires systemd)
    if systemctl is-system-running &>/dev/null; then
        sudo systemctl enable --now tailscaled
        echo "Tailscale installed and tailscaled service started."
        echo "NOTE: Run 'sudo tailscale up' to connect to your Tailnet."
    else
        echo "Tailscale installed."
        echo "NOTE: systemd not running. After WSL restart, run:"
        echo "  sudo systemctl enable --now tailscaled"
        echo "  sudo tailscale up"
    fi
else
    echo "Tailscale already installed, skipping"
    # Ensure tailscaled is running
    if systemctl is-system-running &>/dev/null; then
        sudo systemctl enable --now tailscaled 2>/dev/null || true
    fi
fi

# =============================================================================
# Step 15: Remote Access (SSH, mosh, tmux)
# =============================================================================
echo "[15/16] Installing remote access tools (SSH, mosh, tmux)..."
sudo apt install -y openssh-server mosh tmux

# Enable and start SSH server (requires systemd)
if systemctl is-system-running &>/dev/null; then
    sudo systemctl enable --now ssh
    echo "SSH server enabled and started."
else
    echo "SSH server installed."
    echo "NOTE: systemd not running. After WSL restart, run:"
    echo "  sudo systemctl enable --now ssh"
fi

echo "Remote access tools installed:"
echo "  - SSH: Connect via 'ssh user@<tailscale-ip>'"
echo "  - mosh: Connect via 'mosh user@<tailscale-ip>'"
echo "  - tmux: Persistent terminal sessions"

# =============================================================================
# Step 16: GitHub CLI (gh) + GitLab CLI (glab)
# =============================================================================
echo "[16/16] Installing GitHub CLI and GitLab CLI..."

# GitHub CLI (gh)
if ! is_native_linux_command gh; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update
    sudo apt install -y gh
    echo "GitHub CLI installed. Run 'gh auth login' to authenticate."
else
    echo "GitHub CLI already installed (native Linux), skipping"
fi

# GitLab CLI (glab)
if ! is_native_linux_command glab; then
    # Get version from GitLab API (not GitHub)
    GLAB_VERSION=$(curl -s "https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases" | grep -o '"tag_name":"v[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/v//')
    if [ -n "$GLAB_VERSION" ]; then
        curl -sLO "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_linux_amd64.tar.gz"
        tar xzf "glab_${GLAB_VERSION}_linux_amd64.tar.gz"
        sudo install -o root -g root -m 0755 bin/glab /usr/local/bin/glab
        rm -rf "glab_${GLAB_VERSION}_linux_amd64.tar.gz" bin/
        echo "GitLab CLI installed. Run 'glab auth login' to authenticate."
    else
        echo "Warning: Could not determine glab version, skipping installation"
    fi
else
    echo "GitLab CLI already installed (native Linux), skipping"
fi

# =============================================================================
# Dotfiles
# =============================================================================
echo ""
echo "Installing dotfiles..."
if [ -f "$REPO_DIR/dotfiles/install.sh" ]; then
    "$REPO_DIR/dotfiles/install.sh"
else
    echo "Dotfiles not found, skipping (run from infrastructure repo)"
fi

# Set Git identity AFTER dotfiles (dotfiles overwrites gitconfig)
if [ -n "$DEV_NAME" ] && [ -n "$DEV_EMAIL" ]; then
    git config --global user.name "$DEV_NAME"
    git config --global user.email "$DEV_EMAIL"
    echo "Git identity set: $DEV_NAME <$DEV_EMAIL>"
else
    echo "NOTE: Git identity not set. Configure manually:"
    echo "  git config --global user.name \"Your Name\""
    echo "  git config --global user.email \"your-email@example.com\""
fi

# =============================================================================
# Volume directories
# =============================================================================
echo ""
echo "Creating volume directories..."
mkdir -p ~/k3d-vol/postgres-data
mkdir -p ~/k3d-vol/mongodb-data
mkdir -p ~/k3d-vol/redis-data
mkdir -p ~/k3d-vol/registry
mkdir -p ~/k3d-vol/registry-quay
chmod 777 ~/k3d-vol/*-data

# =============================================================================
# Registry Configuration (for k3d image caching)
# =============================================================================
echo ""
echo "Configuring container registry cache..."

# Check if already configured (from headless setup or previous run)
if grep -q "REGISTRY_MODE" "$CONFIG_FILE" 2>/dev/null; then
    source "$CONFIG_FILE"
    echo "Registry already configured: ${REGISTRY_MODE} mode"
    case "$REGISTRY_MODE" in
        remote) echo "  Host: ${REGISTRY_HOST}:${DOCKER_REGISTRY_PORT}/${QUAY_REGISTRY_PORT}" ;;
        local)  echo "  Local containers on ports ${DOCKER_REGISTRY_PORT}/${QUAY_REGISTRY_PORT}" ;;
        none)   echo "  No caching (direct pull from internet)" ;;
    esac
else
    # Only prompt interactively if stdin is a terminal
    if [ -t 0 ]; then
        echo ""
        echo "Container registries cache images to speed up k3d cluster resets."
        echo ""
        echo "Options:"
        echo "  1) None   - No cache, pull directly from internet (default)"
        echo "  2) Local  - Run registry containers in this WSL instance"
        echo "  3) Remote - Use existing registry server on your network"
        echo ""
        read -p "Select registry mode [1/2/3, default=1]: " REG_CHOICE

        case $REG_CHOICE in
            2)
                REGISTRY_MODE="local"
                REGISTRY_HOST="localhost"
                DOCKER_REGISTRY_PORT="5000"
                QUAY_REGISTRY_PORT="5001"
                ;;
            3)
                REGISTRY_MODE="remote"
                read -p "Registry server IP or hostname: " REGISTRY_HOST
                read -p "docker.io port [5000]: " DOCKER_REGISTRY_PORT
                read -p "quay.io port [5001]: " QUAY_REGISTRY_PORT
                DOCKER_REGISTRY_PORT=${DOCKER_REGISTRY_PORT:-5000}
                QUAY_REGISTRY_PORT=${QUAY_REGISTRY_PORT:-5001}
                ;;
            *)
                REGISTRY_MODE="none"
                REGISTRY_HOST=""
                DOCKER_REGISTRY_PORT=""
                QUAY_REGISTRY_PORT=""
                ;;
        esac

        # Append to config file
        cat >> "$CONFIG_FILE" << REGCONF

# Registry configuration (for k3d image caching)
REGISTRY_MODE="${REGISTRY_MODE}"
REGISTRY_HOST="${REGISTRY_HOST}"
DOCKER_REGISTRY_PORT="${DOCKER_REGISTRY_PORT}"
QUAY_REGISTRY_PORT="${QUAY_REGISTRY_PORT}"
REGCONF

        echo "Registry configuration saved"
    else
        # Non-interactive: use defaults (none)
        echo "Using default registry config (no cache)"
        cat >> "$CONFIG_FILE" << REGCONF

# Registry configuration (for k3d image caching)
REGISTRY_MODE="none"
REGISTRY_HOST=""
DOCKER_REGISTRY_PORT=""
QUAY_REGISTRY_PORT=""
REGCONF
    fi
fi

# =============================================================================
# WSL-specific configuration
# =============================================================================
echo ""
echo "Configuring WSL settings..."

# Find Windows user directory (use cmd.exe to get actual current user)
WIN_USER=""
WIN_USER_DIR=""
if command -v cmd.exe &> /dev/null; then
    WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')
    if [ -n "$WIN_USER" ] && [ -d "/mnt/c/Users/$WIN_USER" ]; then
        WIN_USER_DIR="/mnt/c/Users/$WIN_USER/"
    fi
fi

# Create .wslconfig if we found the Windows user dir and file doesn't exist
if [ -n "$WIN_USER_DIR" ] && [ ! -f "${WIN_USER_DIR}.wslconfig" ]; then
    # Calculate memory: total RAM - 10GB for Windows (minimum 8GB for WSL)
    TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))
    WSL_RAM_GB=$((TOTAL_RAM_GB - 10))
    [ $WSL_RAM_GB -lt 8 ] && WSL_RAM_GB=8

    # Calculate processors: 50% of total
    TOTAL_CPUS=$(nproc)
    WSL_CPUS=$((TOTAL_CPUS / 2))
    [ $WSL_CPUS -lt 2 ] && WSL_CPUS=2

    echo "Creating ${WIN_USER_DIR}.wslconfig (${WSL_RAM_GB}GB RAM, ${WSL_CPUS} CPUs)..."
    cat > "${WIN_USER_DIR}.wslconfig" << WSLCONFIG
[wsl2]
memory=${WSL_RAM_GB}GB
processors=${WSL_CPUS}
WSLCONFIG
    echo "NOTE: WSL restart required for .wslconfig changes (wsl --shutdown)"
else
    if [ -f "${WIN_USER_DIR}.wslconfig" ]; then
        echo ".wslconfig already exists, skipping"
    fi
fi

# =============================================================================
# Done
# =============================================================================
echo ""
echo "=========================================="
echo "Setup complete!"
echo "=========================================="
echo ""
echo "Installed:"
echo "  - System tools (curl, wget, git, jq, htop, ...)"
echo "  - ZSH + Oh My Zsh"
echo "  - Docker + Docker Compose"
echo "  - kubectl, k3d, Helm, k9s"
echo "  - uv (Python), fnm + bun (Node.js)"
echo "  - Claude Code CLI (+ ccstatusline config)"
echo "  - MCP server templates (playwright, etc.)"
echo "  - Git aliases and credential helper"
echo "  - Tailscale (run 'sudo tailscale up' to connect)"
echo "  - SSH server, mosh, tmux (remote access)"
echo "  - GitHub CLI (gh) + GitLab CLI (glab)"
echo ""
echo "MCP Server Templates:"
echo "  Templates are in ~/.claude/templates/"
echo "  To enable Playwright in a project:"
echo "    cp ~/.claude/templates/mcp-playwright.json /path/to/project/.mcp.json"
echo ""
echo "Next steps:"
echo "  1. Log out and back in (for docker group + zsh)"
echo "  2. source ~/.zshrc"
if [ -d "$REPO_DIR" ]; then
echo "  3. cd $REPO_DIR && make cluster-up"
echo "  4. make infra-up"
fi
echo ""
