variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Primary Azure region"
  type        = string
  default     = "australiaeast"
}

variable "prefix" {
  description = "Naming prefix for all resources"
  type        = string
  default     = "fleetnohub"
}

variable "kubernetes_version" {
  description = "Initial Kubernetes version for fleet member AKS clusters. Use an older version (e.g. 1.31) to enable both node image and K8s version upgrade demos."
  type        = string
  default     = "1.32"
}

variable "node_vm_size" {
  description = "VM size for AKS node pools — use D4s_v3 for faster upgrades"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "monitor_node_vm_size" {
  description = "VM size for monitoring cluster"
  type        = string
  default     = "Standard_D2s_v3"
}
