variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "github_org_or_user" {
  type = string
}

variable "allowed_repositories" {
  type    = list(string)
  default = ["tenant-sandbox-infra", "tenant-sandbox-manifests"]
}

