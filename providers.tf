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

data "aws_caller_identity" "current" {}

data "aws_iam_role" "lab" {
  name = var.lab_role_name
}

locals {
  name = "${var.project}-${var.environment}"
}
