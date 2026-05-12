CLUSTER_NAME ?= lab-k8s
export CLUSTER_NAME

.PHONY: help deps create delete status kubeconfig

help: ## Mostra esta ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

deps: ## Instala Docker, Kind e kubectl (requer sudo)
	sudo bash scripts/install-deps.sh

create: ## Cria o cluster Kind
	bash scripts/setup-cluster.sh

delete: ## Remove o cluster Kind
	bash scripts/teardown-cluster.sh

status: ## Exibe status do cluster
	@export KUBECONFIG="$$HOME/.kube/config-$(CLUSTER_NAME)"; \
	echo "=== Nodes ==="; kubectl get nodes -o wide; \
	echo ""; echo "=== Pods (all namespaces) ==="; kubectl get pods -A

kubeconfig: ## Exibe o comando para setar o KUBECONFIG
	@echo "export KUBECONFIG=$$HOME/.kube/config-$(CLUSTER_NAME)"

recreate: delete create ## Recria o cluster do zero
