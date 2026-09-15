terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.64"
    }
  }

  backend "s3" {
    key          = "infra-k8s/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
