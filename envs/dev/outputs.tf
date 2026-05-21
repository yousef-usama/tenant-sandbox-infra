output "cluster_name" {
  value = module.eks.cluster_name
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "tenant_export_bucket_names" {
  value = module.tenant_irsa.tenant_bucket_names
}

output "argocd_namespace" {
  value = module.bootstrap_addons.argocd_namespace
}

output "external_dns_role_arn" {
  value = module.bootstrap_addons.external_dns_role_arn
}

output "external_secrets_role_arn" {
  value = module.bootstrap_addons.external_secrets_role_arn
}
