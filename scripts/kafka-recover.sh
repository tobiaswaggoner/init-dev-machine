#!/bin/bash
#------------------------------------------------------------------------------
# Kafka Recovery Script for WSL/k3d environments
#
# Problem: After WSL restart, Strimzi generates a new cluster.id that doesn't
# match the existing data on the PVC, causing Kafka to fail to start.
#
# Solution: Extract the cluster.id from the PVC and patch the Kafka CR status
# before reconciliation happens.
#------------------------------------------------------------------------------
set -e

NAMESPACE="${KAFKA_NAMESPACE:-kafka}"
KAFKA_CLUSTER="${KAFKA_CLUSTER_NAME:-dev-kafka}"
NODE_POOL="${KAFKA_NODE_POOL:-dev-pool}"
PVC_NAME="data-${KAFKA_CLUSTER}-${NODE_POOL}-0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

#------------------------------------------------------------------------------
# Check if recovery is needed
#------------------------------------------------------------------------------
check_recovery_needed() {
    log_info "Checking if Kafka recovery is needed..."

    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
        log_info "Namespace '$NAMESPACE' does not exist. No recovery needed."
        return 1
    fi

    # Check if PVC exists
    if ! kubectl get pvc "$PVC_NAME" -n "$NAMESPACE" &>/dev/null; then
        log_info "PVC '$PVC_NAME' does not exist. No recovery needed."
        return 1
    fi

    # Check if Kafka CR exists
    if ! kubectl get kafka "$KAFKA_CLUSTER" -n "$NAMESPACE" &>/dev/null; then
        log_info "Kafka CR '$KAFKA_CLUSTER' does not exist. No recovery needed."
        return 1
    fi

    # Check if Kafka broker pod exists and is healthy
    local broker_pod
    broker_pod=$(kubectl get pods -n "$NAMESPACE" -l "strimzi.io/cluster=$KAFKA_CLUSTER,strimzi.io/name=${KAFKA_CLUSTER}-kafka" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

    if [[ -n "$broker_pod" ]]; then
        # Check for CrashLoopBackOff or other unhealthy states
        local container_state
        container_state=$(kubectl get pod "$broker_pod" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || true)

        if [[ "$container_state" == "CrashLoopBackOff" || "$container_state" == "Error" || "$container_state" == "ImagePullBackOff" ]]; then
            log_warn "Kafka broker pod is in $container_state state. Recovery needed!"
            return 0
        fi

        # Check if pod is ready
        local ready
        ready=$(kubectl get pod "$broker_pod" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null || true)
        if [[ "$ready" == "true" ]]; then
            log_info "Kafka broker pod is healthy. No recovery needed."
            return 1
        fi

        # Pod exists but not ready - check if it's starting up or stuck
        local restart_count
        restart_count=$(kubectl get pod "$broker_pod" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || echo "0")
        if [[ "$restart_count" -gt 3 ]]; then
            log_warn "Kafka broker pod has restarted $restart_count times. Recovery needed!"
            return 0
        fi

        log_info "Kafka broker pod exists but not ready yet. Waiting..."
        return 1
    fi

    # Check if StrimziPodSet exists but has no actual pods
    local sps_pods
    sps_pods=$(kubectl get strimzipodset -n "$NAMESPACE" -o jsonpath='{.items[0].status.pods}' 2>/dev/null || echo "0")
    local actual_pods
    actual_pods=$(kubectl get pods -n "$NAMESPACE" -l "strimzi.io/cluster=$KAFKA_CLUSTER,strimzi.io/name=${KAFKA_CLUSTER}-kafka" --no-headers 2>/dev/null | wc -l)

    if [[ "$sps_pods" -gt 0 && "$actual_pods" -eq 0 ]]; then
        log_warn "StrimziPodSet reports $sps_pods pods but $actual_pods actually exist. Recovery needed!"
        return 0
    fi

    # Check if reconciliation is stuck
    local last_transition
    last_transition=$(kubectl get kafka "$KAFKA_CLUSTER" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].lastTransitionTime}' 2>/dev/null || true)

    if [[ -z "$last_transition" ]]; then
        log_warn "Kafka CR has no Ready condition. Recovery may be needed."
        return 0
    fi

    log_info "Kafka appears healthy. No recovery needed."
    return 1
}

