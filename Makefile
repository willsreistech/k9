CLUSTER_NAME ?= lab-k8s
export CLUSTER_NAME

.PHONY: help deps create delete delete-data status kubeconfig baseline validate

help: ## Mostra esta ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

deps: ## Instala Kind e kubectl; Docker deve existir para uso sem root
	bash scripts/install-deps.sh

create: ## Cria o cluster Kind
	bash scripts/setup-cluster.sh

delete: ## Remove o cluster Kind
	bash scripts/teardown-cluster.sh

delete-data: ## Remove o cluster e seus dados persistentes
	DELETE_DATA=true bash scripts/teardown-cluster.sh

status: ## Exibe status do cluster
	@KUBECONFIG="$$HOME/.kube/config-$(CLUSTER_NAME)" kubectl get nodes -o wide
	@KUBECONFIG="$$HOME/.kube/config-$(CLUSTER_NAME)" kubectl get pods -A

kubeconfig: ## Exibe o comando para setar o KUBECONFIG
	@echo "export KUBECONFIG=$$HOME/.kube/config-$(CLUSTER_NAME)"

baseline: ## Reaplica quotas e politicas do namespace de laboratorio
	KUBECONFIG="$$HOME/.kube/config-$(CLUSTER_NAME)" kubectl apply -f manifests/platform-baseline.yaml

recreate: delete create ## Recria o cluster do zero

validate: ## Valida sintaxe dos scripts e arquivos basicos
	bash -n scripts/*.sh
	@command -v shellcheck >/dev/null && shellcheck scripts/*.sh || echo "shellcheck nao instalado; etapa ignorada"
