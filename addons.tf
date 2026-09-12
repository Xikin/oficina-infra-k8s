# ---------------------------------------------------------------------------
# metrics-server
#
# O HPA da aplicação declara métricas de CPU e memória (autoscaling/v2). Sem o
# metrics-server o HPA fica com targets "<unknown>" e NUNCA escala — era
# exatamente essa a lacuna do cluster Kind da Fase 2.
#
# Instalado como addon gerenciado do EKS, e não via Helm. A diferença não é
# só estética: com Helm, o Terraform precisa falar direto com o API server do
# cluster, o que exige rota IPv4 até ele. Como addon, a instalação passa pela
# API do EKS — mesma credencial e mesmo caminho de rede das demais chamadas
# AWS — e a AWS cuida da compatibilidade de versão com o control plane.
# ---------------------------------------------------------------------------

resource "aws_eks_addon" "metrics_server" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "metrics-server"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # Precisa de nós para agendar os pods, e de DNS e rede de pods funcionando
  # para ficar ACTIVE.
  depends_on = [
    aws_eks_node_group.this,
    aws_eks_addon.coredns,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy,
  ]
}
