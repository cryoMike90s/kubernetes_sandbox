resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

data "talos_machine_configuration" "worker" {
  for_each = toset(var.worker_ips)

  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk                = var.install_disk
          grubUseUKICmdline   = false
          extraKernelArgs     = ["button.lid_init_state=open", "consoleblank=1"]
        }
      }
    }),

    yamlencode({
      machine = {
        network = {
          nameservers = var.nameservers
          interfaces = [
            {
              interface = "enp0s31f6"
              addresses = ["${each.key}/24"]
              routes = [
                {
                  network = "0.0.0.0/0"
                  gateway = var.gateway
                }
              ]
            }
          ]
        }
      }
    }),

    yamlencode({
      machine = {
        time = {
          servers = ["time.cloudflare.com", "time.google.com"]
        }
      }
    }),
  ]
}

data "talos_machine_configuration" "this" {
  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = [

    yamlencode({
      machine = {
        install = {
          disk = var.install_disk
        }
      }
    }),

    yamlencode({
      machine = {
        network = {
          nameservers = var.nameservers
        }
      }
    }),

    yamlencode({
      cluster = {
        allowSchedulingOnControlPlanes = true
      }
    }),

    yamlencode({
      cluster = {
        network = {
          podSubnets     = [var.pod_subnet]
          serviceSubnets = [var.service_subnet]
          cni = {
            name = "none"
          }
        }
      }
    }),


    yamlencode({
      machine = {
        time = {
          servers = ["time.cloudflare.com", "time.google.com"]
        }
      }
    }),
  ]
}
