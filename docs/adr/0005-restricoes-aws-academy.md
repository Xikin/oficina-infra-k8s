# ADR-0005: Operar dentro das restrições do AWS Academy Learner Lab

**Status:** Aceita
**Data:** 2026-09-09
**Contexto de uso:** todas as stacks Terraform da Fase 3

## Contexto

A Fase 3 exige infraestrutura real em nuvem provisionada por Terraform. A conta
disponível é um **AWS Academy Learner Lab**, que impõe limites que não existem numa
conta AWS comum e que moldam a arquitetura inteira:

1. **`iam:CreateRole` é negado.** Não é possível criar roles de execução para EKS,
   node group ou Lambda. A conta traz uma role pré-provisionada, `LabRole`, com
   política ampla e trust para os principais serviços.
2. **Credenciais temporárias de 4 horas.** O trio
   `aws_access_key_id` / `aws_secret_access_key` / `aws_session_token` é rotacionado
   a cada nova sessão do lab. Não existe usuário IAM de longa duração, logo **não é
   possível usar OIDC federado** entre GitHub Actions e AWS.
3. **Crédito limitado** (na faixa de US$50–100) e recursos são desligados quando a
   sessão do lab encerra.
4. **Catálogo de serviços e tipos de instância restrito** — família `t3` até
   `t3.medium`, região `us-east-1`.

## Decisão

Aceitamos as restrições e as tornamos explícitas no código, em vez de contorná-las:

- **`LabRole` como cluster role, node role e execution role da Lambda**, sempre
  atrás de uma variável (`lab_role_name`) com default `"LabRole"`. Trocar por roles
  dedicadas numa conta normal é mudar um valor de variável, não reescrever a stack.
- **Credenciais estáticas como secrets do GitHub**, com um passo de
  `aws sts get-caller-identity` no início de todo pipeline que falha com mensagem
  acionável quando o token expirou. Sem isso, a falha apareceria mais tarde como um
  erro obscuro do Terraform.
- **Nenhum NAT Gateway** e nenhum VPC Endpoint de interface. São os dois maiores
  custos fixos de uma VPC e nenhum é necessário para este desenho
  (ver [ADR-0006](https://github.com/Xikin/oficina-auth-lambda/blob/main/docs/adr/0006-segredos-da-lambda.md)).
- **`terraform destroy` como operação rotineira**, documentada no README e exposta
  como `workflow_dispatch`, para preservar crédito entre sessões de estudo.

## Consequências

**Positivas**
- A stack roda de ponta a ponta na conta que o curso fornece, sem pedir cartão.
- As restrições ficam documentadas no código, não no conhecimento tácito do grupo.

**Negativas**
- `LabRole` é amplamente permissiva: o desenho **não demonstra menor privilégio**.
  Numa entrega corporativa isso seria um achado de segurança.
- Os secrets do GitHub precisam ser atualizados manualmente a cada sessão do lab.
  É a fonte mais provável de pipeline vermelho neste projeto.
- Sem OIDC, o repositório guarda credenciais de acesso — mitigado por serem
  temporárias e de escopo de laboratório.

## Reavaliar se

O projeto migrar para uma conta AWS própria. Nesse caso: criar roles dedicadas por
serviço, trocar os secrets estáticos por `aws-actions/configure-aws-credentials` com
`role-to-assume` via OIDC, e reavaliar NAT/VPC Endpoints com o orçamento real.
