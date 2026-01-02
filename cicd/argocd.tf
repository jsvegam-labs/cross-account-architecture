# ArgoCD deployment in EKS
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "7.7.8"
  timeout    = 900  # 15 minutos
  wait       = true

  values = [
    yamlencode({
      server = {
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
          }
        }
        extraArgs = [
          "--insecure"
        ]
      }
      configs = {
        params = {
          "server.insecure" = true
        }
      }
      # Reducir recursos para evitar problemas
      controller = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }
      server = {
        resources = {
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
          }
        }
        extraArgs = [
          "--insecure"
        ]
      }
    })
  ]

  depends_on = [kubernetes_namespace.argocd]
}

# ArgoCD Application for auto-deployment (deploy this after ArgoCD is running)
# resource "kubernetes_manifest" "app_of_apps" {
#   manifest = {
#     apiVersion = "argoproj.io/v1alpha1"
#     kind       = "Application"
#     metadata = {
#       name      = "app-of-apps"
#       namespace = "argocd"
#     }
#     spec = {
#       project = "default"
#       source = {
#         repoURL        = var.git_repo_url
#         targetRevision = "HEAD"
#         path           = "k8s/applications"
#       }
#       destination = {
#         server    = "https://kubernetes.default.svc"
#         namespace = "argocd"
#       }
#       syncPolicy = {
#         automated = {
#           prune    = true
#           selfHeal = true
#         }
#       }
#     }
#   }

#   depends_on = [helm_release.argocd]
# }