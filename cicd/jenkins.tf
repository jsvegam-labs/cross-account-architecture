# Jenkins (opcional - solo si enable_jenkins = true)
resource "kubernetes_namespace" "jenkins" {
  count = var.enable_jenkins ? 1 : 0
  metadata {
    name = "jenkins"
  }
}

resource "helm_release" "jenkins" {
  count      = var.enable_jenkins ? 1 : 0
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  namespace  = kubernetes_namespace.jenkins[0].metadata[0].name
  version    = "5.7.15"

  values = [
    yamlencode({
      controller = {
        serviceType = "LoadBalancer"
        serviceAnnotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
        }
        resources = {
          requests = {
            cpu    = "50m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "1000m"
            memory = "1Gi"
          }
        }
        installPlugins = [
          "kubernetes:4246.v5a_12b_1fe120e",
          "workflow-aggregator:596.v8c21c963d92d",
          "git:5.4.1",
          "configuration-as-code:1810.v9b_c30a_249a_4c"
        ]
      }
      persistence = {
        enabled = true
        size    = "8Gi"
      }
    })
  ]

  depends_on = [kubernetes_namespace.jenkins]
}