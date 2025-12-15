.PHONY: help cluster-up cluster-down cluster-reset cluster-status \
        infra-up infra-down infra-status \
        postgres-up postgres-down mongodb-up mongodb-down redis-up redis-down \
        kafka-up kafka-down strimzi-up strimzi-down \
        port-forward-postgres port-forward-mongodb port-forward-redis \
        setup-volumes

HELM := helm
KUBECTL := kubectl
K3D := k3d
CLUSTER_NAME := my-dev
NAMESPACE := infra
MANIFESTS := k8s/manifests

# Default target
help:
	@echo "Cluster Management:"
	@echo "  make cluster-up      - Create and start k3d cluster"
	@echo "  make cluster-down    - Stop cluster (keeps data)"
	@echo "  make cluster-reset   - Delete and recreate cluster"
	@echo "  make cluster-status  - Show cluster status"
	@echo ""
	@echo "Infrastructure:"
	@echo "  make infra-up        - Deploy all infrastructure services"
	@echo "  make infra-down      - Remove all infrastructure services"
	@echo "  make infra-status    - Show service status"
	@echo ""
	@echo "Individual Services:"
	@echo "  make postgres-up/down"
	@echo "  make mongodb-up/down"
	@echo "  make redis-up/down"
	@echo "  make kafka-up/down   - Includes Strimzi operator"
	@echo ""
	@echo "Port Forwarding:"
	@echo "  make port-forward-postgres  - Forward PostgreSQL (5432)"
	@echo "  make port-forward-mongodb   - Forward MongoDB (27017)"
	@echo "  make port-forward-redis     - Forward Redis (6379)"

# =============================================================================
# Cluster Management
# =============================================================================

setup-volumes:
	@mkdir -p $(HOME)/k3d-vol/postgres-data
	@mkdir -p $(HOME)/k3d-vol/mongodb-data
	@mkdir -p $(HOME)/k3d-vol/redis-data
	@chmod 777 $(HOME)/k3d-vol/*-data
	@echo "Volume directories created"

cluster-up:
	@./scripts/cluster-up.sh

cluster-down:
	$(K3D) cluster stop $(CLUSTER_NAME)

cluster-reset: setup-volumes
	-$(K3D) cluster delete $(CLUSTER_NAME)
	$(K3D) cluster create --config k8s/cluster/k3d-config.yaml
	@$(KUBECTL) cluster-info

cluster-status:
	@$(K3D) cluster list
	@echo ""
	@$(KUBECTL) get nodes

# =============================================================================
# Namespace
# =============================================================================

namespace:
	@$(KUBECTL) create namespace $(NAMESPACE) --dry-run=client -o yaml | $(KUBECTL) apply -f -

# =============================================================================
# PostgreSQL (Official image, not Bitnami)
# =============================================================================

postgres-up: namespace
	$(KUBECTL) apply -f $(MANIFESTS)/postgres.yaml
	@echo "Waiting for PostgreSQL to be ready..."
	@$(KUBECTL) wait --for=condition=ready pod -l app=postgres -n $(NAMESPACE) --timeout=600s

postgres-down:
	-$(KUBECTL) delete -f $(MANIFESTS)/postgres.yaml

# =============================================================================
# MongoDB (Official image, not Bitnami)
# =============================================================================

mongodb-up: namespace
	$(KUBECTL) apply -f $(MANIFESTS)/mongodb.yaml
	@echo "Waiting for MongoDB to be ready..."
	@$(KUBECTL) wait --for=condition=ready pod -l app=mongodb -n $(NAMESPACE) --timeout=600s

mongodb-down:
	-$(KUBECTL) delete -f $(MANIFESTS)/mongodb.yaml

# =============================================================================
# Redis (Official image, not Bitnami)
# =============================================================================

redis-up: namespace
	$(KUBECTL) apply -f $(MANIFESTS)/redis.yaml
	@echo "Waiting for Redis to be ready..."
	@$(KUBECTL) wait --for=condition=ready pod -l app=redis -n $(NAMESPACE) --timeout=600s

redis-down:
	-$(KUBECTL) delete -f $(MANIFESTS)/redis.yaml

# =============================================================================
# Strimzi / Kafka (still uses Helm - not affected by Bitnami changes)
# =============================================================================

strimzi-up:
	@$(KUBECTL) create namespace kafka --dry-run=client -o yaml | $(KUBECTL) apply -f -
	$(HELM) upgrade --install strimzi strimzi/strimzi-kafka-operator \
		--namespace kafka \
		--version 0.49.1 \
		--values k8s/helm/strimzi/operator/values.yaml \
		--wait

strimzi-down:
	-$(HELM) uninstall strimzi --namespace kafka

kafka-up: strimzi-up
	@echo "Waiting for Strimzi operator to be ready..."
	@$(KUBECTL) wait --for=condition=ready pod -l name=strimzi-cluster-operator -n kafka --timeout=600s
	$(KUBECTL) apply -f k8s/helm/strimzi/kafka-node-pool.yaml
	$(KUBECTL) apply -f k8s/helm/strimzi/kafka-cluster.yaml
	@echo "Waiting for Kafka to be ready..."
	@$(KUBECTL) wait --for=condition=ready pod -l strimzi.io/cluster=dev-kafka -n kafka --timeout=300s || true

kafka-down:
	-$(KUBECTL) delete -f k8s/helm/strimzi/kafka-cluster.yaml
	-$(KUBECTL) delete -f k8s/helm/strimzi/kafka-node-pool.yaml
	@echo "Kafka cluster removed. Run 'make strimzi-down' to also remove the operator."

# =============================================================================
# All Infrastructure
# =============================================================================

infra-up: postgres-up mongodb-up redis-up kafka-up
	@echo "All infrastructure services deployed"

infra-down: kafka-down mongodb-down redis-down postgres-down strimzi-down
	@echo "All infrastructure services removed"

infra-status:
	@echo "=== Pods in $(NAMESPACE) namespace ==="
	@$(KUBECTL) get pods -n $(NAMESPACE)
	@echo ""
	@echo "=== Pods in kafka namespace ==="
	@$(KUBECTL) get pods -n kafka
	@echo ""
	@echo "=== Services ==="
	@$(KUBECTL) get svc -n $(NAMESPACE)
	@$(KUBECTL) get svc -n kafka

# =============================================================================
# Port Forwarding
# =============================================================================

port-forward-postgres:
	@echo "Forwarding PostgreSQL to localhost:5432 (Ctrl+C to stop)"
	$(KUBECTL) port-forward svc/postgres 5432:5432 -n $(NAMESPACE)

port-forward-mongodb:
	@echo "Forwarding MongoDB to localhost:27017 (Ctrl+C to stop)"
	$(KUBECTL) port-forward svc/mongodb 27017:27017 -n $(NAMESPACE)

port-forward-redis:
	@echo "Forwarding Redis to localhost:6379 (Ctrl+C to stop)"
	$(KUBECTL) port-forward svc/redis 6379:6379 -n $(NAMESPACE)
