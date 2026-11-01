variable "name" { type = string }
variable "vpc_id" { type = string }
variable "db_subnets" { type = list(string) }
variable "ecs_security_group_id" { type = string }
variable "instance_class" { type = string }
variable "allocated_storage" { type = number }
variable "backup_retention" { type = number }
variable "deletion_protection" { type = bool }
variable "multi_az" { type = bool }
resource "aws_security_group" "rds" {
  name_prefix = "${var.name}-rds-"
  vpc_id = var.vpc_id
  ingress { from_port = 5432 to_port = 5432 protocol = "tcp" security_groups = [var.ecs_security_group_id] }
  egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }
  lifecycle { create_before_destroy = true }
}
resource "aws_db_subnet_group" "this" {
  name = "${var.name}-db-subnets"
  subnet_ids = var.db_subnets
}
resource "aws_db_instance" "this" {
  identifier = "${var.name}-postgres"
  engine = "postgres"
  engine_version = "16.8"
  instance_class = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type = "gp3"
  storage_encrypted = true
  db_name = "hotels"
  username = "appadmin"
  manage_master_user_password = true
  port = 5432
  publicly_accessible = false
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name = aws_db_subnet_group.this.name
  backup_retention_period = var.backup_retention
  deletion_protection = var.deletion_protection
  multi_az = var.multi_az
  skip_final_snapshot = !var.deletion_protection
  final_snapshot_identifier = var.deletion_protection ? "${var.name}-final-snapshot" : null
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot = true
}
output "db_endpoint" { value = aws_db_instance.this.endpoint }
