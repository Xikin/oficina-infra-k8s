variable "region" {
  description = "Região AWS. O AWS Academy Learner Lab só libera us-east-1 (e us-west-2 em alguns labs)."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Prefixo aplicado ao nome de todos os recursos"
  type        = string
  default     = "oficina"
}

variable "environment" {
  description = "Ambiente lógico desta stack (homolog ou prod)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["homolog", "prod"], var.environment)
    error_message = "environment deve ser 'homolog' ou 'prod'."
  }
}

variable "vpc_cidr" {
  description = "CIDR da VPC dedicada da oficina"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Zonas de disponibilidade. O EKS exige subnets em pelo menos duas."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.azs) >= 2
    error_message = "O EKS exige no mínimo duas zonas de disponibilidade."
  }
}

variable "kubernetes_version" {
  description = "Versão do Kubernetes do control plane do EKS"
  type        = string
  default     = "1.31"
}

variable "lab_role_name" {
  description = <<-EOT
    Role pré-existente usada como cluster role e node role.
    O AWS Academy Learner Lab NÃO permite criar IAM roles — 'LabRole' já vem
    provisionada na conta com trust para eks.amazonaws.com e ec2.amazonaws.com.
    Numa conta AWS normal, troque por uma role própria com as policies do EKS.
  EOT
  type        = string
  default     = "LabRole"
}

variable "node_instance_types" {
  description = "Tipos de instância do managed node group (o Learner Lab limita a família t3 até t3.medium)"
  type        = list(string)
  default     = ["t3.small"]
}

variable "node_capacity_type" {
  description = "ON_DEMAND ou SPOT"
  type        = string
  default     = "ON_DEMAND"
}

variable "node_desired_size" {
  description = "Quantidade inicial de nós"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Mínimo de nós do autoscaling do node group"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Máximo de nós — é o que dá lastro real ao maxReplicas do HPA da aplicação"
  type        = number
  default     = 4
}

variable "extra_cluster_admin_arns" {
  description = <<-EOT
    ARNs adicionais que recebem acesso administrativo ao cluster via EKS Access Entry.
    Quem roda o apply já vira admin por bootstrap_cluster_creator_admin_permissions;
    use esta lista se o pipeline autenticar com um principal diferente do seu.
  EOT
  type        = list(string)
  default     = []
}
