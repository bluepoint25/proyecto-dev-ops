# ─── Variables de la base de datos ────────────────────────────────────────────
variable "db_password" {
  description = "Contraseña del usuario maestro de RDS"
  type        = string
  default     = "Pedidos2025DB!"
  sensitive   = true
}

# ─── Red por defecto (se reutiliza) ──────────────────────────────────────────
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "publicas" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

# ─── Security group para RDS: permite Postgres ───────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${var.grupo}-rds-sg"
  description = "Permite conexiones PostgreSQL"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # lab: abierto; en prod se restringe al SG de la task
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ─── Subnet group (RDS necesita al menos 2 subredes) ─────────────────────────
resource "aws_db_subnet_group" "rds" {
  name       = "${var.grupo}-rds-subnets"
  subnet_ids = data.aws_subnets.publicas.ids
}

# ─── Instancia PostgreSQL ─────────────────────────────────────────────────────
resource "aws_db_instance" "postgres" {
  identifier             = "${var.grupo}-db"
  engine                 = "postgres"
  engine_version         = "16.9"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "pedidos360"
  username               = "postgres"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = true
  skip_final_snapshot    = true
  # sslmode se maneja en la URL de conexión del backend
}

output "rds_endpoint" {
  description = "Endpoint de la base de datos PostgreSQL"
  value       = aws_db_instance.postgres.address
}
