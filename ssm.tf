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

resource "aws_ssm_parameter" "api_endpoint" {
  name        = "${local.ssm_prefix}/api/endpoint"
  description = "Hostname do Load Balancer da API; preenchido pelo deploy de oficina-mvp"
  type        = "String"
  value       = "pendente-primeiro-deploy.invalid"

  lifecycle {
    ignore_changes = [value]
  }
}
