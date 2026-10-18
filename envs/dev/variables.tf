variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "project_name" {
  type    = string
  default = "tenant-sandbox"
}

variable "domain_name" {
  type        = string
  description = "Route53 hosted zone domain, for example example.click."
}

variable "github_org_or_user" {
  type        = string
  description = "GitHub owner for the two project repositories."
}

variable "manifests_repo" {
  type    = string
  default = "tenant-sandbox-manifests"
}

variable "allowed_admin_cidr" {
  type        = string
  default     = null
  nullable    = true
  description = "Optional fixed CIDR allowed to reach the public EKS API endpoint. Omit to detect the current public IPv4 address at Terraform apply time."
}

variable "tenant_names" {
  type    = list(string)
  default = ["tenant-a", "tenant-b", "tenant-c"]
}

