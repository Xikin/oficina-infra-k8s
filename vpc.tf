# ---------------------------------------------------------------------------
# Rede
#
# Duas camadas de subnet, ambas sem NAT Gateway:
#   públicas  -> nós do EKS e o Network Load Balancer da API
#   privadas  -> RDS (repo oficina-infra-db) e a Lambda de autenticação
#
# Por que sem NAT: um NAT Gateway custa ~US$1,10/dia, o que sozinho consome
# boa parte do crédito do Learner Lab. As subnets privadas não precisam de
# saída para a internet — o RDS não faz chamadas externas e a Lambda só
# conversa com o RDS, recebendo os segredos por variável de ambiente
# (ver ADR-0006 no repositório oficina-auth-lambda).
# ---------------------------------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true # exigido pelo EKS e pelo endpoint DNS do RDS

  tags = { Name = "${local.name}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-igw" }
}

resource "aws_subnet" "public" {
  for_each = { for idx, az in var.azs : az => idx }

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, each.value)
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name}-public-${each.key}"
    # Sinaliza ao controlador de serviço do Kubernetes onde publicar
    # Services do tipo LoadBalancer voltados para a internet.
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "private" {
  for_each = { for idx, az in var.azs : az => idx }

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, each.value + length(var.azs))

  tags = {
    Name                              = "${local.name}-private-${each.key}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = { Name = "${local.name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Sem rota default: o tráfego das subnets privadas não sai da VPC.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-private-rt" }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
