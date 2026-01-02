output "argocd_server_url" {
  description = "ArgoCD server URL"
  value       = "Get URL with: kubectl get svc argocd-server -n argocd"
}

output "argocd_admin_password" {
  description = "ArgoCD admin password (get from secret)"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
  sensitive   = true
}

output "jenkins_url" {
  description = "Jenkins URL"
  value       = var.enable_jenkins ? "Get URL with: kubectl get svc jenkins -n jenkins" : "Jenkins not enabled"
}