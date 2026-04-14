# Cleanup

## Terraform Destroy

```bash
cd terraform
terraform destroy
```

This removes all resources including the Fleet Manager, AKS clusters, ACR, and Log Analytics workspace.

## Manual Cleanup (if Terraform fails)

```bash
RG=$(terraform output -raw resource_group_name)
az group delete --name $RG --yes --no-wait

# Also delete the managed fleet resource group (FL_*)
az group list --query "[?starts_with(name, 'FL_')].name" -o tsv | xargs -I{} az group delete --name {} --yes --no-wait
```
