# ---------------------------------------------------------------------------
# Contrato entre repositórios
#
# Este é o único ponto de acoplamento entre as quatro stacks. Em vez de
# terraform_remote_state (que exigiria dar acesso ao state de um repo para os
# outros), publicamos os identificadores em SSM Parameter Store e os demais
# repositórios leem com data sources.
#
#   oficina-infra-db     -> lê vpc_id, private_subnet_ids, node_security_group_id
#   oficina-auth-lambda  -> lê private_subnet_ids, vpc_id
#   oficina-mvp (API)    -> lê cluster_name no deploy
# ---------------------------------------------------------------------------

locals {
  ssm_prefix = "/${var.project}/${var.environment}"
}

resource "aws_ssm_parameter" "vpc_id" {
  name  = "${local.ssm_prefix}/network/vpc_id"
  type  = "String"
  value = aws_vpc.this.id
}

resource "aws_ssm_parameter" "public_subnet_ids" {
  name  = "${local.ssm_prefix}/network/public_subnet_ids"
  type  = "StringList"
  value = join(",", [for s in aws_subnet.public : s.id])
}

resource "aws_ssm_parameter" "private_subnet_ids" {
  name  = "${local.ssm_prefix}/network/private_subnet_ids"
  type  = "StringList"
  value = join(",", [for s in aws_subnet.private : s.id])
}

# SG que o EKS anexa a todos os nós — é a origem que o RDS libera no ingress.
resource "aws_ssm_parameter" "node_security_group_id" {
  name  = "${local.ssm_prefix}/eks/node_security_group_id"
  type  = "String"
  value = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

resource "aws_ssm_parameter" "cluster_name" {
  name  = "${local.ssm_prefix}/eks/cluster_name"
  type  = "String"
  value = aws_eks_cluster.this.name
}

resource "aws_ssm_parameter" "cluster_endpoint" {
  name  = "${local.ssm_prefix}/eks/cluster_endpoint"
  type  = "String"
  value = aws_eks_cluster.this.endpoint
}

# Endereço público do Load Balancer que o Service da API cria no cluster.
#
# Criado aqui com placeholder e SOBRESCRITO pelo pipeline de deploy da
# aplicação (oficina-mvp), que só descobre o DNS depois que o Kubernetes
# provisiona o balanceador. Existir desde já permite que o API Gateway
# (oficina-auth-lambda) leia o parâmetro sem falhar por ordem de aplicação —
# até o primeiro deploy da API, a rota de proxy responde erro, o que é
# autoexplicativo e se corrige sozinho.
resource "aws_ssm_parameter" "api_endpoint" {
  name        = "${local.ssm_prefix}/api/endpoint"
  description = "Hostname do Load Balancer da API; preenchido pelo deploy de oficina-mvp"
  type        = "String"
  value       = "pendente-primeiro-deploy.invalid"

  lifecycle {
    ignore_changes = [value]
  }
}
