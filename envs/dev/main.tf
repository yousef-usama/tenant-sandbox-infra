data "aws_caller_identity" "current" {}

data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

module "vpc" {
  source       = "../../modules/vpc"
  project_name = var.project_name
  aws_region   = var.aws_region
}

module "eks" {
  source             = "../../modules/eks"
  project_name       = var.project_name
  private_subnet_ids = module.vpc.private_subnet_ids
  vpc_id             = module.vpc.vpc_id
  allowed_admin_cidr = local.allowed_admin_cidr
}

module "vpc_endpoints" {
  source             = "../../modules/vpc-endpoints"
  project_name       = var.project_name
  vpc_id             = module.vpc.vpc_id
  route_table_ids    = module.vpc.private_route_table_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  vpc_cidr_block     = module.vpc.vpc_cidr_block
}

module "ecr" {
  source       = "../../modules/ecr"
  project_name = var.project_name
}

module "tenant_irsa" {
  source            = "../../modules/tenant-irsa"
  project_name      = var.project_name
  tenant_names      = var.tenant_names
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.oidc_issuer_url
}

module "bootstrap_addons" {
  source                  = "../../modules/bootstrap-addons"
  project_name            = var.project_name
  cluster_name            = module.eks.cluster_name
  cluster_endpoint        = module.eks.cluster_endpoint
  oidc_provider_arn       = module.eks.oidc_provider_arn
  oidc_issuer_url         = module.eks.oidc_issuer_url
  vpc_id                  = module.vpc.vpc_id
  manifests_repo_url      = "https://github.com/${var.github_org_or_user}/${var.manifests_repo}.git"
  route53_hosted_zone_arn = data.aws_route53_zone.main.arn
  route53_hosted_zone_id  = data.aws_route53_zone.main.zone_id
  domain_name             = var.domain_name

  depends_on = [module.eks]
}
