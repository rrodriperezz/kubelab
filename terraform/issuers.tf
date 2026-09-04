# En produccion esto seria un ClusterIssuer ACME contra Let's Encrypt. Autofirmado
# alcanza en local porque nadie externo tiene que confiar en el certificado.
resource "kubernetes_manifest" "clusterissuer_selfsigned" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name   = "selfsigned"
      labels = local.common_labels
    }
    spec = {
      selfSigned = {}
    }
  }

  depends_on = [helm_release.cert_manager]
}

# Comodin en vez de un certificado por host: cualquier Ingress nuevo del entorno
# reutiliza el mismo secreto sin esperar una emision.
resource "kubernetes_manifest" "certificate_wildcard" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "wildcard-base-domain"
      namespace = kubernetes_namespace_v1.plataforma["demo"].metadata[0].name
      labels    = local.common_labels
    }
    spec = {
      secretName = "wildcard-base-domain-tls"
      commonName = local.wildcard_domain
      dnsNames = [
        local.wildcard_domain,
        var.base_domain,
      ]
      issuerRef = {
        name  = "selfsigned"
        kind  = "ClusterIssuer"
        group = "cert-manager.io"
      }
    }
  }

  depends_on = [kubernetes_manifest.clusterissuer_selfsigned]
}
