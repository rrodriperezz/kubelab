variable "cluster_name" {
  description = "Name of the k3d cluster. Must match cluster/k3d-config.yaml."
  type        = string
  default     = "platform"
}

variable "kubeconfig_path" {
  description = "Path to the kubeconfig used by the kubernetes and helm providers."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Context inside the kubeconfig. k3d names it k3d-<cluster>."
  type        = string
  default     = "k3d-platform"
}

variable "base_domain" {
  description = "Base domain for the Ingresses. localtest.me resolves to 127.0.0.1."
  type        = string
  default     = "localtest.me"
}

variable "enable_demo_app" {
  description = "Install the sample app with its Ingress and HPA."
  type        = bool
  default     = true
}

variable "demo_replicas" {
  description = "Initial replicas of the sample app."
  type        = number
  default     = 2

  validation {
    condition     = var.demo_replicas >= 1 && var.demo_replicas <= 10
    error_message = "demo_replicas must be between 1 and 10."
  }
}

variable "helm_timeout_seconds" {
  description = "Maximum wait per Helm release before aborting and rolling back."
  type        = number
  default     = 300

  validation {
    condition     = var.helm_timeout_seconds >= 60
    error_message = "helm_timeout_seconds must be at least 60."
  }
}
