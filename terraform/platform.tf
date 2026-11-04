resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = local.chart_versions["ingress-nginx"]
  namespace  = kubernetes_namespace_v1.platform["ingress-nginx"].metadata[0].name

  values = [file("${path.module}/values/ingress-nginx.yaml")]

  timeout = var.helm_timeout_seconds
  wait    = true

  # A half-installed release leaves the cluster in a state the next apply
  # cannot reconcile; atomic rolls back and keeps the error visible.
  atomic = true

  depends_on = [kubernetes_namespace_v1.platform]
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = local.chart_versions["cert-manager"]
  namespace  = kubernetes_namespace_v1.platform["cert-manager"].metadata[0].name

  values = [file("${path.module}/values/cert-manager.yaml")]

  timeout = var.helm_timeout_seconds
  wait    = true
  atomic  = true

  depends_on = [kubernetes_namespace_v1.platform]
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = local.chart_versions["metrics-server"]
  namespace  = kubernetes_namespace_v1.platform["monitoring"].metadata[0].name

  values = [file("${path.module}/values/metrics-server.yaml")]

  timeout = var.helm_timeout_seconds
  wait    = true
  atomic  = true

  depends_on = [kubernetes_namespace_v1.platform]
}
