locals {
  # Versions live here and not inside each helm_release so outputs.tf can
  # publish them without duplicating the number in two places.
  chart_versions = {
    ingress-nginx  = "4.11.3"  # verified 2026-09-04
    cert-manager   = "v1.16.1" # verified 2026-09-04
    metrics-server = "3.12.2"  # verified 2026-09-04
  }

  namespaces = ["ingress-nginx", "cert-manager", "monitoring", "demo"]

  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = var.cluster_name
  }

  demo_host = "demo.${var.base_domain}"

  # The certificate is issued for the wildcard, so any new subdomain in the
  # local environment reuses the same secret without a new issuance.
  wildcard_domain = "*.${var.base_domain}"
}
