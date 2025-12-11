#!/bin/bash
set -e

echo "Installing Helm..."

# Check if helm is already installed
if command -v helm &> /dev/null; then
    echo "Helm is already installed: $(helm version --short)"
    exit 0
fi

# Install Helm to user directory (no sudo required)
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | \
    HELM_INSTALL_DIR=~/.local/bin USE_SUDO=false bash

# Verify installation
~/.local/bin/helm version

# Add common repositories
echo "Adding Helm repositories..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add strimzi https://strimzi.io/charts/
helm repo update

echo "Helm installation complete!"
