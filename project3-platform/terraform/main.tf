module "vpc_primary" {
  source = "./modules/vpc"
  name   = "p3-primary"
  cidr   = "10.0.0.0/16"
  azs    = ["ap-south-1a", "ap-south-1b"]
}

module "vpc_dr" {
  source    = "./modules/vpc"
  providers = { aws = aws.dr }
  name      = "p3-dr"
  cidr      = "10.1.0.0/16"
  azs       = ["ap-southeast-1a", "ap-southeast-1b"]
}

module "ecr" {
  source = "./modules/ecr"
  name   = "p3-devops-app"
}

module "iam" {
  source             = "./modules/iam"
  github_repo        = "SamirPathan8124/aws-ha-architecture-project"
  ecr_repository_arn = module.ecr.repository_arn
}

module "eks" {
  source     = "./modules/eks"
  name       = "p3-eks"
  subnet_ids = module.vpc_primary.public_subnet_ids
}

module "monitoring" {
  source      = "./modules/monitoring"
  alert_email = var.alert_email
}
