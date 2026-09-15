# Notas de implementação

O código deste repositório não tem comentários. O que não dá para deduzir lendo o código — o porquê de uma
escolha, restrições externas, contratos com os outros repositórios — fica registrado aqui, organizado por
arquivo.

---

## `vpc.tf`

Duas camadas de subnet, ambas sem NAT Gateway:

| Subnets | Recebem |
| --- | --- |
| públicas | nós do EKS e o Network Load Balancer da API |
| privadas | RDS (oficina-infra-db) e a Lambda de autenticação |

- Sem NAT porque um NAT Gateway custa ~US$1,10/dia, o que sozinho consome boa parte do crédito do Learner Lab. As
  subnets privadas não precisam de saída para a internet: o RDS não faz chamadas externas, e a Lambda só conversa
  com o RDS, recebendo os segredos por variável de ambiente
  ([ADR-0006 em oficina-auth-lambda](https://github.com/Xikin/oficina-auth-lambda/blob/main/docs/adr/0006-segredos-da-lambda.md)).
- A route table privada não tem rota default: o tráfego das subnets privadas não sai da VPC.
- `enable_dns_hostnames` é exigido pelo EKS e pelo endpoint DNS do RDS.
- A tag `kubernetes.io/role/elb` nas subnets públicas sinaliza ao controlador de serviço do Kubernetes onde publicar
  Services do tipo LoadBalancer voltados para a internet.

## `eks.tf`

- No AWS Academy Learner Lab não é possível criar IAM roles, então tanto o cluster role quanto o node role apontam
  para a LabRole pré-existente, que já tem trust para `eks.amazonaws.com` e `ec2.amazonaws.com`. Numa conta AWS
  normal, isso violaria o menor privilégio ([ADR-0005](adr/0005-restricoes-aws-academy.md)).
- `bootstrap_cluster_creator_admin_permissions`: quem roda o apply vira admin do cluster automaticamente. No
  Learner Lab o principal é sempre o mesmo (voclabs), então dev e CI compartilham acesso.
- A faixa de `scaling_config` do node group é o que dá lastro real ao HPA da aplicação: o HPA cria pods; o
  autoscaling do node group cria as instâncias que os hospedam. Depois do bootstrap, quem manda no número de nós é
  o autoscaling, e não o Terraform — por isso `desired_size` fica em `ignore_changes`.
- O node group depende explicitamente do cluster porque falha se o control plane ainda estiver estabilizando.
- Os addons gerenciados VPC CNI e kube-proxy são obrigatórios: sem eles, os nós não entram Ready.

## `addons.tf`

O metrics-server é instalado como addon gerenciado do EKS, e não via Helm: com Helm, o Terraform precisaria falar
direto com o API server do cluster, o que exige rota IPv4 até ele. Como addon, a instalação passa pela API do EKS —
mesma credencial e mesmo caminho de rede das demais chamadas AWS —, e a AWS cuida da compatibilidade de versão com o
control plane.

O addon depende dos nós, para agendar os pods, e de DNS e rede de pods funcionando (CoreDNS, VPC CNI, kube-proxy)
para ficar ACTIVE.

## `ecr.tf`

- Com ECR na mesma conta, os nós puxam a imagem com a própria role (LabRole), sem `imagePullSecret`. Um pull secret
  criado com token de curta duração expira e quebra o pull justamente dos pods agendados em nós novos durante a
  escala.
- `force_delete`: no laboratório, destruir a stack é rotina; sem isso, o destroy falha enquanto houver imagens no
  repositório.
- A lifecycle policy guarda as 15 imagens mais recentes; o resto só ocupa storage cobrado.

## `ssm.tf`

Contrato entre repositórios. Em vez de `terraform_remote_state` (que exigiria dar acesso ao state de um repositório
para os outros), os identificadores são publicados no SSM Parameter Store, e os demais repositórios os leem com data
sources.

| Consumidor | Parâmetros |
| --- | --- |
| oficina-infra-db | lê `vpc_id`, `private_subnet_ids`, `node_security_group_id` |
| oficina-auth-lambda | lê `private_subnet_ids` e `api/endpoint` |
| oficina-mvp | lê `cluster_name` e `ecr/api_repository_url`; escreve `api/endpoint` |

- `node_security_group_id` é o SG que o EKS anexa a todos os nós — a origem que o RDS libera no ingress.
- `api/endpoint` é o endereço público do Load Balancer que o Service da API cria no cluster. É criado aqui com um
  placeholder e **sobrescrito** pelo pipeline de deploy de oficina-mvp, que só descobre o DNS depois que o
  Kubernetes provisiona o balanceador — por isso `ignore_changes = [value]`. Existir desde já permite que o API
  Gateway (oficina-auth-lambda) leia o parâmetro sem falhar por ordem de aplicação; até o primeiro deploy da API, a
  rota de proxy responde erro, o que se corrige sozinho.

## `versions.tf`

O backend S3 usa configuração parcial: bucket e região vêm de `-backend-config` no CI
(`.github/workflows/terraform.yml`) e no uso local (`bootstrap/backend.sh` imprime o comando). `use_lockfile` usa o
lock nativo do S3, o que dispensa a tabela DynamoDB.

## `bootstrap/backend.sh`

Cria o bucket S3 que guarda o state remoto das três stacks Terraform. Rode **uma vez**, antes do primeiro
`terraform init` de qualquer repositório. É idempotente: se o bucket já existe, não faz nada.

```bash
./bootstrap/backend.sh
./bootstrap/backend.sh us-east-1 meu-bucket-de-state
```

- O lock de state usa o mecanismo nativo do S3 (`use_lockfile`), então não é preciso criar tabela DynamoDB.
- `us-east-1` é a única região que rejeita `LocationConstraint`, por isso o `create-bucket` tem dois ramos.
- O versionamento do bucket permite recuperar um state corrompido por apply interrompido — no Learner Lab a sessão
  cai a cada 4h, então isso não é hipotético.

## `terraform.tfvars.example`

Copie para `terraform.tfvars` e ajuste. Todos os valores têm default sensato para o AWS Academy Learner Lab — na
prática, só é preciso mexer para ter um cluster maior ou usar outra região.

| Variável | Observação |
| --- | --- |
| `environment` | `prod` ou `homolog` |
| `lab_role_name` | O Learner Lab não permite criar IAM roles — `LabRole` já existe na conta |
| `node_instance_types` | `t3.small` = 2 vCPU / 2 GiB. Dois nós comportam as 2 réplicas mínimas do HPA com folga; o autoscaling sobe até `node_max_size` sob carga |
| `node_capacity_type` | Troque para `SPOT` para economizar ~70% nos nós |
| `extra_cluster_admin_arns` | Preencha apenas se o pipeline autenticar com um principal diferente do seu |

## `.gitignore`

- `terraform.tfvars` carrega valores específicos do ambiente e, eventualmente, segredos: o `.example` é versionado;
  o real, não. O plano salvo por `terraform plan -out` também é ignorado.
- O `.terraform.lock.hcl` **é** versionado de propósito: garante que CI e devs resolvam exatamente as mesmas versões
  de providers.

## CI — `.github/workflows/terraform.yml`

- `aws-session-token` é obrigatório: o Learner Lab entrega credenciais temporárias, que expiram junto com a sessão
  de 4h do lab.
- A integração Kubernetes do New Relic (CPU, memória, pods, nós e eventos do cluster) é instalada pelo pipeline, e
  não pelo Terraform, porque é o runner do GitHub que alcança o API server do EKS. Não bloqueia a infraestrutura:
  sem `NEW_RELIC_LICENSE_KEY`, é ignorada; se falhar, vira aviso. `global.lowDataMode=true` reduz a ingestão para
  caber com folga nos 100 GB gratuitos.
- `newrelic-logging.enabled=false`: os logs da API já chegam pelo agente New Relic de dentro da aplicação, com
  `trace.id` e `span.id`. O coletor de logs do cluster enviaria cada linha uma segunda vez, e os painéis que contam
  eventos (volume diário, funil de status) mostrariam o dobro.
- O resumo do cluster usa `terraform-bin` em vez de `terraform`: o wrapper do `setup-terraform` (necessário para
  comentar o plan no PR) acrescenta linhas extras à saída capturada por `$(terraform output)`.
- As actions são fixadas por SHA de commit, com a versão legível no comentário `# vX.Y.Z` ao lado de cada `uses:`.
  O `.github/dependabot.yml` mantém os SHAs atualizados; sem ele, o pin congelaria as actions para sempre.
