output "argocd_namespace" {
  value = helm_release.argocd.namespace
}

output "external_dns_role_arn" {
  value = aws_iam_role.external_dns.arn
}

output "external_secrets_role_arn" {
  value = aws_iam_role.external_secrets.arn
}

output "tenant_ingress_certificate_arn" {
  value = aws_acm_certificate_validation.tenant_ingress.certificate_arn
}
