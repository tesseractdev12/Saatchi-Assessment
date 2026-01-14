variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "eks-assessment"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones_count" {
  description = "Number of availability zones"
  type        = number
  default     = 3
}

variable "enable_public_access" {
  description = "Enable public access to cluster endpoint"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to access cluster endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_instance_types" {
  description = "Instance types for node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_capacity_type" {
  description = "Capacity type (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "node_min_size" {
  description = "Minimum nodes in node group"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum nodes in node group"
  type        = number
  default     = 10
}

variable "node_desired_size" {
  description = "Desired nodes in node group"
  type        = number
  default     = 2
}

variable "node_disk_size" {
  description = "Node disk size in GB"
  type        = number
  default     = 50
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "app_namespace" {
  description = "Kubernetes namespace for application"
  type        = string
  default     = "default"
}

variable "app_service_account" {
  description = "Kubernetes service account for application"
  type        = string
  default     = "app-sa"
}
