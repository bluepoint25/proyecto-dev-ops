# ─── USER POOL ───────────────────────────────────────────────────────────────
resource "aws_cognito_user_pool" "pool" {
  name                     = "${var.grupo}-pool"
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = false
  }

  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  schema {
    name                = "role"
    attribute_data_type = "String"
    mutable             = true
    required            = false
    string_attribute_constraints {
      min_length = 1
      max_length = 50
    }
  }

  # ── Trigger: inyecta scopes según grupo antes de firmar el token ──
  lambda_config {
    pre_token_generation_config {
      lambda_arn     = aws_lambda_function.user_token_ms.arn
      lambda_version = "V2_0"
    }
  }
}

# ─── RESOURCE SERVER: declara que los scopes existen ─────────────────────────
resource "aws_cognito_resource_server" "productos" {
  identifier   = "productos"
  name         = "API de productos"
  user_pool_id = aws_cognito_user_pool.pool.id

  scope {
    scope_name        = "read"
    scope_description = "Consultar productos"
  }
  scope {
    scope_name        = "write"
    scope_description = "Crear y modificar productos"
  }
}

# ─── DOMINIO (HOSTED UI) ──────────────────────────────────────────────────────
resource "aws_cognito_user_pool_domain" "hosted_ui" {
  domain                = "${var.grupo}-dsy1107"
  user_pool_id          = aws_cognito_user_pool.pool.id
  managed_login_version = 1
}

# ─── CLIENTE SPA (React) ──────────────────────────────────────────────────────
resource "aws_cognito_user_pool_client" "spa" {
  name         = "spa-react"
  user_pool_id = aws_cognito_user_pool.pool.id

  # Cliente público: su código es visible en el navegador, no tiene secreto
  generate_secret = false

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  supported_identity_providers         = ["COGNITO"]

  allowed_oauth_scopes = [
    "openid",
    "email",
    "profile",
    "productos/read",
    "productos/write",
  ]

  # Dos orígenes: localhost (desarrollo) y Amplify (producción)
  callback_urls = [
    "http://localhost:5173/",
    "${local.url_amplify}/",
  ]
  logout_urls = [
    "http://localhost:5173/",
    "${local.url_amplify}/",
  ]

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  access_token_validity = 60
  id_token_validity     = 60
  token_validity_units {
    access_token = "minutes"
    id_token     = "minutes"
  }

  read_attributes  = ["email", "custom:role"]
  write_attributes = ["email", "custom:role"]

  depends_on = [aws_cognito_resource_server.productos]
}

# ─── USUARIOS ─────────────────────────────────────────────────────────────────
resource "aws_cognito_user" "admin" {
  user_pool_id = aws_cognito_user_pool.pool.id
  username     = var.admin_email

  attributes = {
    email          = var.admin_email
    email_verified = "true"
    "custom:role"  = "admin"
  }

  temporary_password = var.temp_password
  message_action     = "SUPPRESS"
}

resource "aws_cognito_user" "normal" {
  user_pool_id = aws_cognito_user_pool.pool.id
  username     = var.normal_email

  attributes = {
    email          = var.normal_email
    email_verified = "true"
    "custom:role"  = "user"
  }

  temporary_password = var.temp_password
  message_action     = "SUPPRESS"
}

# ─── GRUPOS (el grupo define el scope que la Lambda inyecta) ──────────────────
# editores → productos/read + productos/write
resource "aws_cognito_user_group" "editores" {
  name         = "editores"
  user_pool_id = aws_cognito_user_pool.pool.id
  description  = "Puede crear, modificar y eliminar productos"
}

# lectores → solo productos/read
resource "aws_cognito_user_group" "lectores" {
  name         = "lectores"
  user_pool_id = aws_cognito_user_pool.pool.id
  description  = "Puede consultar productos"
}

# ─── ASIGNACIÓN DE USUARIOS A GRUPOS ─────────────────────────────────────────
resource "aws_cognito_user_in_group" "admin_en_editores" {
  user_pool_id = aws_cognito_user_pool.pool.id
  group_name   = aws_cognito_user_group.editores.name
  username     = aws_cognito_user.admin.username
}

resource "aws_cognito_user_in_group" "normal_en_lectores" {
  user_pool_id = aws_cognito_user_pool.pool.id
  group_name   = aws_cognito_user_group.lectores.name
  username     = aws_cognito_user.normal.username
}
