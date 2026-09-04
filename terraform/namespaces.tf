resource "kubernetes_namespace_v1" "plataforma" {
  for_each = toset(local.namespaces)

  metadata {
    name   = each.value
    labels = local.common_labels
  }
}
