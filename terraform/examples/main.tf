terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment for remote state management
  # backend "s3" {
  #   bucket         = "my-terraform-state-bucket"
  #   key            = "eks-cluster/terraform.tfstate"
  #   region         = "us-west-2"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = "EKS-Assessment"
    }
  }
}

# Create the EKS cluster using our module
module "eks_cluster" {
  source = "../modules/eks-cluster"

  cluster_name       = "${var.project_name}-${var.environment}"
  kubernetes_version = var.kubernetes_version

  # VPC Configuration
  vpc_cidr                 = var.vpc_cidr
  availability_zones_count = var.availability_zones_count

  # Cluster access configuration
  enable_public_access = var.enable_public_access
  public_access_cidrs  = var.public_access_cidrs

  # Node group configuration
  node_instance_types = var.node_instance_types
  node_capacity_type  = var.node_capacity_type
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  node_desired_size   = var.node_desired_size
  node_disk_size      = var.node_disk_size

  node_labels = {
    Environment = var.environment
    NodeGroup   = "primary"
  }

  # Logging configuration
  cluster_log_types   = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  log_retention_days  = var.log_retention_days

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Create IAM role for application deployments (IRSA example)
resource "aws_iam_role" "app_deploy" {
  name_prefix = "${var.project_name}-app-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = module.eks_cluster.oidc_provider_arn
      }
      Condition = {
        StringEquals = {
          "${replace(module.eks_cluster.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:${var.app_namespace}:${var.app_service_account}"
          "${replace(module.eks_cluster.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Environment = var.environment
    Purpose     = "Application deployment"
  }
}

# Example policy for application accessing AWS resources (e.g., S3)
resource "aws_iam_role_policy" "app_deploy" {
  name_prefix = "${var.project_name}-app-policy"
  role        = aws_iam_role.app_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::my-app-bucket/*",
          "arn:aws:s3:::my-app-bucket"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.project_name}/*"
      }
    ]
  })
}

# ECR repository for application images
resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = {
    Environment = var.environment
  }
}

# ECR lifecycle policy to manage image retention
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 30
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
