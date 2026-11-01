
# ==========================================
# RDS PostgreSQL Module
# ==========================================

# Variables
variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "db_subnets" {
  type = list(string)
}

variable "ecs_security_group_id" {
  type = string
}

variable "instance_class" {
  type = string
}

variable "allocated_storage" {
  type = number
}

variable "backup_retention" {
  type = number
}

variable "deletion_protection" {
  type = bool
}

variable "multi_az" {
  type = bool
}

# ==========================================
# RDS Security Group
# ==========================================

resource "aws_security_group" "rds" {
  name_prefix = "${var.name}-rds-"
  description = "Allow PostgreSQL access only from ECS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL access from ECS Fargate only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.ecs_security_group_id]
  }

  # No outbound rules are required for application-initiated
  # PostgreSQL connections. Security groups are stateful.

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.name}-rds-sg"
  }
}

# ==========================================
# RDS DB Subnet Group
# ==========================================

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnets"
  subnet_ids = var.db_subnets

  tags = {
    Name = "${var.name}-db-subnets"
  }
}

# ==========================================
# RDS PostgreSQL Instance
# ==========================================

resource "aws_db_instance" "this" {
  identifier = "${var.name}-postgres"

  # Database Engine
  engine         = "postgres"
  engine_version = "16.8"

  # Instance Configuration
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  # Database Configuration
  db_name  = "hotels"
  username = "appadmin"
  port     = 5432

  # AWS Secrets Manager managed master password
  manage_master_user_password = true

  # Network Configuration
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.this.name

  # Backup Configuration
  backup_retention_period = var.backup_retention
  copy_tags_to_snapshot   = true

  # High Availability
  multi_az = var.multi_az

  # Deletion Protection
  deletion_protection = var.deletion_protection

  # Final snapshot required when deletion protection is enabled
  skip_final_snapshot = !var.deletion_protection

  final_snapshot_identifier = var.deletion_protection ? "${var.name}-final-snapshot" : null

  # Maintenance
  auto_minor_version_upgrade = true

  tags = {
    Name        = "${var.name}-postgres"
    Environment = var.name
  }
}

# ==========================================
# Outputs
# ==========================================

output "db_endpoint" {
  description = "PostgreSQL RDS endpoint including port"
  value       = aws_db_instance.this.endpoint
}

