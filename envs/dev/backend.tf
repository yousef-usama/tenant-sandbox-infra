terraform {
  backend "s3" {
    bucket       = "tenant-sandbox-tfstate"
    key          = "tenant-sandbox/dev/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
