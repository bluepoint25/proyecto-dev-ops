# Nota: la VPC por defecto de este lab YA trae la ruta 0.0.0.0/0,
# por eso NO creamos aws_route (a diferencia de la guía 1.3.9).

# ─── ECR: registro privado de la imagen ───────────────────────────────────────
resource "aws_ecr_repository" "backend" {
  name         = "${var.grupo}-backend"
  force_delete = true
  image_scanning_configuration {
    scan_on_push = false
  }
}

output "ecr_repositorio" {
  description = "URL del repositorio ECR"
  value       = aws_ecr_repository.backend.repository_url
}

# ─── Log group para el stdout del contenedor ─────────────────────────────────
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.grupo}-backend"
  retention_in_days = 7
}

# ─── Security group de la task: abre el 8080 ─────────────────────────────────
resource "aws_security_group" "tarea" {
  name        = "${var.grupo}-task-sg"
  description = "Permite HTTP al backend en 8080"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # el API Gateway (HTTP API) llama por internet
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ─── Cluster (en Fargate es solo un nombre) ───────────────────────────────────
resource "aws_ecs_cluster" "backend" {
  name = "${var.grupo}-cluster"
}

output "ecs_cluster" {
  value = aws_ecs_cluster.backend.name
}

# ─── Task definition: la receta (imagen, CPU, variables, health check) ───────
resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.grupo}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  task_role_arn            = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = "${aws_ecr_repository.backend.repository_url}:latest"
      essential = true
      portMappings = [
        { containerPort = 8080, protocol = "tcp" }
      ]
      environment = [
        { name = "SPRING_DATASOURCE_URL", value = "jdbc:postgresql://${aws_db_instance.postgres.address}:5432/pedidos360?sslmode=require" },
        { name = "SPRING_DATASOURCE_USERNAME", value = aws_db_instance.postgres.username },
        { name = "SPRING_DATASOURCE_PASSWORD", value = var.db_password }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/actuator/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# ─── Servicio: mantiene 1 copia viva ──────────────────────────────────────────
resource "aws_ecs_service" "backend" {
  name            = "${var.grupo}-backend"
  cluster         = aws_ecs_cluster.backend.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.publicas.ids
    security_groups  = [aws_security_group.tarea.id]
    assign_public_ip = true
  }

  # El despliegue de la imagen decide qué corre; Terraform no revierte la imagen
  lifecycle {
    ignore_changes = [task_definition]
  }
}
