# Fleet Manager — Hubless Mode (infrastructure only)
# Members, update strategy, and update runs are created via CLI during the demo.
#
# Demo CLI steps (post-deploy):
#
#   # 1. Join clusters as fleet members
#   az fleet member create -g <rg> --fleet-name <fleet> --name dev \
#     --member-cluster-id $(az aks show -g <rg> -n <dev-cluster> --query id -o tsv)
#   az fleet member create -g <rg> --fleet-name <fleet> --name staging \
#     --member-cluster-id $(az aks show -g <rg> -n <stg-cluster> --query id -o tsv)
#   az fleet member create -g <rg> --fleet-name <fleet> --name prod \
#     --member-cluster-id $(az aks show -g <rg> -n <prod-cluster> --query id -o tsv)
#
#   # 2. Set member update groups
#   az fleet member update -g <rg> --fleet-name <fleet> --name dev --update-group dev-group
#   az fleet member update -g <rg> --fleet-name <fleet> --name staging --update-group staging-group
#   az fleet member update -g <rg> --fleet-name <fleet> --name prod --update-group prod-group
#
#   # 3. Create staged rollout strategy
#   az fleet updatestrategy create -g <rg> --fleet-name <fleet> --name staged-rollout \
#     --stages '[
#       {"name":"dev","groups":[{"name":"dev-group"}]},
#       {"name":"staging","groups":[{"name":"staging-group"}],"afterStageWaitInSeconds":60},
#       {"name":"production","groups":[{"name":"prod-group"}],"afterStageWaitInSeconds":120}
#     ]'
#
#   # 4. Run a Kubernetes version upgrade
#   az fleet updaterun create -g <rg> --fleet-name <fleet> \
#     --name upgrade-134 --upgrade-type Full \
#     --kubernetes-version 1.34 --update-strategy-name staged-rollout
#   az fleet updaterun start -g <rg> --fleet-name <fleet> --name upgrade-134

resource "azurerm_kubernetes_fleet_manager" "fleet" {
  name                = "${var.prefix}-fleet-${local.suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = local.tags
}
