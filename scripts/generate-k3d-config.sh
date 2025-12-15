#!/bin/bash
# Generates k3d-config.yaml from template based on registry configuration
# Reads from ~/.config/dev-setup/config

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$HOME/.config/dev-setup/config"
TEMPLATE="${SCRIPT_DIR}/../k8s/cluster/k3d-config.yaml.template"
OUTPUT="${SCRIPT_DIR}/../k8s/cluster/k3d-config.yaml"

# Load configuration or use defaults
if [[ -f "${CONFIG_FILE}" ]]; then
    source "${CONFIG_FILE}"
fi

# Defaults
REGISTRY_MODE="${REGISTRY_MODE:-none}"
REGISTRY_HOST="${REGISTRY_HOST:-localhost}"
DOCKER_REGISTRY_PORT="${DOCKER_REGISTRY_PORT:-5000}"
QUAY_REGISTRY_PORT="${QUAY_REGISTRY_PORT:-5001}"

# Handle "none" mode - remove registry section entirely
if [[ "${REGISTRY_MODE}" == "none" ]]; then
    # Copy template but remove registry section
    sed '/^# Registry configuration/,/^$/d' "${TEMPLATE}" > "${OUTPUT}"
    echo "Generated ${OUTPUT}"
    echo "  Registry mode: none (no cache)"
    exit 0
fi

# Determine registry endpoints based on mode
if [[ "${REGISTRY_MODE}" == "remote" ]]; then
    DOCKER_REGISTRY="${REGISTRY_HOST}:${DOCKER_REGISTRY_PORT}"
    QUAY_REGISTRY="${REGISTRY_HOST}:${QUAY_REGISTRY_PORT}"
else
    # Local containers are accessed by name within k3d network
    DOCKER_REGISTRY="k3d-registry.localhost:5000"
    QUAY_REGISTRY="k3d-registry-quay:5000"
fi

# Generate config from template
sed -e "s|{{DOCKER_REGISTRY}}|${DOCKER_REGISTRY}|g" \
    -e "s|{{QUAY_REGISTRY}}|${QUAY_REGISTRY}|g" \
    "${TEMPLATE}" > "${OUTPUT}"

echo "Generated ${OUTPUT}"
echo "  Registry mode: ${REGISTRY_MODE}"
echo "  docker.io -> http://${DOCKER_REGISTRY}"
echo "  quay.io   -> http://${QUAY_REGISTRY}"
