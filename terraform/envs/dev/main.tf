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
