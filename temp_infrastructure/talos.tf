resource "talos_machine_configuration_apply" "this" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this.machine_configuration
  endpoint                    = var.node_ip
  node                        = var.node_ip

  apply_mode = "staged_if_needing_reboot"
}

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint             = var.node_ip
  node                 = var.node_ip

  depends_on = [talos_machine_configuration_apply.this]
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint             = var.node_ip
  node                 = var.node_ip

  depends_on = [talos_machine_bootstrap.this]
}
