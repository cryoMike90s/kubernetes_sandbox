data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [var.node_ip]
  nodes                = [var.node_ip]
}

# WARNING: This overwrites any existing kubeconfig at that path.
# If you manage multiple clusters, consider changing `filename` to something
# like "${pathexpand("~")}/.kube/${var.cluster_name}.yaml" and merging manually.
# -----------------------------------------------------------------------------

resource "local_file" "kubeconfig" {
  content         = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename        = pathexpand("~/.kube/config")
  file_permission = "0600" # kubeconfig contains credentials — keep it private
}

resource "local_file" "talosconfig" {
  content         = data.talos_client_configuration.this.talos_config
  filename        = pathexpand("~/.talos/config")
  file_permission = "0600"
}

output "kubeconfig_raw" {
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
  description = "Raw kubeconfig YAML. Use: tofu output -raw kubeconfig_raw > /tmp/kube.yaml"
}

output "talosconfig_raw" {
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
  description = "Raw talosconfig YAML. Use: tofu output -raw talosconfig_raw > /tmp/talos.yaml"
}

output "cluster_endpoint" {
  value       = local.cluster_endpoint
  description = "Kubernetes API server address."
}

output "node_ip" {
  value       = var.node_ip
  description = "Talos node IP address."
}
