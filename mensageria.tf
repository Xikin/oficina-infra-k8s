resource "random_password" "rabbitmq" {
  length  = 32
  special = false
}

resource "random_password" "rabbitmq_cookie" {
  length  = 48
  special = false
}

locals {
  rabbitmq_host = "rabbitmq.plataforma.svc.cluster.local"
}

resource "aws_ssm_parameter" "rabbitmq_password" {
  name        = "${local.ssm_prefix}/mensageria/rabbitmq_password"
  description = "Senha do usuário da aplicação no RabbitMQ; usada pelo pipeline deste repositório para criar o Secret do broker"
  type        = "SecureString"
  value       = random_password.rabbitmq.result
}

resource "aws_ssm_parameter" "rabbitmq_cookie" {
  name        = "${local.ssm_prefix}/mensageria/rabbitmq_erlang_cookie"
  description = "Erlang cookie do RabbitMQ"
  type        = "SecureString"
  value       = random_password.rabbitmq_cookie.result
}

resource "aws_ssm_parameter" "rabbitmq_url" {
  name        = "${local.ssm_prefix}/mensageria/rabbitmq_url"
  description = "URL AMQP do broker dentro do cluster; lida pelos pipelines dos três microsserviços"
  type        = "SecureString"
  value       = "amqp://${var.rabbitmq_usuario}:${random_password.rabbitmq.result}@${local.rabbitmq_host}:5672"
}

output "rabbitmq_host" {
  description = "Endereço do RabbitMQ dentro do cluster"
  value       = local.rabbitmq_host
}
