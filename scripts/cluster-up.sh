#!/bin/bash
#------------------------------------------------------------------------------
# Smart cluster-up script
# - Checks if port 8080 is free
# - If used by our cluster: restart it
# - If used by something else: find free port or error
#------------------------------------------------------------------------------
set -e

CLUSTER_NAME="my-dev"
DEFAULT_PORT=8080
CONFIG_FILE="k8s/cluster/k3d-config.yaml"

# Check if port is in use
check_port() {
    local port=$1
    if command -v ss &> /dev/null; then
        ss -tlnp 2>/dev/null | grep -q ":$port " && return 0 || return 1
    elif command -v netstat &> /dev/null; then
        netstat -tlnp 2>/dev/null | grep -q ":$port " && return 0 || return 1
    else
        # Fallback: try to connect
        (echo >/dev/tcp/localhost/$port) 2>/dev/null && return 0 || return 1
    fi
}

# Check if our k3d cluster exists
cluster_exists() {
    k3d cluster list 2>/dev/null | grep -q "^$CLUSTER_NAME "
}

# Check if our k3d cluster is using the port
our_cluster_uses_port() {
    # If cluster exists, check if its loadbalancer is using the port
    if cluster_exists; then
        docker ps --format '{{.Names}} {{.Ports}}' 2>/dev/null | grep "k3d-$CLUSTER_NAME-serverlb" | grep -q ":$DEFAULT_PORT->" && return 0
    fi
    return 1
}

# Find a free port starting from a base
find_free_port() {
    local port=$1
    while check_port $port; do
        port=$((port + 1))
        if [ $port -gt 9000 ]; then
            echo "Error: Could not find free port" >&2
            return 1
        fi
    done
    echo $port
}

# Main logic
echo "Checking cluster status..."

# Start pull-through cache registry (survives cluster resets)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/registry-up.sh"

# Generate k3d config from template (applies registry settings)
"$SCRIPT_DIR/generate-k3d-config.sh"

# Setup volumes first
mkdir -p "$HOME/k3d-vol/postgres-data"
mkdir -p "$HOME/k3d-vol/mongodb-data"
mkdir -p "$HOME/k3d-vol/redis-data"
mkdir -p "$HOME/k3d-vol/registry"
chmod 777 "$HOME/k3d-vol"/*-data 2>/dev/null || true
echo "Volume directories ready"

# Check if cluster already exists
if cluster_exists; then
    echo "Cluster '$CLUSTER_NAME' already exists"

    # Check if it's running
    if docker ps --format '{{.Names}}' | grep -q "k3d-$CLUSTER_NAME"; then
        echo "Cluster is running"
        kubectl cluster-info
        exit 0
    else
        echo "Cluster exists but not running, starting..."
        k3d cluster start "$CLUSTER_NAME"
        kubectl cluster-info
        exit 0
    fi
fi

# Cluster doesn't exist - check port availability
if check_port $DEFAULT_PORT; then
    # Port is in use - by what?
    echo "Port $DEFAULT_PORT is in use"

    # Check if it's a k3d container from a different cluster
    if docker ps --format '{{.Names}} {{.Ports}}' | grep "k3d-" | grep -q ":$DEFAULT_PORT->"; then
        OTHER_CLUSTER=$(docker ps --format '{{.Names}}' | grep "k3d-.*-serverlb" | sed 's/k3d-\(.*\)-serverlb/\1/')
        echo "Port is used by k3d cluster: $OTHER_CLUSTER"
        echo ""
        echo "Options:"
        echo "  1. Stop the other cluster: k3d cluster stop $OTHER_CLUSTER"
        echo "  2. Delete the other cluster: k3d cluster delete $OTHER_CLUSTER"
        exit 1
    fi

    # Find alternative port
    ALT_PORT=$(find_free_port $((DEFAULT_PORT + 1)))
    echo "Port $DEFAULT_PORT is used by another service"
    echo ""
    echo "Found free port: $ALT_PORT"
    echo ""
    read -p "Create cluster with port $ALT_PORT instead? [y/N]: " response

    if [[ "$response" =~ ^[Yy]$ ]]; then
        # Create temporary config with different port
        # Format in config is "8080:80" where 8080 is host port
        TEMP_CONFIG=$(mktemp)
        sed "s/$DEFAULT_PORT:80/$ALT_PORT:80/g" "$CONFIG_FILE" > "$TEMP_CONFIG"

        echo "Creating cluster '$CLUSTER_NAME' on port $ALT_PORT..."
        k3d cluster create --config "$TEMP_CONFIG"
        rm "$TEMP_CONFIG"

        # Connect registry to k3d network
        docker network connect "k3d-$CLUSTER_NAME" "k3d-registry.localhost" 2>/dev/null || true
        echo "Registry connected to cluster network"

        echo ""
        echo "NOTE: Cluster is running on port $ALT_PORT (not $DEFAULT_PORT)"
        kubectl cluster-info
    else
        echo "Aborted. Free port $DEFAULT_PORT first or choose alternative."
        exit 1
    fi
else
    # Port is free - create cluster normally
    echo "Creating cluster '$CLUSTER_NAME' on port $DEFAULT_PORT..."
    k3d cluster create --config "$CONFIG_FILE"

    # Connect registry to k3d network
    docker network connect "k3d-$CLUSTER_NAME" "k3d-registry.localhost" 2>/dev/null || true
    echo "Registry connected to cluster network"

    kubectl cluster-info
fi
