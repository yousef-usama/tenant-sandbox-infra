locals {
  issuer_hostpath = replace(var.oidc_issuer_url, "https://", "")
}

resource "aws_s3_bucket" "tenant_exports" {
  for_each = toset(var.tenant_names)
  bucket   = "${var.project_name}-${each.key}-exports"
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

