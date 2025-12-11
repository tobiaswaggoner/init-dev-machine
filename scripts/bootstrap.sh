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
# Step 1: Essential System Packages
# =============================================================================
echo "[1/13] Installing essential system packages..."
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
echo "[2/13] Installing CLI utilities..."
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
echo "[3/13] Installing ZSH..."
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
echo "[4/13] Installing Oh My Zsh..."
if [ ! -d ~/.oh-my-zsh ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "Oh My Zsh already installed, skipping"
fi

# =============================================================================
# Step 5: Docker
# =============================================================================
echo "[5/13] Installing Docker..."
if ! command -v docker &> /dev/null; then
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
    echo "Docker already installed, skipping"
    # Ensure docker is running
    sudo service docker start 2>/dev/null || true
fi

# =============================================================================
# Step 6: kubectl
# =============================================================================
echo "[6/13] Installing kubectl..."
if ! command -v kubectl &> /dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
else
    echo "kubectl already installed, skipping"
fi

# =============================================================================
# Step 7: k3d
# =============================================================================
echo "[7/13] Installing k3d..."
if ! command -v k3d &> /dev/null; then
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
else
    echo "k3d already installed, skipping"
fi

# =============================================================================
# Step 8: Helm + k9s
# =============================================================================
echo "[8/13] Installing Helm and k9s..."

# Ensure ~/.local/bin exists and is in PATH
mkdir -p ~/.local/bin

if ! command -v helm &> /dev/null; then
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | \
        HELM_INSTALL_DIR=~/.local/bin USE_SUDO=false bash

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
echo "[9/13] Installing Python tools (uv)..."
if ! command -v uv &> /dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
else
    echo "uv already installed, skipping"
fi

# =============================================================================
# Step 10: Node.js (fnm + bun)
# =============================================================================
echo "[10/13] Installing Node.js tools (fnm, bun)..."
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
echo "[11/13] Installing Claude Code..."
if ! command -v claude &> /dev/null; then
    # Native installation via official installer
    curl -fsSL https://claude.ai/install.sh | bash
    echo "Claude Code installed"
    echo "NOTE: Run 'claude' and authenticate with your Anthropic account"
else
    echo "Claude Code already installed, skipping"
fi

# =============================================================================
# Step 12: Git Configuration Check
# =============================================================================
echo "[12/13] Checking Git configuration..."

# Git config will be set via dotfiles/gitconfig symlink
# Just add delta support if available
if command -v delta &> /dev/null; then
    git config --global core.pager delta
    git config --global interactive.diffFilter "delta --color-only"
    echo "Delta diff viewer configured"
fi

echo "Git aliases and settings will be applied via dotfiles"
echo "NOTE: Remember to set your identity after setup:"
echo "  git config --global user.name \"Your Name\""
echo "  git config --global user.email \"your-email@example.com\""

# =============================================================================
# Step 13: GitHub CLI (gh) + GitLab CLI (glab)
# =============================================================================
echo "[13/13] Installing GitHub CLI and GitLab CLI..."

# GitHub CLI (gh)
if ! command -v gh &> /dev/null; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update
    sudo apt install -y gh
    echo "GitHub CLI installed. Run 'gh auth login' to authenticate."
else
    echo "GitHub CLI already installed, skipping"
fi

# GitLab CLI (glab)
if ! command -v glab &> /dev/null; then
    GLAB_VERSION=$(curl -s https://api.github.com/repos/gitlab-org/cli/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//')
    curl -sLO "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_Linux_x86_64.tar.gz"
    tar xzf "glab_${GLAB_VERSION}_Linux_x86_64.tar.gz"
    sudo install -o root -g root -m 0755 bin/glab /usr/local/bin/glab
    rm -rf "glab_${GLAB_VERSION}_Linux_x86_64.tar.gz" bin/
    echo "GitLab CLI installed. Run 'glab auth login' to authenticate."
else
    echo "GitLab CLI already installed, skipping"
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

# =============================================================================
# Volume directories
# =============================================================================
echo ""
echo "Creating volume directories..."
mkdir -p ~/k3d-vol/postgres-data
mkdir -p ~/k3d-vol/mongodb-data
mkdir -p ~/k3d-vol/redis-data
chmod 777 ~/k3d-vol/*-data

# =============================================================================
# WSL-specific configuration
# =============================================================================
echo ""
echo "Configuring WSL settings..."

# Create .wslconfig hint if not exists
if [ ! -f /mnt/c/Users/$USER/.wslconfig ] 2>/dev/null; then
    echo "TIP: Consider creating C:\\Users\\$USER\\.wslconfig with:"
    echo "  [wsl2]"
    echo "  memory=8GB"
    echo "  processors=4"
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
echo "  - Git aliases and credential helper"
echo "  - GitHub CLI (gh) + GitLab CLI (glab)"
echo ""
echo "Next steps:"
echo "  1. Log out and back in (for docker group + zsh)"
echo "  2. source ~/.zshrc"
if [ -d "$REPO_DIR" ]; then
echo "  3. cd $REPO_DIR && make cluster-up"
echo "  4. make infra-up"
fi
echo ""
