terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.15"
    }
  }

  # Configuração parcial: bucket e região vêm de -backend-config no CI
  # (ver .github/workflows/terraform.yml e bootstrap/README.md).
  # use_lockfile usa o lock nativo do S3 — dispensa a tabela DynamoDB.
  backend "s3" {
    key          = "infra-k8s/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
