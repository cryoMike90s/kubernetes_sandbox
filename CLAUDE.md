# kubernetes_sandbox — Claude Code Guide

## Overview

This is a GitOps-managed Kubernetes learning sandbox. There is **no build system** — all changes are pure YAML. Pushing to `main` is sufficient; Flux CD reconciles the cluster every 60 seconds.

**Key tech stack:**
- **Flux CD** — GitOps operator watching this repo
- **Kustomize** — layering via `base/` + `sandbox/` overlays
- **Helm** — used inside Flux `HelmRelease` resources for complex apps
- **External Secrets Operator (ESO)** — syncs secrets from Infisical; never store raw secrets in git
- **Gateway API (NGINX Gateway Fabric)** — preferred way to route HTTP traffic to apps (see below); `ingress-nginx` is still installed but new routing should use `HTTPRoute`, not `Ingress`
- **Cloudflare Tunnel (`cloudflared`)** — exposes apps under `miskers.org` to the internet without opening any router ports

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
  controllers/             # Helm/OCI HelmReleases for operators (cert-manager, ESO, ingress-nginx, nginx-gateway-fabric, gateway-api-crds, cnpg, metallb, nfs-driver)
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

- **Never** commit raw (plaintext) secrets — SOPS-encrypted manifests are fine and expected.
- All application secrets are sourced from **Infisical** via External Secrets Operator.
- `ExternalSecret` and `SecretStore`/`ClusterSecretStore` resources live in `infrastructure/configs/`.
- The `auth-credentials` secret (used by `ClusterSecretStore/sandbox-secretstore` to authenticate to Infisical) is itself managed via **SOPS**, not created imperatively: it's committed as an encrypted `Secret` manifest at `infrastructure/configs/sandbox/external-secrets/auth-credentials.secret.yaml`, decrypted automatically by Flux's `kustomize-controller` on every reconcile.
- `secretstore.yaml` and `auth-credentials.secret.yaml` live directly under `infrastructure/configs/sandbox/external-secrets/`, not `base/` — both are inherently cluster/environment-specific (Infisical project slug, environment, and credentials), so putting them in `base/` would leak sandbox-specific secrets/config into any future cluster overlay reusing that base. `infrastructure/configs/base/external-secrets/secretstore.yaml.example` is a generic, unwired template to copy from when setting up a new cluster overlay.
- To add or edit a SOPS-encrypted secret manifest:
  ```yaml
  # 1. write the manifest with plaintext stringData values (never git add yet)
  # 2. encrypt in place, encrypting only data/stringData so kustomize can still parse the resource:
  sops --encrypt --encrypted-regex '^(data|stringData)$' --in-place <file>.secret.yaml
  # 3. verify the values show as ENC[...] before committing
  cat <file>.secret.yaml
  ```
  `.sops.yaml` (repo root) scopes encryption to any file matching `*.secret.yaml`.
- **Cluster bootstrap (one-time, per-cluster):** Flux needs the age private key to decrypt SOPS secrets. After a fresh cluster/`flux bootstrap`, recreate it:
  ```bash
  cat <path-to-age.agekey> | kubectl create secret generic sops-age \
    --namespace=flux-system \
    --from-file=age.agekey=/dev/stdin
  ```
  The age private key itself is never stored in git — keep it in a password manager or similar. Losing it means every SOPS-encrypted secret in the repo must be re-encrypted with a new key.
- **Safety net:** a pre-commit hook in `.githooks/pre-commit` blocks committing any `*.secret.yaml` file that isn't already SOPS-encrypted. `core.hooksPath` is a local git setting, not synced by git itself — every clone must run this once:
  ```bash
  git config core.hooksPath .githooks
  ```

### Exposing an app via Gateway API + Cloudflare Tunnel

Routing is split across two layers — don't confuse them:

- **`Gateway`** (`infrastructure/configs/base/gateway-api/gateway.yaml`, `sandbox-gateway` in ns `nginx-gateway`) — the shared listener, one per cluster. `gatewayClassName: nginx` binds it to the NGINX Gateway Fabric controller (`infrastructure/controllers/base/nginx-gateway-fabric/`). HTTP-only for now (port 80) — TLS to browsers is handled by Cloudflare's edge, not this listener. `allowedRoutes.namespaces.from: All` means any namespace can attach routes to it.
- **`HTTPRoute`** — one per app, lives next to the app's own manifests (e.g. `apps/base/podinfo/httproute.yaml`), `parentRefs` the shared `Gateway`, and picks a `hostname` + `backendRefs` to the app's `Service`.

To route a new app:
1. Add an `HTTPRoute` in `apps/base/<app>/` (see `apps/base/podinfo/httproute.yaml` as a template) with `hostnames: [<app>.miskers.org]` and `backendRefs` pointing at the app's `Service`.
2. Add it to the app's `kustomization.yaml`.
3. Push. No DNS or Cloudflare Tunnel change is needed — DNS for `*.miskers.org` is a **wildcard** CNAME to the tunnel (`apps/sandbox/cloudflared/cf.yaml`), so any new `<something>.miskers.org` hostname is automatically routable the moment its `HTTPRoute` exists.

**Security implication of the wildcard:** because DNS and the Gateway are both wide open, adding an `HTTPRoute` with a hostname is enough to make that app internet-reachable — there's no extra review gate. Fine for public/demo apps (e.g. `podinfo`), but anything with an admin UI or sensitive data needs an explicit access control layer:
- **Cloudflare Access (Zero Trust)**: Cloudflare dashboard → Zero Trust → Access → Applications → add a self-hosted application scoped to the specific hostname (e.g. `keycloak.miskers.org`), with a policy (email allow-list, or SSO via an identity provider). This blocks unauthenticated requests at Cloudflare's edge, before they ever reach the tunnel/cluster. This is dashboard-only configuration, not something expressed in this repo.
- `cloudflared`'s own ingress rules live in `apps/sandbox/cloudflared/cf.yaml` (sandbox-specific, mirrors the `external-secrets` `base/`+`sandbox/` split since the tunnel name/hostname/credentials are cluster-specific) — currently a single catch-all `*.miskers.org` rule forwarding to the Gateway's service; it doesn't itself do any access control.

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
