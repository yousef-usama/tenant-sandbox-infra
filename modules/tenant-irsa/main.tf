locals {
  issuer_hostpath = replace(var.oidc_issuer_url, "https://", "")
}

resource "aws_s3_bucket" "tenant_exports" {
  for_each      = toset(var.tenant_names)
  bucket        = "${var.project_name}-${each.key}-exports"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "tenant_exports" {
  for_each = aws_s3_bucket.tenant_exports
  bucket   = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "tenant_exports" {
  for_each = aws_s3_bucket.tenant_exports
  bucket   = each.value.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tenant_exports" {
  for_each = aws_s3_bucket.tenant_exports
  bucket   = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "random_password" "postgres" {
  for_each = toset(var.tenant_names)
  length   = 32
  special  = false
}

resource "aws_secretsmanager_secret" "postgres" {
  for_each                = toset(var.tenant_names)
  name                    = "${var.project_name}/${each.key}/postgres"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "postgres" {
  for_each      = toset(var.tenant_names)
  secret_id     = aws_secretsmanager_secret.postgres[each.key].id
  secret_string = jsonencode({ password = random_password.postgres[each.key].result })
}

resource "aws_iam_role" "tenant" {
  for_each = toset(var.tenant_names)
  name     = "${var.project_name}-${each.key}-app"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.issuer_hostpath}:aud" = "sts.amazonaws.com"
          "${local.issuer_hostpath}:sub" = "system:serviceaccount:${each.key}:feedback-api"
        }
      }
    }]
  })
}

resource "aws_iam_policy" "tenant_exports" {
  for_each = toset(var.tenant_names)
  name     = "${var.project_name}-${each.key}-exports"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ]
      Resource = [
        aws_s3_bucket.tenant_exports[each.key].arn,
        "${aws_s3_bucket.tenant_exports[each.key].arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "tenant_exports" {
  for_each   = toset(var.tenant_names)
  role       = aws_iam_role.tenant[each.key].name
  policy_arn = aws_iam_policy.tenant_exports[each.key].arn
}
