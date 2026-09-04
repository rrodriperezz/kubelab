# Ruta y contexto explicitos en vez de las variables de entorno implicitas
# (KUBECONFIG, contexto actual): sin esto un apply puede terminar aplicando
# sobre otro cluster que este seleccionado en la maquina.
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
