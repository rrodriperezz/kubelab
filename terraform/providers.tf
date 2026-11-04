# Explicit path and context instead of the implicit environment (KUBECONFIG,
# current context): without this an apply can end up running against whatever
# other cluster happens to be selected on the machine.
provider "kubernetes" {
  config_path    = pathexpand(var.kubeconfig_path)
  config_context = var.kube_context
}

provider "helm" {
  kubernetes {
    config_path    = pathexpand(var.kubeconfig_path)
    config_context = var.kube_context
  }
}
