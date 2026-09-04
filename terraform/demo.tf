locals {
  demo_enabled = var.enable_demo_app ? 1 : 0

  demo_labels = merge(local.common_labels, {
    "app.kubernetes.io/name" = "demo"
  })
}

resource "kubernetes_deployment_v1" "demo" {
  count = local.demo_enabled

  metadata {
    name      = "demo"
    namespace = kubernetes_namespace_v1.plataforma["demo"].metadata[0].name
    labels    = local.demo_labels
  }

  spec {
    replicas = var.demo_replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "demo"
      }
    }

    template {
      metadata {
        labels = local.demo_labels
      }

      spec {
        automount_service_account_token = false

        security_context {
          run_as_non_root = true
          run_as_user     = 101
          fs_group        = 101
        }

        container {
          name = "nginx"
          # nginx-unprivileged escucha en 8080 y corre como usuario 101, que es lo
          # que permite el runAsNonRoot de arriba. La imagen oficial de nginx
          # necesita root para escribir el pid y no arrancaria.
          # El tag queda por legibilidad, pero lo que fija la version es el digest:
          # un tag movil hace que dos nodos del cluster corran binarios distintos.
          image = join("@", [
            "ghcr.io/nginxinc/nginx-unprivileged:1.27-alpine",
            "sha256:e234d4f7e346c098f7b22245690372382aded5be988611eb2c53ae62231eece7",
          ])

          image_pull_policy = "Always"

          port {
            name           = "http"
            container_port = 8080
          }

          resources {
            requests = {
              cpu    = "25m"
              memory = "32Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/"
              port = "http"
            }
            initial_delay_seconds = 2
            period_seconds        = 5
          }

          liveness_probe {
            http_get {
              path = "/"
              port = "http"
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          security_context {
            run_as_non_root            = true
            run_as_user                = 101
            read_only_root_filesystem  = true
            allow_privilege_escalation = false

            capabilities {
              drop = ["ALL"]
            }
          }

          # Con el rootfs de solo lectura nginx no puede escribir sus temporales ni
          # su pid, y entra en CrashLoopBackOff sin estos tres volumenes.
          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "cache"
            mount_path = "/var/cache/nginx"
          }

          volume_mount {
            name       = "run"
            mount_path = "/var/run"
          }
        }

        volume {
          name = "tmp"
          empty_dir {}
        }

        volume {
          name = "cache"
          empty_dir {}
        }

        volume {
          name = "run"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "demo" {
  count = local.demo_enabled

  metadata {
    name      = "demo"
    namespace = kubernetes_namespace_v1.plataforma["demo"].metadata[0].name
    labels    = local.demo_labels
  }

  spec {
    type = "ClusterIP"

    selector = {
      "app.kubernetes.io/name" = "demo"
    }

    port {
      name        = "http"
      port        = 80
      target_port = "http"
    }
  }
}

resource "kubernetes_ingress_v1" "demo" {
  count = local.demo_enabled

  metadata {
    name      = "demo"
    namespace = kubernetes_namespace_v1.plataforma["demo"].metadata[0].name
    labels    = local.demo_labels

    annotations = {
      "cert-manager.io/cluster-issuer" = "selfsigned"

      # ingress-nginx redirige a https://demo.localtest.me sin puerto, y en local
      # el 443 del cluster se publica en el 8443 del host: el redirect apuntaria a
      # un puerto donde no escucha nadie. El sitio sigue disponible por TLS en
      # https://demo.localtest.me:8443.
      "nginx.ingress.kubernetes.io/ssl-redirect" = "false"
    }
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      hosts       = [local.demo_host]
      secret_name = "demo-tls"
    }

    rule {
      host = local.demo_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.demo[0].metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.ingress_nginx, kubernetes_manifest.clusterissuer_selfsigned]
}

# El HPA existe para demostrar que metrics-server responde: sin metricas el
# objetivo queda en <unknown> y el smoke test lo detecta.
resource "kubernetes_horizontal_pod_autoscaler_v2" "demo" {
  count = local.demo_enabled

  metadata {
    name      = "demo"
    namespace = kubernetes_namespace_v1.plataforma["demo"].metadata[0].name
    labels    = local.demo_labels
  }

  spec {
    min_replicas = 2
    max_replicas = 5

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.demo[0].metadata[0].name
    }

    metric {
      type = "Resource"

      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }
  }

  depends_on = [helm_release.metrics_server]
}
