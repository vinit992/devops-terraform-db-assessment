locals { name = "hotel-prod" }
module "network" {
  source   = "../../modules/network"
  name     = local.name
  vpc_cidr = var.vpc_cidr
  azs      = var.azs
}
module "ecs" {
  source         = "../../modules/ecs"
  name           = local.name
  vpc_id         = module.network.vpc_id
  public_subnets = module.network.public_subnets
  app_subnets    = module.network.app_subnets
  cpu            = var.ecs_cpu
  memory         = var.ecs_memory
  desired_count  = var.ecs_desired_count
  image          = var.container_image
}
module "rds" {
  source                = "../../modules/rds"
  name                  = local.name
  vpc_id                = module.network.vpc_id
  db_subnets            = module.network.db_subnets
  ecs_security_group_id = module.ecs.ecs_security_group_id
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  backup_retention      = var.db_backup_retention
  deletion_protection   = var.db_deletion_protection
  multi_az              = var.db_multi_az
}
output "alb_dns_name" { value = module.ecs.alb_dns_name }
output "db_endpoint" { value = module.rds.db_endpoint }
