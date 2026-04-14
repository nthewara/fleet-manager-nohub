# Update Orchestration Demo — Complete End-to-End

Three upgrade scenarios demonstrating Fleet Manager's orchestration capabilities, following [AKS Upgrade Best Practices](https://github.com/nthewara/fleet-manager).

## Environment

> **Important:** Clusters must be deployed on K8s 1.31 (not latest) so the node images are older
> and all three upgrade scenarios can be demonstrated. The Terraform template defaults to 1.31 for this reason.

```bash
RG="<your-rg>"
FLEET="<your-fleet>"
```

## Pre-flight: Current State

```bash
# Fleet members and versions
az fleet member list -g $RG --fleet-name $FLEET -o table

# Current K8s versions and node images
for c in fleetdemo-aks-dev-xuji fleetdemo-aks-stg-xuji fleetdemo-aks-prod-xuji; do
  CP=$(az aks show -g $RG -n $c --query "kubernetesVersion" -o tsv)
  NODE=$(az aks show -g $RG -n $c --query "agentPoolProfiles[0].currentOrchestratorVersion" -o tsv)
  IMG=$(az aks show -g $RG -n $c --query "agentPoolProfiles[0].nodeImageVersion" -o tsv)
  echo "$c: CP=$CP Nodes=$NODE Image=$IMG"
done

# Available upgrade targets
az aks get-upgrades -g $RG -n fleetdemo-aks-dev-xuji \
  --query "controlPlaneProfile.upgrades[].kubernetesVersion" -o tsv

# View update strategy
az fleet updatestrategy show -g $RG --fleet-name $FLEET --name staged-rollout
```

---

## Scenario 1: Node Image Upgrade (Weekly Security Patching)

**What:** Updates the OS image on all nodes — security patches, kernel updates, CVE fixes.
**K8s version:** Unchanged.
**Pod disruption:** Yes — nodes are cordoned, drained, and reimaged.
**Frequency:** Weekly or biweekly in production.

> This is the most common Fleet Manager operation. Teams run this weekly to stay current on OS-level vulnerabilities without changing the Kubernetes version.

### Open Fleet Monitor

Open the Fleet Monitor dashboard and **Reset History** before starting:
- Fleet Monitor: `http://<monitor-ip>`

### Create and Start

```bash
az fleet updaterun create \
  -g $RG --fleet-name $FLEET \
  --name node-image-weekly \
  --upgrade-type NodeImageOnly \
  --node-image-selection Latest \
  --update-strategy-name staged-rollout

az fleet updaterun start \
  -g $RG --fleet-name $FLEET \
  --name node-image-weekly
```

### Monitor

```bash
# CLI
az fleet updaterun show -g $RG --fleet-name $FLEET --name node-image-weekly -o table

# Portal: Fleet Manager → Update runs → node-image-weekly
```

### What to Watch

- Fleet Monitor shows **red** as each cluster's nodes are drained and reimaged
- Dev upgrades first → 60s wait → Staging → 120s wait → Production
- Each cluster takes ~10-15 min (cordon → drain → reimage cycle)
- After each cluster recovers, Fleet Monitor goes back to **green**

### Verify

```bash
for c in fleetdemo-aks-dev-xuji fleetdemo-aks-stg-xuji fleetdemo-aks-prod-xuji; do
  IMG=$(az aks show -g $RG -n $c --query "agentPoolProfiles[0].nodeImageVersion" -o tsv)
  echo "$c: Image=$IMG"
done
```

Node images should be updated to the latest version. K8s version remains unchanged.

---

## Scenario 2: Control Plane Only Upgrade (K8s 1.31 → 1.32)

**What:** Upgrades the API server, etcd, scheduler, and controller-manager.
**Node pools:** Unchanged — kubelet stays on 1.31.
**Pod disruption:** None — workloads keep running throughout.
**When:** When a new K8s minor version is available and you want to validate API compatibility before touching nodes.

> This is the safest first step in a K8s version upgrade. Zero pod disruption means you can validate that controllers, webhooks, and Helm charts work against the new API version before committing to a node pool upgrade.

### Reset Fleet Monitor History

Reset history in Fleet Monitor before starting this scenario.

### Create and Start

