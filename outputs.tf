output "cluster_name" {
  description = "Nome do cluster EKS (use em: aws eks update-kubeconfig --name <valor>)"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Endpoint do API server do cluster"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "Versão do Kubernetes em execução no control plane"
  value       = aws_eks_cluster.this.version
}

output "vpc_id" {
  description = "VPC compartilhada por todas as stacks da oficina"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Subnets públicas — nós do EKS e load balancers voltados para a internet"
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  description = "Subnets privadas — RDS e Lambda de autenticação"
  value       = [for s in aws_subnet.private : s.id]
}

output "node_security_group_id" {
  description = "Security group dos nós; o RDS libera ingresso na 5432 a partir dele"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "update_kubeconfig_command" {
  description = "Comando pronto para apontar o kubectl local para este cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.this.name}"
}
