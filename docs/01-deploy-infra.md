# Step 1: Deploy Infrastructure

## Prerequisites
- Azure subscription with Contributor access
- `az` CLI with fleet extension: `az extension add --name fleet`
- Terraform >= 1.5
- Docker (for building sample app)

## Deploy with Terraform

```bash
cd terraform

# Update terraform.tfvars with your subscription ID
vim terraform.tfvars

terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

This creates:
- 1 Resource Group
- 1 Fleet Manager with hub cluster
- 3 AKS clusters (dev, staging, prod) joined as fleet members
- 1 ACR for sample app images
- 1 Log Analytics workspace
- 1 Update strategy (dev → staging → prod)

Deployment takes ~15-20 minutes (AKS clusters + Fleet hub).

## Build Sample App

```bash
cd ../scripts
./build-app.sh
```

## Verify

```bash
# Check fleet members
az fleet member list --resource-group $(terraform -chdir=../terraform output -raw resource_group_name) --fleet-name $(terraform -chdir=../terraform output -raw fleet_name) -o table
```
