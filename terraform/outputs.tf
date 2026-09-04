output "cluster_name" {
  description = "Nombre del cluster sobre el que se aplico la plataforma."
  value       = var.cluster_name
}

output "demo_url" {
  description = "URL de la aplicacion de ejemplo a traves del loadbalancer de k3d."
  value       = var.enable_demo_app ? "http://${local.demo_host}:8080" : null
}

output "ingress_class" {
  description = "IngressClass que atiende el trafico entrante."
  value       = "nginx"
}

output "installed_charts" {
  description = "Version efectiva de cada release de plataforma."
  value = {
    ingress-nginx  = helm_release.ingress_nginx.version
    cert-manager   = helm_release.cert_manager.version
    metrics-server = helm_release.metrics_server.version
  }
}
