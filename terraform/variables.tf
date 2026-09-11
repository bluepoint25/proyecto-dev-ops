variable "grupo" {
  description = "Nombre del grupo, se usa en nombres de recursos"
  type        = string
  default     = "pedidos360"
}

variable "admin_email" {
  description = "Email del usuario administrador"
  type        = string
  default     = "admin@pedidos360.cl"
}

variable "normal_email" {
  description = "Email del usuario normal"
  type        = string
  default     = "usuario@pedidos360.cl"
}

variable "temp_password" {
  description = "Contraseña temporal para ambos usuarios"
  type        = string
  default     = "Pedidos2025!"
}
