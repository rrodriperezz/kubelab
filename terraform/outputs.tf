output "cluster_name" {
  description = "Name of the cluster the platform was applied to."
  value       = var.cluster_name
}

output "demo_url" {
  description = "URL of the sample app through the k3d loadbalancer."
  value       = var.enable_demo_app ? "http://${local.demo_host}:8080" : null
}

output "ingress_class" {
  description = "IngressClass that serves incoming traffic."
  value       = "nginx"
}

output "installed_charts" {
  description = "Effective version of each platform release."
  value = {
    ingress-nginx  = helm_release.ingress_nginx.version
    cert-manager   = helm_release.cert_manager.version
    metrics-server = helm_release.metrics_server.version
  }
}
