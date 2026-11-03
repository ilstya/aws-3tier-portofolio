terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    bucket       = "ilham-tfstate-324476445159"
    key          = "dev/terraform.tfstate"
    region       = "ap-southeast-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "ap-southeast-1"
  default_tags {
    tags = { Project = "aws-3tier-portfolio", Env = "dev", ManagedBy = "terraform" }
  }
}

module "vpc" {
  source              = "../../modules/vpc"
  name                = "portfolio-dev"
  vpc_cidr            = "10.0.0.0/16"
  azs                 = ["ap-southeast-1a", "ap-southeast-1b"]
  public_subnet_cidrs = ["10.0.0.0/24", "10.0.1.0/24"]
  app_subnet_cidrs    = ["10.0.10.0/24", "10.0.11.0/24"]
  db_subnet_cidrs     = ["10.0.20.0/24", "10.0.21.0/24"]
}

output "vpc_id" { value = module.vpc.vpc_id }

module "security" {
  source = "../../modules/security"
  name   = "portfolio-dev"
  vpc_id = module.vpc.vpc_id
}

module "web" {
  db_host           = module.db.address
  db_secret_arn     = module.db.secret_arn
  source            = "../../modules/web"
  name              = "portfolio-dev"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  app_subnet_ids    = module.vpc.app_subnet_ids
  alb_sg_id         = module.security.alb_sg_id
  app_sg_id         = module.security.app_sg_id
  app_code          = file("${path.root}/../../../app/app.py")
}

output "alb_dns" { value = module.web.alb_dns }


module "db" {
  source        = "../../modules/db"
  name          = "portfolio-dev"
  db_subnet_ids = module.vpc.db_subnet_ids
  db_sg_id      = module.security.db_sg_id
}


variable "alert_email" { type = string }

module "monitoring" {
  source         = "../../modules/monitoring"
  name           = "portfolio-dev"
  alert_email    = var.alert_email
  alb_arn_suffix = module.web.alb_arn_suffix
  tg_arn_suffix  = module.web.tg_arn_suffix
  asg_name       = module.web.asg_name
  db_identifier  = module.db.identifier
}
