output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks_cluster.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS cluster API server"
  value       = module.eks_cluster.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for cluster authentication"
  value       = module.eks_cluster.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the cluster (used for IRSA)"
  value       = module.eks_cluster.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider (used for IRSA)"
  value       = module.eks_cluster.oidc_provider_arn
}

output "vpc_id" {
  description = "VPC ID where cluster is deployed"
  value       = module.eks_cluster.vpc_id
}

output "node_role_arn" {
  description = "IAM role ARN for EKS nodes"
  value       = module.eks_cluster.node_role_arn
}

output "ecr_repository_url" {
  description = "URL of the ECR repository for application images"
  value       = aws_ecr_repository.app.repository_url
}

output "app_deploy_role_arn" {
  description = "IAM role ARN for application deployments (IRSA)"
  value       = aws_iam_role.app_deploy.arn
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks_cluster.cluster_id}"
}
