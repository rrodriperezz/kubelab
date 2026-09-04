locals {
  # Las versiones viven aca y no dentro de cada helm_release para que outputs.tf
  # pueda publicarlas sin duplicar el numero en dos lugares.
  chart_versions = {
    ingress-nginx  = "4.11.3"  # verificado 2026-09-04
    cert-manager   = "v1.16.1" # verificado 2026-09-04
    metrics-server = "3.12.2"  # verificado 2026-09-04
  }

  namespaces = ["ingress-nginx", "cert-manager", "monitoring", "demo"]

  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = var.cluster_name
  }

  demo_host = "demo.${var.base_domain}"

  # El certificado se emite para el comodin, asi cualquier subdominio nuevo del
  # entorno local reutiliza el mismo secreto sin volver a emitir.
  wildcard_domain = "*.${var.base_domain}"
}