```bash
az fleet updaterun create \
  -g $RG --fleet-name $FLEET \
  --name cp-upgrade-132 \
  --upgrade-type ControlPlaneOnly \
  --kubernetes-version 1.32.7 \
  --update-strategy-name staged-rollout

az fleet updaterun start \
  -g $RG --fleet-name $FLEET \
  --name cp-upgrade-132
```

### Monitor

```bash
az fleet updaterun show -g $RG --fleet-name $FLEET --name cp-upgrade-132 -o table
```

### What to Watch

- Fleet Monitor stays **all green** — no pod disruption during control plane upgrade
- Each cluster completes in ~5 min
- Staged rollout: dev → (60s) → staging → (120s) → production
- This is the key demo moment: "zero-downtime control plane upgrade across the fleet"

### Verify

```bash
for c in fleetdemo-aks-dev-xuji fleetdemo-aks-stg-xuji fleetdemo-aks-prod-xuji; do
  CP=$(az aks show -g $RG -n $c --query "kubernetesVersion" -o tsv)
  NODE=$(az aks show -g $RG -n $c --query "agentPoolProfiles[0].currentOrchestratorVersion" -o tsv)
  echo "$c: ControlPlane=$CP Nodes=$NODE"
done
```

Expected: Control plane = **1.32.7**, Nodes = **1.31.x** (split version — expected and supported, nodes can trail by up to 2 minor versions).

---

## Scenario 3: Full Upgrade (Bring Nodes to 1.34)

**What:** Upgrades node pools to match the control plane — kubelet version + node image.
**Pod disruption:** Yes — nodes are cordoned, drained, and reimaged.
**When:** After control plane upgrade is validated and stable.

> This completes the K8s version upgrade. Now both control plane and nodes are on 1.34.

### Reset Fleet Monitor History

Reset history again to get a clean view of node upgrade downtime.

### Create and Start

```bash
az fleet updaterun create \
  -g $RG --fleet-name $FLEET \
  --name full-upgrade-132 \
  --upgrade-type Full \
  --kubernetes-version 1.32.7 \
  --update-strategy-name staged-rollout

az fleet updaterun start \
  -g $RG --fleet-name $FLEET \
  --name full-upgrade-132
```

### Monitor

```bash
az fleet updaterun show -g $RG --fleet-name $FLEET --name full-upgrade-132 -o table
```

### What to Watch

- Control plane already on 1.34 — this only upgrades node pools
- Fleet Monitor shows **red** during node drain/reimage (same pattern as Scenario 1)
- Staged rollout: dev → staging → production

### Final Verification

```bash
for c in fleetdemo-aks-dev-xuji fleetdemo-aks-stg-xuji fleetdemo-aks-prod-xuji; do
  CP=$(az aks show -g $RG -n $c --query "kubernetesVersion" -o tsv)
  NODE=$(az aks show -g $RG -n $c --query "agentPoolProfiles[0].currentOrchestratorVersion" -o tsv)
  IMG=$(az aks show -g $RG -n $c --query "agentPoolProfiles[0].nodeImageVersion" -o tsv)
  echo "$c: CP=$CP Nodes=$NODE Image=$IMG"
done
```

Expected: All clusters on **K8s 1.32.7** with matching control plane and node versions.

---

## Summary: Three Upgrade Types

| Scenario | Type | K8s Version Change | Pod Disruption | Duration/Cluster | Frequency |
|----------|------|-------------------|----------------|-----------------|-----------|
| 1. Node Image | `NodeImageOnly` | No | Yes (drain/reimage) | ~10-15 min | Weekly |
| 2. Control Plane | `ControlPlaneOnly` | Yes (CP only) | None | ~5 min | Per K8s release |
| 3. Full Upgrade | `Full` | Yes (nodes) | Yes (drain/reimage) | ~10-15 min | Per K8s release |

## Emergency: Stop an Update Run

```bash
az fleet updaterun stop -g $RG --fleet-name $FLEET --name <run-name>
```

## Fleet Monitor

Watch real-time cluster health during all scenarios:
- 🟢 Green = cluster healthy, app responding
- 🔴 Red = cluster offline (nodes being upgraded)
- Uptime timeline shows exact downtime window per cluster
- K8s version updates live as each cluster completes
