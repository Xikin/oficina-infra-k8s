#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Cria o bucket S3 que guarda o state remoto das três stacks Terraform.
#
# Rode UMA VEZ, antes do primeiro `terraform init` de qualquer repositório.
# É idempotente: se o bucket já existe, não faz nada.
#
# O lock de state usa o mecanismo nativo do S3 (use_lockfile), então não é
# preciso criar tabela DynamoDB.
#
#   ./bootstrap/backend.sh
#   ./bootstrap/backend.sh us-east-1 meu-bucket-de-state
# ---------------------------------------------------------------------------
set -euo pipefail

REGION="${1:-${AWS_REGION:-us-east-1}}"

if ! ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)"; then
  echo "ERRO: credenciais AWS ausentes ou expiradas." >&2
  echo "No Learner Lab, copie o bloco 'AWS CLI' de AWS Details para ~/.aws/credentials." >&2
  exit 1
fi

BUCKET="${2:-oficina-tfstate-${ACCOUNT_ID}}"

echo "Conta:  ${ACCOUNT_ID}"
echo "Região: ${REGION}"
echo "Bucket: ${BUCKET}"

if aws s3api head-bucket --bucket "${BUCKET}" 2>/dev/null; then
  echo "Bucket já existe — nada a fazer."
else
  # us-east-1 é a única região que rejeita LocationConstraint.
  if [ "${REGION}" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}"
  else
    aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}" \
      --create-bucket-configuration "LocationConstraint=${REGION}"
  fi
  echo "Bucket criado."
fi

# Versionamento permite recuperar um state corrompido por apply interrompido —
# no Learner Lab a sessão cai a cada 4h, então isso não é hipotético.
aws s3api put-bucket-versioning \
  --bucket "${BUCKET}" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket "${BUCKET}" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-public-access-block \
  --bucket "${BUCKET}" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

cat <<EOF

Pronto. Guarde o nome do bucket como secret TF_STATE_BUCKET nos quatro repositórios.

Para inicializar localmente:

  terraform init \\
    -backend-config="bucket=${BUCKET}" \\
    -backend-config="region=${REGION}"
EOF
