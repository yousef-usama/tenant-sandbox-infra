output "tenant_role_arns" {
  value = { for name, role in aws_iam_role.tenant : name => role.arn }
}

output "tenant_bucket_names" {
  value = { for name, bucket in aws_s3_bucket.tenant_exports : name => bucket.bucket }
}

output "tenant_postgres_secret_arns" {
  value = { for name, secret in aws_secretsmanager_secret.postgres : name => secret.arn }
}
