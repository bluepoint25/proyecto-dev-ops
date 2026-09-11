# ─── APP DE AMPLIFY ───────────────────────────────────────────────────────────
# Hosting de sitio estático (el build de React son archivos, no un servidor)
resource "aws_amplify_app" "front" {
  name     = "${var.grupo}-front"
  platform = "WEB"

  # Regla que salva a la SPA: cualquier ruta que no sea un archivo → index.html
  # Sin esto, cualquier ruta distinta de / da 404.
  # json está en la lista a propósito para no tragarse /config.json.
  custom_rule {
    source = "</^[^.]+$|\\.(?!(css|gif|ico|jpg|js|png|txt|svg|woff|woff2|ttf|map|json|webp)$)([^.]+$)/>"
    target = "/index.html"
    status = "200"
  }
}

# ─── RAMA main ────────────────────────────────────────────────────────────────
resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.front.id
  branch_name = "main"
  framework   = "React"
  stage       = "PRODUCTION"
}

# ─── URL que AWS asigna ───────────────────────────────────────────────────────
locals {
  url_amplify = "https://${aws_amplify_branch.main.branch_name}.${aws_amplify_app.front.default_domain}"
}

output "amplify_app_id" {
  description = "Necesario para aws amplify create-deployment"
  value       = aws_amplify_app.front.id
}

output "amplify_url" {
  description = "URL pública del front. Va en callback_urls, logout_urls y CORS"
  value       = local.url_amplify
}