#------------------------------------------------------------------------------
# Extract cluster.id from PVC using a temporary pod
#------------------------------------------------------------------------------
extract_cluster_id() {
    log_info "Extracting cluster.id from PVC..."

    # Create a temporary pod to read the meta.properties file
    local temp_pod="kafka-recovery-reader-$$"

    cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: $temp_pod
  namespace: $NAMESPACE
spec:
  containers:
  - name: reader
    image: busybox:latest
    command: ["sleep", "300"]
    volumeMounts:
    - name: kafka-data
      mountPath: /data
  volumes:
  - name: kafka-data
    persistentVolumeClaim:
      claimName: $PVC_NAME
  restartPolicy: Never
EOF

    log_info "Waiting for temporary pod to be ready..."
    kubectl wait --for=condition=ready pod/"$temp_pod" -n "$NAMESPACE" --timeout=60s >/dev/null 2>&1

    # Find and read meta.properties
    local cluster_id
    cluster_id=$(kubectl exec -n "$NAMESPACE" "$temp_pod" -- sh -c '
        # Look for meta.properties in various possible locations
        for dir in /data /data/kafka-log0 /data/__cluster_metadata-0; do
            if [ -f "$dir/meta.properties" ]; then
                grep "^cluster.id=" "$dir/meta.properties" | cut -d= -f2
                exit 0
            fi
        done
        # Also try to find it recursively
        find /data -name "meta.properties" -exec grep "^cluster.id=" {} \; 2>/dev/null | head -1 | cut -d= -f2
    ' 2>/dev/null || true)

    # Cleanup temporary pod
    kubectl delete pod "$temp_pod" -n "$NAMESPACE" --grace-period=0 --force >/dev/null 2>&1 || true

    if [[ -z "$cluster_id" ]]; then
        log_error "Could not extract cluster.id from PVC"
        return 1
    fi

    echo "$cluster_id"
}

#------------------------------------------------------------------------------
# Patch Kafka CR status with the correct cluster.id
#------------------------------------------------------------------------------
patch_kafka_status() {
    local cluster_id="$1"

    log_info "Patching Kafka CR status with cluster.id: $cluster_id"

    # Pause reconciliation first
    log_info "Pausing Strimzi reconciliation..."
    kubectl annotate kafka "$KAFKA_CLUSTER" -n "$NAMESPACE" \
        strimzi.io/pause-reconciliation="true" --overwrite >/dev/null

    # Give operator time to notice the pause
    sleep 2

    # Patch the status with the correct cluster.id
    log_info "Setting cluster.id in Kafka status..."
    kubectl patch kafka "$KAFKA_CLUSTER" -n "$NAMESPACE" \
        --type merge --subresource=status \
        -p "{\"status\":{\"clusterId\":\"$cluster_id\"}}" >/dev/null

    # Also patch the KafkaNodePool status
    log_info "Setting cluster.id in KafkaNodePool status..."
    kubectl patch kafkanodepool "$NODE_POOL" -n "$NAMESPACE" \
        --type merge --subresource=status \
        -p "{\"status\":{\"clusterId\":\"$cluster_id\"}}" >/dev/null 2>&1 || true

    # Delete stale StrimziPodSet if it exists
    if kubectl get strimzipodset "${KAFKA_CLUSTER}-${NODE_POOL}" -n "$NAMESPACE" &>/dev/null; then
        log_info "Deleting stale StrimziPodSet..."
        kubectl delete strimzipodset "${KAFKA_CLUSTER}-${NODE_POOL}" -n "$NAMESPACE" >/dev/null 2>&1 || true
    fi

    # Resume reconciliation
    log_info "Resuming Strimzi reconciliation..."
    kubectl annotate kafka "$KAFKA_CLUSTER" -n "$NAMESPACE" \
        strimzi.io/pause-reconciliation- >/dev/null

    log_info "Kafka CR status patched successfully"
}

#------------------------------------------------------------------------------
# Wait for Kafka to be ready
#------------------------------------------------------------------------------
wait_for_kafka() {
    log_info "Waiting for Kafka broker pod to be created..."

    local retries=30
    local count=0

    while [[ $count -lt $retries ]]; do
        local broker_pod
        broker_pod=$(kubectl get pods -n "$NAMESPACE" -l "strimzi.io/cluster=$KAFKA_CLUSTER,strimzi.io/name=${KAFKA_CLUSTER}-kafka" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

        if [[ -n "$broker_pod" ]]; then
            log_info "Kafka broker pod '$broker_pod' found. Waiting for ready state..."
            if kubectl wait --for=condition=ready pod/"$broker_pod" -n "$NAMESPACE" --timeout=300s 2>/dev/null; then
                log_info "Kafka broker is ready!"
                return 0
            fi
        fi

        count=$((count + 1))
        echo -n "."
        sleep 10
    done

    log_error "Timeout waiting for Kafka broker pod"
    return 1
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------
main() {
    echo "========================================"
    echo "Kafka Recovery Script for Strimzi/KRaft"
    echo "========================================"
    echo ""

    # Check if kubectl is available
    if ! command -v kubectl &>/dev/null; then
        log_error "kubectl not found in PATH"
        exit 1
    fi

    # Check cluster connectivity
    if ! kubectl cluster-info &>/dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi

    # Check if recovery is needed
    if ! check_recovery_needed; then
        exit 0
    fi

    log_warn "Recovery needed! Starting recovery process..."
    echo ""

    # Extract cluster.id from PVC
    local cluster_id
    cluster_id=$(extract_cluster_id)

    if [[ -z "$cluster_id" ]]; then
        log_error "Failed to extract cluster.id. Manual intervention required."
        exit 1
    fi

    log_info "Found cluster.id: $cluster_id"

    # Patch Kafka CR status
    patch_kafka_status "$cluster_id"

    # Wait for Kafka to be ready
    echo ""
    if wait_for_kafka; then
        echo ""
        log_info "Kafka recovery completed successfully!"
    else
        echo ""
        log_error "Kafka recovery may have partially failed. Check pod status."
        exit 1
    fi
}

# Run main function
main "$@"
