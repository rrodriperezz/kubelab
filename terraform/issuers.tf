# In production this would be an ACME ClusterIssuer against Let's Encrypt.
# Self-signed is enough locally because nobody outside has to trust the certificate.
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

# Wildcard instead of one certificate per host: any new Ingress in the
# environment reuses the same secret without waiting for an issuance.
resource "kubernetes_manifest" "certificate_wildcard" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "wildcard-base-domain"
      namespace = kubernetes_namespace_v1.platform["demo"].metadata[0].name
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
