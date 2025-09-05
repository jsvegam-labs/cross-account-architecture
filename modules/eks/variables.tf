# modules/eks/variables.tf
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.33"
}

variable "kubernetes_version" {
  type        = string
  default     = "1.33"
  description = "Versión de Kubernetes (major.minor) para el clúster EKS."
  validation {
    condition     = can(regex("^1\\.(30|31|32|33)$", var.kubernetes_version))
    error_message = "Usa una versión soportada: 1.30–1.33."
  }
}


variable "vpc_id" {
  description = "VPC ID where the cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the cluster"
  type        = list(string)
}

variable "desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "instance_types" {
  description = "List of EC2 instance types for worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "ami_type" {
  type        = string
  default     = "AL2023_x86_64_STANDARD"  # ✅ válido para 1.33
  description = "AMI type para Managed Node Groups."
  validation {
    condition = contains([
      "AL2_x86_64", "AL2_x86_64_GPU", "AL2_ARM_64",
      "CUSTOM",
      "BOTTLEROCKET_ARM_64", "BOTTLEROCKET_x86_64",
      "BOTTLEROCKET_ARM_64_FIPS", "BOTTLEROCKET_x86_64_FIPS",
      "BOTTLEROCKET_ARM_64_NVIDIA", "BOTTLEROCKET_x86_64_NVIDIA",
      "WINDOWS_CORE_2019_x86_64", "WINDOWS_FULL_2019_x86_64",
      "WINDOWS_CORE_2022_x86_64", "WINDOWS_FULL_2022_x86_64",
      "AL2023_x86_64_STANDARD", "AL2023_ARM_64_STANDARD",
      "AL2023_x86_64_NEURON", "AL2023_x86_64_NVIDIA", "AL2023_ARM_64_NVIDIA"
    ], var.ami_type)
    error_message = "Valor ami_type inválido."
  }
}


variable "capacity_type" {
  description = "Capacity type for nodes (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "disk_size" {
  description = "Disk size for worker nodes"
  type        = number
  default     = 20
}

variable "key_name" {
  description = "SSH key name for worker nodes"
  type        = string
  default     = null
}

variable "remote_access_sg_ids" {
  description = "List of security group IDs for remote access"
  type        = list(string)
  default     = []
}

variable "endpoint_private_access" {
  description = "Enable private access to the Kubernetes API server"
  type        = bool
  default     = false
}

variable "endpoint_public_access" {
  description = "Enable public access to the Kubernetes API server"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}