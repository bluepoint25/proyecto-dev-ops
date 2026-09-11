#!/usr/bin/env bash
# ─── Publicar el backend en ECS (guía 1.3.9) ────────────────────────────────
# Construye la imagen, la sube a ECR y fuerza un nuevo despliegue en ECS.
# Ejecutar desde la carpeta backend/ con las credenciales AWS activas.
set -euo pipefail

REGION="us-east-1"
CLUSTER="pedidos360-cluster"
SERVICIO="pedidos360-backend"

# La URL del ECR se obtiene de terraform output; se puede pasar por variable.
ECR_URL="${ECR_URL:-$(terraform -chdir=../terraform output -raw ecr_repositorio)}"
REGISTRY="${ECR_URL%%/*}"

echo "==> 1/4 Autenticando contra ECR"
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

echo "==> 2/4 Construyendo la imagen (linux/amd64)"
docker build --platform linux/amd64 -t "$ECR_URL:latest" .

echo "==> 3/4 Subiendo la imagen a ECR"
docker push "$ECR_URL:latest"

echo "==> 4/4 Redesplegando el servicio en ECS"
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICIO" \
  --force-new-deployment \
  --region "$REGION" >/dev/null

echo "==> Listo. La task nueva arrancará en 1-2 minutos."
