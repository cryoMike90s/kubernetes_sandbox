variable "node_ip" {
  type        = string
  description = "Static IP address of your Talos node (e.g. '192.168.1.100'). The node must already have this IP before you apply."
}

variable "install_disk" {
  type        = string
  default     = "/dev/sda"
  description = "Block device where Talos will install itself. Use '/dev/nvme0n1' for NVMe drives. Run `talosctl disks` in maintenance mode to list available disks."
}

variable "cluster_name" {
  type        = string
  default     = "sandbox"
  description = "Human-readable name for the cluster. Used as the Kubernetes cluster name AND the node hostname."
}

variable "talos_version" {
  type        = string
  default     = "v1.8.0"
  description = "Talos Linux version to install. Check https://github.com/siderolabs/talos/releases for the latest."
}

variable "kubernetes_version" {
  type        = string
  default     = "v1.31.2"
  description = "Kubernetes version that Talos will run. Must be compatible with your chosen talos_version. See the Talos support matrix."
}

variable "pod_subnet" {
  type        = string
  default     = "10.244.0.0/16"
  description = "CIDR block for pod IPs. Pods get IPs from this range. Must not overlap with your LAN or service_subnet."
}

variable "service_subnet" {
  type        = string
  default     = "10.96.0.0/12"
  description = "CIDR block for Kubernetes Service (ClusterIP) IPs. Must not overlap with your LAN or pod_subnet."
}

variable "nameservers" {
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
  description = "DNS servers pushed to the node. Talos uses these for hostname resolution during and after install."
}

