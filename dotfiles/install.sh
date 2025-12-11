#!/bin/bash
# Install dotfiles by copying (not symlinks - tools modify these files)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing dotfiles from $SCRIPT_DIR"

# Copy .zshrc (not symlink - uv, fnm, bun modify this file during install)
if [ -f ~/.zshrc ] && [ ! -f ~/.zshrc.backup ]; then
    echo "Backing up existing .zshrc to .zshrc.backup"
    cp ~/.zshrc ~/.zshrc.backup
fi
cp "$SCRIPT_DIR/zshrc" ~/.zshrc
echo "Copied ~/.zshrc from $SCRIPT_DIR/zshrc"

# Backup and symlink .gitconfig
if [ -f ~/.gitconfig ] && [ ! -L ~/.gitconfig ]; then
    echo "Backing up existing .gitconfig to .gitconfig.backup"
    mv ~/.gitconfig ~/.gitconfig.backup
fi
if [ -f "$SCRIPT_DIR/gitconfig" ]; then
    ln -sf "$SCRIPT_DIR/gitconfig" ~/.gitconfig
    echo "Linked ~/.gitconfig -> $SCRIPT_DIR/gitconfig"
fi

# Claude Code settings (including ccstatusline config)
if [ -d "$SCRIPT_DIR/claude" ]; then
    mkdir -p ~/.claude
    # Copy settings.json (don't symlink - Claude Code modifies this file)
    if [ -f "$SCRIPT_DIR/claude/settings.json" ]; then
        if [ ! -f ~/.claude/settings.json ]; then
            cp "$SCRIPT_DIR/claude/settings.json" ~/.claude/settings.json
            echo "Copied Claude settings to ~/.claude/settings.json"
        else
            echo "~/.claude/settings.json already exists, skipping (check for updates manually)"
        fi
    fi
fi

echo ""
echo "Dotfiles installed. Run 'source ~/.zshrc' to reload."
