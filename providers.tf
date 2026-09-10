provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "oficina-infra-k8s"
    }
  }
}

# Autentica no cluster com token efêmero do STS em vez de kubeconfig em disco:
# funciona igual na máquina do dev e no runner do GitHub Actions.
provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.this.name, "--region", var.region]
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_iam_role" "lab" {
  name = var.lab_role_name
}

locals {
  name = "${var.project}-${var.environment}"
}
