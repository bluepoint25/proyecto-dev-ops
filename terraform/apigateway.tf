# ─── HTTP API ─────────────────────────────────────────────────────────────────
resource "aws_apigatewayv2_api" "api" {
  name          = "${var.grupo}-api"
  protocol_type = "HTTP"

  cors_configuration {
    # Sin barra final: el origen del navegador nunca la lleva
    allow_origins = [
      "http://localhost:5173",
      local.url_amplify,
    ]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["content-type", "authorization"]
    max_age       = 300
  }
}

# ─── JWT AUTHORIZER (usa Cognito como IDaaS) ──────────────────────────────────
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-authorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.spa.id]
    issuer   = "https://cognito-idp.us-east-1.amazonaws.com/${aws_cognito_user_pool.pool.id}"
  }
}

# ─── STAGE ────────────────────────────────────────────────────────────────────
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

# ─── IP pública de la task ECS ────────────────────────────────────────────────
# Cambia en cada despliegue; el script publicar-ecs.sh la reapunta.
variable "backend_ip" {
  description = "IP publica de la task ECS del backend"
  type        = string
  default     = "100.55.17.199"
}

# ─── INTEGRACIÓN GET → backend ────────────────────────────────────────────────
resource "aws_apigatewayv2_integration" "backend_get" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "GET"
  integration_uri        = "http://${var.backend_ip}:8080/productos"
  payload_format_version = "1.0"

  lifecycle {
    ignore_changes = [integration_uri]
  }
}

# ─── INTEGRACIÓN POST → backend ───────────────────────────────────────────────
resource "aws_apigatewayv2_integration" "backend_post" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "POST"
  integration_uri        = "http://${var.backend_ip}:8080/productos"
  payload_format_version = "1.0"

  lifecycle {
    ignore_changes = [integration_uri]
  }
}

# ─── RUTAS ────────────────────────────────────────────────────────────────────

# GET /productos — requiere scope productos/read (lectores y editores)
resource "aws_apigatewayv2_route" "get_productos" {
  api_id               = aws_apigatewayv2_api.api.id
  route_key            = "GET /productos"
  target               = "integrations/${aws_apigatewayv2_integration.backend_get.id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.cognito.id
  authorization_scopes = ["productos/read"]
}

# POST /productos — requiere scope productos/write (solo editores/admin)
resource "aws_apigatewayv2_route" "post_productos" {
  api_id               = aws_apigatewayv2_api.api.id
  route_key            = "POST /productos"
  target               = "integrations/${aws_apigatewayv2_integration.backend_post.id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.cognito.id
  authorization_scopes = ["productos/write"]
}
