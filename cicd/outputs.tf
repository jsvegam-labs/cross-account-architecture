output "argocd_server_url" {
  description = "ArgoCD server URL"
  value       = "http://${helm_release.argocd.status[0].load_balancer[0].ingress[0].hostname}"
}

output "argocd_admin_password" {
  description = "ArgoCD admin password (get from secret)"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
  sensitive   = true
}

output "jenkins_url" {
  description = "Jenkins URL"
  value       = var.enable_jenkins ? "http://${helm_release.jenkins[0].status[0].load_balancer[0].ingress[0].hostname}:8080" : null
}