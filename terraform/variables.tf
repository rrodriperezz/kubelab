variable "cluster_name" {
  description = "Nombre del cluster k3d. Tiene que coincidir con cluster/k3d-config.yaml."
  type        = string
  default     = "plataforma"
}

variable "kubeconfig_path" {
  description = "Ruta al kubeconfig que usan los provedores de kubernetes y helm."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Contexto dentro del kubeconfig. k3d lo nombra k3d-<cluster>."
  type        = string
  default     = "k3d-plataforma"
}

variable "base_domain" {
  description = "Dominio base de los Ingress. localtest.me resuelve a 127.0.0.1."
  type        = string
  default     = "localtest.me"
}

variable "enable_demo_app" {
  description = "Instala la aplicacion de ejemplo con su Ingress y su HPA."
  type        = bool
  default     = true
}

variable "demo_replicas" {
  description = "Replicas iniciales de la aplicacion de ejemplo."
  type        = number
  default     = 2

  validation {
    condition     = var.demo_replicas >= 1 && var.demo_replicas <= 10
    error_message = "demo_replicas tiene que estar entre 1 y 10."
  }
}

variable "helm_timeout_seconds" {
  description = "Espera maxima por release de Helm antes de abortar y hacer rollback."
  type        = number
  default     = 300

  validation {
    condition     = var.helm_timeout_seconds >= 60
    error_message = "helm_timeout_seconds tiene que ser de al menos 60."
  }
}
