#!/usr/bin/env bash
set -euo pipefail

cluster_name="${1:-tenant-sandbox}"
aws_region="${AWS_REGION:-eu-central-1}"
current_ip="$(curl --fail --silent --show-error --location --ipv4 https://checkip.amazonaws.com/ | tr -d '[:space:]')"

if [[ ! "$current_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo "Unable to determine a valid public IPv4 address: $current_ip" >&2
  exit 1
fi

echo "Allowing ${current_ip}/32 to access the ${cluster_name} EKS public endpoint."
update_id="$(aws eks update-cluster-config \
  --name "$cluster_name" \
  --region "$aws_region" \
  --resources-vpc-config "endpointPublicAccess=true,endpointPrivateAccess=true,publicAccessCidrs=${current_ip}/32" \
  --query 'update.id' \
  --output text)"

aws eks wait cluster-active --name "$cluster_name" --region "$aws_region"
echo "EKS endpoint update ${update_id} is complete."
