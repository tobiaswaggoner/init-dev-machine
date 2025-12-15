#!/bin/bash
# Start Docker Registries with pull-through cache for docker.io and quay.io
# Reads configuration from ~/.config/dev-setup/config
# These registries survive k3d cluster resets and cache pulled images

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$HOME/.config/dev-setup/config"
K3D_NETWORK="k3d-my-dev"

# Load configuration or use defaults
if [[ -f "${CONFIG_FILE}" ]]; then
    source "${CONFIG_FILE}"
fi

# Defaults
REGISTRY_MODE="${REGISTRY_MODE:-none}"
REGISTRY_HOST="${REGISTRY_HOST:-localhost}"
DOCKER_REGISTRY_PORT="${DOCKER_REGISTRY_PORT:-5000}"
QUAY_REGISTRY_PORT="${QUAY_REGISTRY_PORT:-5001}"

# If none mode, skip everything
if [[ "${REGISTRY_MODE}" == "none" ]]; then
    echo "Registry cache disabled (mode=none)"
    exit 0
fi

# If remote mode, just verify connectivity and exit
if [[ "${REGISTRY_MODE}" == "remote" ]]; then
    echo "Using remote registry at ${REGISTRY_HOST}"
    echo "  docker.io: ${REGISTRY_HOST}:${DOCKER_REGISTRY_PORT}"
    echo "  quay.io:   ${REGISTRY_HOST}:${QUAY_REGISTRY_PORT}"

    # Quick connectivity check
    if curl -s --connect-timeout 2 "http://${REGISTRY_HOST}:${DOCKER_REGISTRY_PORT}/v2/" >/dev/null 2>&1; then
        echo "  ✓ docker.io registry reachable"
    else
        echo "  ⚠ docker.io registry not reachable"
    fi
    if curl -s --connect-timeout 2 "http://${REGISTRY_HOST}:${QUAY_REGISTRY_PORT}/v2/" >/dev/null 2>&1; then
        echo "  ✓ quay.io registry reachable"
    else
        echo "  ⚠ quay.io registry not reachable"
    fi
    exit 0
fi

# Local mode: start registry containers
start_registry() {
    local name=$1
    local port=$2
    local remote_url=$3
    local cache_dir=$4

    mkdir -p "${cache_dir}"

    if docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
        echo "Registry ${name} is already running"
    else
        docker rm -f "${name}" 2>/dev/null || true
        docker run -d \
            --name "${name}" \
            --restart=always \
            -p "${port}:5000" \
            -v "${cache_dir}:/var/lib/registry" \
            -e REGISTRY_PROXY_REMOTEURL="${remote_url}" \
            registry:2
        echo "Started ${name} -> ${remote_url}"
    fi

    # Connect to k3d network if it exists
    if docker network ls --format '{{.Name}}' | grep -q "^${K3D_NETWORK}$"; then
        docker network connect "${K3D_NETWORK}" "${name}" 2>/dev/null || true
    fi
}

# Start local registries
start_registry "k3d-registry.localhost" "${DOCKER_REGISTRY_PORT}" "https://registry-1.docker.io" "${HOME}/k3d-vol/registry"
start_registry "k3d-registry-quay" "${QUAY_REGISTRY_PORT}" "https://quay.io" "${HOME}/k3d-vol/registry-quay"

echo ""
echo "Local registry cache:"
echo "  docker.io: ~/k3d-vol/registry"
echo "  quay.io:   ~/k3d-vol/registry-quay"
