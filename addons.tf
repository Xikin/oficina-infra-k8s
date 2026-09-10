# ---------------------------------------------------------------------------
# metrics-server
#
# O HPA da aplicação declara métricas de CPU e memória (autoscaling/v2). Sem o
# metrics-server o HPA fica com targets "<unknown>" e NUNCA escala — era
# exatamente essa a lacuna do cluster Kind da Fase 2. Não existe addon
# gerenciado do EKS para ele, então instalamos via Helm.
# ---------------------------------------------------------------------------

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.12.2"
  namespace  = "kube-system"

  # Espera os pods ficarem prontos para que um apply bem-sucedido signifique
  # de fato "HPA operante".
  wait    = true
  timeout = 600

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }

  depends_on = [
    aws_eks_node_group.this,
    aws_eks_addon.coredns,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy,
  ]
}
