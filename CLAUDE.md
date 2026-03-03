# kubernetes_sandbox — Claude Code Guide

## Overview

This is a GitOps-managed Kubernetes learning sandbox. There is **no build system** — all changes are pure YAML. Pushing to `main` is sufficient; Flux CD reconciles the cluster every 60 seconds.

**Key tech stack:**
- **Flux CD** — GitOps operator watching this repo
- **Kustomize** — layering via `base/` + `sandbox/` overlays
- **Helm** — used inside Flux `HelmRelease` resources for complex apps
- **External Secrets Operator (ESO)** — syncs secrets from Infisical; never store raw secrets in git

---

## Common Commands

```bash
# Check Flux reconciliation status
flux get kustomizations -A
flux get helmreleases -A

# Force an immediate reconciliation (don't wait 60s)
flux reconcile kustomization flux-system --with-source

# Check all Flux sources
flux get sources git -A

# Watch cluster resources
kubectl get pods -A
kubectl get helmreleases -A -w

# Inspect a failing Kustomization
flux describe kustomization <name> -n flux-system

# Validate kustomize output before pushing
kustomize build apps/sandbox
kustomize build infrastructure/configs/sandbox
kustomize build infrastructure/controllers/sandbox
```

---

## Architecture

### Flux Entry Point

`clusters/sandbox/` contains the root Flux Kustomizations that drive everything:

| File | Kustomization name | Path watched |
|---|---|---|
| `apps.yaml` | `apps` | `./apps/sandbox` |
| `databases.yaml` | `databases` | `./databases/sandbox` |
| `infrastructure.yaml` | `infrastructure-controllers` | `./infrastructure/controllers/sandbox` |
| `infrastructure.yaml` | `infrastructure-configs` | `./infrastructure/configs/sandbox` |

### Dependency Order (important — don't break this)

```
infrastructure-controllers  →  infrastructure-configs  →  apps / databases
```

`infrastructure-configs` has an explicit `dependsOn: infrastructure-controllers`. Apps and databases do **not** have declared `dependsOn`, but they rely on controllers (CRDs, operators) being ready first.

### Kustomize Layering Pattern

Every deployable area follows the same convention:

```
<area>/
  base/          # Reusable, environment-agnostic manifests
  sandbox/       # Overlay that references base + applies patches
```

- Edit `base/` when changing something that should apply everywhere.
- Edit `sandbox/` when making a sandbox-specific change (resource limits, replica counts, image tags, etc.).

### Directory Map

```
clusters/sandbox/          # Flux root Kustomizations — Flux bootstrapped here
infrastructure/
  controllers/             # Helm/OCI HelmReleases for operators (cert-manager, ESO, ingress-nginx, cnpg, metallb, nfs-driver)
  configs/                 # CRs that configure the operators (ClusterIssuers, MetalLB pools, ExternalSecret stores, etc.)
  image-repository/        # Flux ImageRepository / ImagePolicy resources
apps/                      # Application workloads (podinfo, pihole, keycloak, cloudflared, etc.)
databases/                 # Database workloads (CloudNativePG clusters, etc.)
cluster/resources/         # LEGACY — manually applied manifests; not reconciled by Flux
```

---

## Working with This Repo

### Adding a new app

1. Create `apps/base/<app-name>/` with Kubernetes manifests and a `kustomization.yaml`.
2. Create `apps/sandbox/<app-name>/` overlay with a `kustomization.yaml` that references the base.
3. Add the new app directory to `apps/sandbox/kustomization.yaml` resources list.
4. Push to `main`. Flux will reconcile within 60 seconds.

### Adding a new infrastructure controller

1. Create `infrastructure/controllers/base/<controller>/` with a `HelmRelease` (or other resource) and `kustomization.yaml`.
2. Create `infrastructure/controllers/sandbox/<controller>/` overlay.
3. Add to `infrastructure/controllers/sandbox/kustomization.yaml`.
4. If the controller exposes CRDs needed by configs, ensure the config resources use `dependsOn` or wait appropriately.

### Secret management

- **Never** commit raw secrets.
- All secrets are sourced from **Infisical** via External Secrets Operator.
- `ExternalSecret` and `SecretStore`/`ClusterSecretStore` resources live in `infrastructure/configs/`.
- To bootstrap Infisical credentials on a fresh cluster, run:
  ```bash
  infrastructure/configs/sandbox/external-secrets/secret-zero.sh
  ```
  This creates the single "secret-zero" Kubernetes secret that ESO uses to authenticate with Infisical. Everything else is synced automatically.

### Debugging reconciliation failures

```bash
# See why a Kustomization is failing
flux describe kustomization <name> -n flux-system

# See HelmRelease failure details
flux describe helmrelease <name> -n <namespace>

# Get controller logs
kubectl logs -n flux-system deploy/kustomize-controller
kubectl logs -n flux-system deploy/helm-controller
```

### Legacy `cluster/resources/`

Manifests in `cluster/resources/` are **not** reconciled by Flux and must be applied manually with `kubectl apply`. Prefer moving workloads to the GitOps paths above rather than adding to the legacy directory.
