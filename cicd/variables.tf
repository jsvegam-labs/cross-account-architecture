variable "git_repo_url" {
  description = "Git repository URL for ArgoCD"
  type        = string
  default     = "https://github.com/your-username/your-app-repo"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "my-eks-cluster"
}

variable "enable_jenkins" {
  description = "Enable Jenkins deployment"
  type        = bool
  default     = false
}

variable "aws_profile" {
  description = "AWS CLI profile"
  type        = string
  default     = "default"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}