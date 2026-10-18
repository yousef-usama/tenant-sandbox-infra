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

output "ebs_csi_role_arn" {
  value = module.eks.ebs_csi_role_arn
}

output "tenant_postgres_secret_arns" {
  value = module.tenant_irsa.tenant_postgres_secret_arns
}

output "tenant_ingress_certificate_arn" {
  value = module.bootstrap_addons.tenant_ingress_certificate_arn
}
