#!/bin/bash
# Install dotfiles by creating symlinks
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing dotfiles from $SCRIPT_DIR"

# Backup and symlink .zshrc
if [ -f ~/.zshrc ] && [ ! -L ~/.zshrc ]; then
    echo "Backing up existing .zshrc to .zshrc.backup"
    mv ~/.zshrc ~/.zshrc.backup
fi
ln -sf "$SCRIPT_DIR/zshrc" ~/.zshrc
echo "Linked ~/.zshrc -> $SCRIPT_DIR/zshrc"

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
