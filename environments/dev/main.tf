module "network" {
  source   = "../../modules/network"
  name     = "fintech-dev"
  vpc_cidr = "10.0.0.0/16"
  az_count = 2
}

module "security_groups" {
  source   = "../../modules/security-groups"
  name     = "fintech-dev"
  vpc_id   = module.network.vpc_id
  app_port = 3000
  db_port  = 5432
}

output "vpc_id" { value = module.network.vpc_id }
output "public_subnet_ids" { value = module.network.public_subnet_ids }
output "private_app_subnet_ids" { value = module.network.private_app_subnet_ids }
output "private_db_subnet_ids" { value = module.network.private_db_subnet_ids }

output "alb_sg_id" { value = module.security_groups.alb_sg_id }
output "ecs_sg_id" { value = module.security_groups.ecs_sg_id }
output "rds_sg_id" { value = module.security_groups.rds_sg_id }

module "rds" {
  source = "../../modules/rds"

  name          = "fintech-dev"
  db_subnet_ids = module.network.private_db_subnet_ids
  db_sg_id      = module.security_groups.rds_sg_id

  db_name           = "fintech"
  engine_version    = "16"
  instance_class    = "db.t4g.micro"
  allocated_storage = 20

  ssm_username_param = "/platform/fintech/dev/database/username"
  ssm_password_param = "/platform/fintech/dev/database/password"
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "rds_port" {
  value = module.rds.port
}

module "ecr" {
  source    = "../../modules/ecr"
  repo_name = "fintech-dev-api"
}

output "ecr_repo_url" {
  value = module.ecr.repository_url
}


module "ecs_fargate" {
  source          = "../../modules/ecs_fargate_service"
  certificate_arn = "arn:aws:acm:eu-central-1:051826742726:certificate/c35c894f-a6ef-4684-b068-28368ae7b911"
  name            = "fintech-dev"

  vpc_id                 = module.network.vpc_id
  public_subnet_ids      = module.network.public_subnet_ids
  private_app_subnet_ids = module.network.private_app_subnet_ids

  alb_sg_id = module.security_groups.alb_sg_id
  ecs_sg_id = module.security_groups.ecs_sg_id

  image = "${module.ecr.repository_url}:v3"

  container_port = 3000

  db_host = module.rds.endpoint
  db_port = module.rds.port
  db_name = "fintech"

  ssm_db_username_param = "/platform/fintech/dev/database/username"
  ssm_db_password_param = "/platform/fintech/dev/database/password"
}

output "alb_dns_name" {
  value = module.ecs_fargate.alb_dns_name
}

module "waf" {
  source  = "../../modules/waf"
  name    = "fintech-dev"
  alb_arn = module.ecs_fargate.alb_arn
}

output "waf_web_acl_arn" {
  value = module.waf.web_acl_arn
}

module "jenkins" {
  source             = "../../modules/jenkins"
  name               = "fintech-dev"
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_app_subnet_ids
}

output "jenkins_controller_instance_id" { value = module.jenkins.controller_instance_id }
output "jenkins_agent_instance_id" { value = module.jenkins.agent_instance_id }
output "jenkins_controller_private_ip" { value = module.jenkins.controller_private_ip }