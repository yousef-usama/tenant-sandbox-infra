# Tenant Sandbox Infra

Terraform for a cost-conscious EKS portfolio/demo platform where each tenant is isolated in a Kubernetes namespace.

This repo owns AWS infrastructure and only the minimum in-cluster bootstrap components:

- VPC, private EKS nodes, public load balancer subnets
- Low-cost NAT instance instead of NAT Gateway
- VPC endpoints for ECR, S3, STS, and CloudWatch Logs
- EKS cluster and managed spot node group
- ECR repository for the feedback API
- IRSA roles for platform add-ons and tenant service accounts
- AWS Load Balancer Controller and ArgoCD

ArgoCD owns everything else from the `tenant-sandbox-manifests` repo.

## Local-Only Status

The files in this repo are safe to create locally. Nothing is deployed until you run Terraform commands such as `terraform apply`.

## Bootstrap

Terraform remote state is intentionally bootstrapped outside the main Terraform stack to avoid a chicken-and-egg dependency.

Replace the bucket name with a globally unique value:

```bash
export AWS_REGION=eu-central-1
export TF_STATE_BUCKET=tenant-sandbox-tfstate-REPLACE_ME
export TF_LOCK_TABLE=tenant-sandbox-tf-locks

aws s3api create-bucket \
  --bucket "$TF_STATE_BUCKET" \
  --region "$AWS_REGION" \
  --create-bucket-configuration LocationConstraint="$AWS_REGION"

aws s3api put-bucket-versioning \
  --bucket "$TF_STATE_BUCKET" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket "$TF_STATE_BUCKET" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws dynamodb create-table \
  --table-name "$TF_LOCK_TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$AWS_REGION"
```

Then copy `envs/dev/backend.tf.example` to `envs/dev/backend.tf` and fill in your bucket name.

## GitHub OIDC Bootstrap

The `bootstrap/github-oidc` directory creates the GitHub OIDC provider and a bootstrap role that GitHub Actions can assume. Apply it only after updating the repo names and account values.

```bash
cd bootstrap/github-oidc
terraform init
terraform plan
terraform apply
```

## Main Infra Apply

```bash
cd envs/dev
terraform init
terraform plan
terraform apply
```

After the EKS cluster exists:

```bash
aws eks update-kubeconfig --region eu-central-1 --name tenant-sandbox
kubectl get nodes
```

## Cost-Conscious Trade-Offs

| Decision | Why | Trade-off |
| --- | --- | --- |
| NAT instance | Much cheaper than NAT Gateway for a short demo | Less available and less managed |
| Spot node group | Keeps compute cost low | Nodes can be interrupted |
| In-cluster Postgres | Avoids RDS cost | Not production-grade database operations |
| VPC endpoints | Reduces NAT traffic for AWS APIs/image pulls | Adds endpoint hourly cost |
| Terraform installs only ArgoCD and AWS LB Controller | Avoids destroy-order problems | Requires GitOps repo for the rest |

## Teardown

Delete ArgoCD-managed applications first from the manifests repo or ArgoCD UI, then destroy Terraform:

```bash
cd envs/dev
terraform destroy
```

The GitHub Actions workflow also includes a manual destroy entry point for the demo account.

