# ---------------------------------------------------------------------------
# Registro de imagens da API
#
# Substitui o GHCR usado na Fase 2. O motivo é um defeito real, não
# preferência: o pipeline criava o imagePullSecret do GHCR com o
# GITHUB_TOKEN, que expira ao fim do job. Quando o HPA ou o autoscaling de
# nós agendava um pod num nó novo depois disso, o pull falhava com
# ImagePullBackOff — justamente no momento em que a escala era necessária.
#
# Com ECR na mesma conta, os nós puxam a imagem com a própria role
# (LabRole), sem segredo nenhum no cluster.
# ---------------------------------------------------------------------------

resource "aws_ecr_repository" "api" {
  name                 = "${local.name}-api"
  image_tag_mutability = "MUTABLE"

  # No laboratório, destruir a stack é rotina; sem isto o destroy falha
  # enquanto houver imagens no repositório.
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = { Name = "${local.name}-api" }
}

# Guarda as 15 imagens mais recentes; o resto só ocupa storage cobrado.
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
