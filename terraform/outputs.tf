output "cognito_domain" {
  description = "Dominio del Hosted UI de Cognito"
  value       = "https://${aws_cognito_user_pool_domain.hosted_ui.domain}.auth.us-east-1.amazoncognito.com"
}

output "cognito_client_id" {
  description = "Client ID de la SPA React"
  value       = aws_cognito_user_pool_client.spa.id
}

output "cognito_user_pool_id" {
  description = "ID del User Pool"
  value       = aws_cognito_user_pool.pool.id
}

output "api_url" {
  description = "URL base del API Gateway"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "env_frontend" {
  description = "Contenido listo para pegar en .env.local del frontend"
  value       = <<-EOT
    VITE_AWS_REGION=us-east-1
    VITE_COGNITO_DOMAIN=https://${aws_cognito_user_pool_domain.hosted_ui.domain}.auth.us-east-1.amazoncognito.com
    VITE_COGNITO_CLIENT_ID=${aws_cognito_user_pool_client.spa.id}
    VITE_REDIRECT_URI=http://localhost:5173/
    VITE_API_URL=${aws_apigatewayv2_stage.default.invoke_url}
  EOT
}

output "admin_email" {
  value = var.admin_email
}

output "normal_email" {
  value = var.normal_email
}

output "temp_password" {
  value     = var.temp_password
  sensitive = true
}
