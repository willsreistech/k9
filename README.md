# K9 — laboratório Kubernetes com Kind

O K9 provisiona um cluster Kubernetes local com [Kind](https://kind.sigs.k8s.io/) em um host Linux. O ciclo de vida pode ser operado pelo terminal, GitHub Actions ou templates do Backstage.

O projeto foi pensado para estudo e desenvolvimento. Ele não substitui um cluster Kubernetes de produção.

## O que ele entrega

- Um control plane e dois workers.
- Kubernetes e imagens dos nodes fixados por versão e digest.
- API Server e NodePorts acessíveis apenas pelo host (`127.0.0.1`).
- Dados separados por cluster em `$HOME/.local/share/kind`.
- Namespace `lab-workloads` com Pod Security `restricted`, quota e limites padrão.
- NetworkPolicy default-deny, com uma exceção de saída para DNS.
- Health check agendado a cada seis horas.
- Templates de criação, remoção e status no Backstage.
- CI para scripts, YAML e dependências do GitHub Actions.

## Arquitetura

```text
Backstage ──dispatch──> GitHub Actions
                           │
                           v
                  runner self-hosted
                           │
                           v
                         Docker
                           │
          ┌────────────────┼────────────────┐
          v                v                v
   control-plane        worker-1         worker-2
          │
          └── localhost:6443 / 30000 / 30080 / 30443
```

## Pré-requisitos

- Ubuntu 22.04 ou 24.04.
- Docker, Kind e kubectl; `make deps` pode instalá-los com privilégios de root.
- Para automação, um runner com as labels `self-hosted` e `production`.
- O usuário operador deve ter acesso ao daemon Docker.

> Pertencer ao grupo `docker` equivale, na prática, a possuir privilégios elevados no host. Use um servidor dedicado ao laboratório.

## Uso local

```bash
# Instala/atualiza dependências e valida os downloads por SHA-256
make deps

# Cria o cluster e aplica o baseline
make create

# Configura o terminal atual
export KUBECONFIG="$HOME/.kube/config-lab-k8s"

# Exibe nodes e pods
make status

# Remove o cluster e preserva os dados
make delete

# Remove o cluster e os dados persistentes
make delete-data
```

Para usar outro nome:

```bash
CLUSTER_NAME=dev-cluster make create
CLUSTER_NAME=dev-cluster make status
CLUSTER_NAME=dev-cluster make delete
```

Nomes aceitam apenas letras minúsculas, números e hifens. `DATA_ROOT` permite trocar a raiz de persistência:

```bash
DATA_ROOT=/caminho/dedicado CLUSTER_NAME=dev-cluster make create
```

## Namespace para workloads

Use `lab-workloads` para os exercícios:

```bash
kubectl -n lab-workloads apply -f minha-aplicacao.yaml
kubectl -n lab-workloads get resourcequota,limitrange,networkpolicy
```

A política de rede bloqueia tráfego por padrão. Cada aplicação deve declarar explicitamente o ingresso e a saída de que precisa. A CNI padrão do Kind pode não aplicar NetworkPolicy; para enforcement real, instale uma CNI compatível, como Calico ou Cilium, e desative `kindnet` na configuração.

## Portas

| Porta no host | Finalidade |
|---:|---|
| `6443` | API Server Kubernetes |
| `30080` | NodePort HTTP |
| `30443` | NodePort HTTPS |
| `30000` | NodePort genérico |

Todas escutam somente em `127.0.0.1`. Para acesso remoto, prefira VPN ou túnel SSH:

```bash
ssh -L 6443:127.0.0.1:6443 usuario@servidor
```

## GitHub Actions

Os workflows manuais ficam em **Actions → Run workflow**:

| Workflow | Função |
|---|---|
| Setup Kind Cluster | Cria o cluster e aplica o baseline |
| Teardown Kind Cluster | Remove o cluster |
| Cluster Status | Valida API Server, nodes e pods |
| Validate | Executa lint em scripts e YAML |
| TechDocs | Publica esta documentação no Backstage |

As dependências devem ser previamente instaladas no runner. O input `install_dependencies` do setup existe para bootstrap e fica desativado por padrão, pois executa o instalador com `sudo`.

Os workflows usam um grupo global de concorrência para evitar setup, status e teardown simultâneos. Como as portas do host são fixas, mantenha apenas um destes clusters ativo por host. Se houver vários runners, use a label `production` somente no host que possui o cluster.

## Backstage

- `catalog-info.yaml` registra o componente e o TechDocs.
- `backstage/create-cluster-template.yaml` contém templates de criação, remoção e status.
- Os templates disparam os mesmos workflows usados pela operação manual.

## Atualização de versões

As versões ficam em `versions.env`. Ao atualizar o Kind:

1. Consulte as release notes oficiais.
2. Escolha uma imagem `kindest/node` publicada para essa versão.
3. Copie a referência completa, incluindo `@sha256:`.
4. Atualize Kind, kubectl e imagem em conjunto.
5. Execute `make validate` e crie um cluster de teste.

## Estrutura

```text
.
├── .github/workflows/       # Automação e validações
├── backstage/               # Templates do Scaffolder
├── docs/                    # Entrada do TechDocs
├── kind/                    # Template de configuração do cluster
├── manifests/               # Baseline declarativo do Kubernetes
├── scripts/                 # Instalação e ciclo de vida
├── catalog-info.yaml        # Componente do catálogo
├── Makefile                 # Comandos operacionais
├── mkdocs.yml               # Configuração do TechDocs
└── versions.env             # Versões testadas
```

## Solução de problemas

Cluster já existe:

```bash
kind get clusters
make delete
make create
```

Permissão negada no Docker:

```bash
docker info
groups
```

Após entrar no grupo `docker`, encerre e abra a sessão novamente.

Para diagnóstico:

```bash
export KUBECONFIG="$HOME/.kube/config-lab-k8s"
kubectl cluster-info dump
kubectl get events -A --sort-by=.lastTimestamp
docker ps --filter label=io.x-k8s.kind.cluster=lab-k8s
```

## Segurança e limitações

- Não exponha o Docker socket nem as portas do cluster diretamente à internet.
- Proteja a branch principal e limite quem pode executar workflows no runner.
- O armazenamento local não possui alta disponibilidade nem backup automático.
- O Kind usa containers como nodes; falhas do host afetam todo o cluster.
- O teardown preserva dados por padrão para evitar perda acidental.

## Licença

Uso interno e educacional. Adicione um arquivo `LICENSE` caso o projeto seja distribuído publicamente.
