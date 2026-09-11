# ─── ZIP del código Lambda ────────────────────────────────────────────────────
# Terraform lo empaqueta automáticamente cada vez que cambia index.mjs
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.mjs"
  output_path = "${path.module}/lambda/user-token-ms.zip"
}

# ─── ROL IAM para la Lambda ───────────────────────────────────────────────────
# En AWS Academy no se pueden crear roles, usamos LabRole
data "aws_caller_identity" "current" {}

# ─── FUNCIÓN LAMBDA ───────────────────────────────────────────────────────────
resource "aws_lambda_function" "user_token_ms" {
  function_name    = "user-token-ms-${var.grupo}"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  role             = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  handler          = "index.handler"
  runtime          = "nodejs20.x"

  # La Lambda debe responder rápido: está en el camino del login
  timeout = 10
}

# ─── PERMISO para que Cognito invoque la Lambda ───────────────────────────────
# Sin este bloque el trigger existe pero el login falla sin decir por qué
resource "aws_lambda_permission" "cognito_invoke" {
  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.user_token_ms.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.pool.arn
}
