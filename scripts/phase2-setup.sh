#!/bin/bash
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE 2: Pre-Bootstrap Setup
# Run this after fresh Debian WSL installation
#
# This script:
# 1. Installs minimal prerequisites (git, curl, wget)
# 2. Collects your configuration (name, email)
# 3. Generates SSH key and helps you add it to GitHub
# 4. Clones the infrastructure repository
#
# After this, run: ./scripts/bootstrap.sh
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
set -e

CONFIG_DIR="$HOME/.config/dev-setup"
CONFIG_FILE="$CONFIG_DIR/config"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Phase 2: Pre-Bootstrap Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 1: Install prerequisites
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "[1/5] Installing prerequisites..."
sudo apt update && sudo apt install -y git curl wget ca-certificates
echo ""

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 2: Collect configuration
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "[2/5] Collecting your configuration..."
echo ""

# Check if config already exists
if [ -f "$CONFIG_FILE" ]; then
    echo "Found existing configuration:"
    cat "$CONFIG_FILE"
    echo ""
    read -p "Use existing config? [Y/n]: " USE_EXISTING
    if [[ "$USE_EXISTING" =~ ^[Nn] ]]; then
        rm "$CONFIG_FILE"
    fi
fi

# Collect if no config or user wants new
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Please enter your details:"
    echo ""

    read -p "  Your full name (for Git): " DEV_NAME
    read -p "  Your email (for Git & SSH key): " DEV_EMAIL

    # Optional: GitHub username for cloning
    read -p "  GitHub username [tobiaswaggoner]: " GITHUB_USER
    GITHUB_USER=${GITHUB_USER:-tobiaswaggoner}

    # Save configuration
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" << CONF
# Development setup configuration
# Generated: $(date)
DEV_NAME="$DEV_NAME"
DEV_EMAIL="$DEV_EMAIL"
GITHUB_USER="$GITHUB_USER"
CONF

    echo ""
    echo "Configuration saved to $CONFIG_FILE"
fi

# Load configuration
source "$CONFIG_FILE"
echo ""

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 3: Generate SSH key
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "[3/5] Setting up SSH key..."

if [ -f "$HOME/.ssh/id_ed25519" ]; then
    echo "SSH key already exists at ~/.ssh/id_ed25519"
else
    ssh-keygen -t ed25519 -C "$DEV_EMAIL" -N "" -f "$HOME/.ssh/id_ed25519"
    echo "SSH key generated"
fi

# Start ssh-agent and add key
eval "$(ssh-agent -s)" > /dev/null
ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ACTION REQUIRED: Add this SSH key to GitHub"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Copy the key below"
echo "2. Go to: https://github.com/settings/keys"
echo "3. Click 'New SSH key'"
echo "4. Paste the key and save"
echo ""
echo "━━━━━━━━━━━━ YOUR PUBLIC KEY ━━━━━━━━━━━━"
cat "$HOME/.ssh/id_ed25519.pub"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
read -p "Press Enter after adding the key to GitHub..."

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 4: Test GitHub connection
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "[4/5] Testing GitHub connection..."
echo ""

# Test connection (this will prompt to accept GitHub's key)
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo "✓ GitHub connection successful!"
else
    echo "Testing connection (you may need to type 'yes' to accept GitHub's host key)..."
    ssh -T git@github.com || true
fi
echo ""

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Step 5: Clone repository
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "[5/5] Cloning infrastructure repository..."

REPO_URL="git@github.com:${GITHUB_USER}/init-dev-machine.git"
REPO_DIR="$HOME/src/infrastructure"

if [ -d "$REPO_DIR" ]; then
    echo "Repository already exists at $REPO_DIR"
    cd "$REPO_DIR"
    git pull || true
else
    mkdir -p "$HOME/src"
    git clone "$REPO_URL" "$REPO_DIR"
    cd "$REPO_DIR"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✓ Phase 2 Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Your configuration:"
echo "  Name:   $DEV_NAME"
echo "  Email:  $DEV_EMAIL"
echo "  GitHub: $GITHUB_USER"
echo ""
echo "Next step - copy and paste this:"
echo ""
echo "  cd ~/src/infrastructure && ./scripts/bootstrap.sh"
echo ""
