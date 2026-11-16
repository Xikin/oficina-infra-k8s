resource "aws_ecr_repository" "api" {
  name                 = "${local.name}-api"
  image_tag_mutability = "MUTABLE"

  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = { Name = "${local.name}-api" }
}

resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Manter apenas as 15 imagens mais recentes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 15
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_ssm_parameter" "ecr_api_repository_url" {
  name        = "${local.ssm_prefix}/ecr/api_repository_url"
  description = "Repositório ECR da imagem da API; lido pelo pipeline de oficina-mvp"
  type        = "String"
  value       = aws_ecr_repository.api.repository_url
}

output "ecr_api_repository_url" {
  description = "URL do repositório ECR da API"
  value       = aws_ecr_repository.api.repository_url
}

resource "aws_ecr_repository" "servico" {
  for_each = toset(var.servicos_adicionais)

  name                 = "${local.name}-${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = { Name = "${local.name}-${each.key}" }
}

resource "aws_ecr_lifecycle_policy" "servico" {
  for_each   = aws_ecr_repository.servico
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Manter apenas as 15 imagens mais recentes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 15
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_ssm_parameter" "ecr_servico_repository_url" {
  for_each    = aws_ecr_repository.servico
  name        = "${local.ssm_prefix}/ecr/${each.key}_repository_url"
  description = "Repositório ECR da imagem do serviço ${each.key}; lido pelo pipeline do repositório oficina-${each.key}"
  type        = "String"
  value       = each.value.repository_url
}

output "ecr_servicos_repository_urls" {
  description = "URLs dos repositórios ECR dos serviços adicionais da Fase 4"
  value       = { for k, r in aws_ecr_repository.servico : k => r.repository_url }
}
