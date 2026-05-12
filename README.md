# labsk8 — Kubernetes Lab com Kind

Cluster Kubernetes de laboratório usando **Kind** (Kubernetes in Docker) em Ubuntu 22.04/24.04, com automação via **GitHub Actions** rodando no seu self-hosted runner.

## 🗂️ Estrutura

```
labsk8/
├── .github/workflows/
│   ├── setup-cluster.yml     # Cria o cluster
│   ├── teardown-cluster.yml  # Remove o cluster
│   └── cluster-status.yml    # Health check (a cada 6h)
├── kind/
│   └── cluster-config.yaml   # Topologia: 1 control-plane + 2 workers
├── scripts/
│   ├── install-deps.sh       # Instala Docker + Kind + kubectl
│   ├── setup-cluster.sh      # Cria o cluster Kind
│   └── teardown-cluster.sh   # Remove o cluster Kind
└── Makefile                  # Atalhos para comandos comuns
```

## 🚀 Pré-requisitos no servidor

- Ubuntu 22.04 ou 24.04
- GitHub Actions **self-hosted runner** instalado e online
- Sudo sem senha para o usuário do runner (ou ajuste conforme necessário)

## ⚡ Uso rápido (via terminal no servidor)

```bash
# 1. Instalar Docker, Kind e kubectl
make deps

# 2. Criar o cluster (1 control-plane + 2 workers)
make create

# 3. Verificar status
make status

# 4. Configurar KUBECONFIG na sessão atual
$(make kubeconfig)

# 5. Remover cluster
make delete
```

## 🤖 Uso via GitHub Actions

Os workflows ficam disponíveis em **Actions → Run workflow**:

| Workflow | O que faz |
|---|---|
| `Setup Kind Cluster` | Instala tudo e cria o cluster |
| `Teardown Kind Cluster` | Remove o cluster |
| `Cluster Status` | Mostra health dos nodes/pods |

## 🌐 Portas expostas

| Porta host | Uso |
|---|---|
| `30080` | HTTP via NodePort |
| `30443` | HTTPS via NodePort |
| `30000` | Porta genérica NodePort |
| `6443`  | API Server Kubernetes |

## 🔧 Topologia do cluster

```
control-plane  (kindest/node)
worker-1       (kindest/node)
worker-2       (kindest/node)
```

CNI padrão: **kindnet**. Para trocar por Calico ou Cilium, edite `kind/cluster-config.yaml` e defina `disableDefaultCNI: true`.

## 📁 Persistência

O diretório `/tmp/kind-data` do host é montado em `/data` em todos os nodes.  
Altere `hostPath` em `kind/cluster-config.yaml` para usar outro caminho.
