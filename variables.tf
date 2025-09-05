variable "kubernetes_version" {
  type        = string
  default     = "1.33"
  description = "Versión de Kubernetes para el clúster EKS (major.minor)."
}
