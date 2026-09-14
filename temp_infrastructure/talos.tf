resource "talos_machine_configuration_apply" "worker" {
  for_each = toset(var.worker_ips)

  client_configuration        = talos_machine_secrets.controlplane.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[each.key].machine_configuration
  endpoint                    = each.key
  node                        = each.key

  apply_mode = "auto"

  depends_on = [talos_machine_bootstrap.controlplane]
}

resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = talos_machine_secrets.controlplane.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  endpoint                    = var.node_ip
  node                        = var.node_ip

  apply_mode = "auto"
}

resource "talos_machine_bootstrap" "controlplane" {
  client_configuration = talos_machine_secrets.controlplane.client_configuration
  endpoint             = var.node_ip
  node                 = var.node_ip

  depends_on = [talos_machine_configuration_apply.controlplane]
}

resource "talos_cluster_kubeconfig" "controlplane" {
  client_configuration = talos_machine_secrets.controlplane.client_configuration
  endpoint             = var.node_ip
  node                 = var.node_ip

  depends_on = [talos_machine_bootstrap.controlplane]
}
