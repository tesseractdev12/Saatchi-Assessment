# IAM and RBAC Documentation

This document explains all IAM roles, policies, and Kubernetes RBAC configurations required for the EKS deployment.

## Overview

This infrastructure implements AWS IAM Roles for Service Accounts (IRSA), which allows Kubernetes service accounts to assume IAM roles without storing AWS credentials in the cluster.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS IAM                                   │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ EKS Cluster  │  │  Node Group  │  │  VPC CNI     │     │
│  │     Role     │  │     Role     │  │    Role      │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   EBS CSI    │  │   App Deploy │  │  GitHub      │     │
│  │    Role      │  │     Role     │  │  Actions     │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│                            ▲                                 │
└────────────────────────────┼─────────────────────────────────┘
                             │
                             │ OIDC Federation
                             │
┌────────────────────────────▼─────────────────────────────────┐
│                    Kubernetes (EKS)                          │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   aws-node   │  │   ebs-csi    │  │    app-sa    │     │
│  │ ServiceAcct  │  │ ServiceAcct  │  │ ServiceAcct  │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## AWS IAM Roles

### 1. EKS Cluster Role

**Purpose**: Allows EKS control plane to manage AWS resources on your behalf.

**Trust Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Service": "eks.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }]
}
```

**Attached Policies**:
- `AmazonEKSClusterPolicy` (AWS Managed)
- `AmazonEKSVPCResourceController` (AWS Managed)

**Permissions**:
- Create and manage ENIs for pod networking
- Manage security groups
- Create and manage load balancers
- Write logs to CloudWatch

**Created By**: `terraform/modules/eks-cluster/main.tf:154-169`

**Used By**: EKS Control Plane

---

### 2. Node Group Role

**Purpose**: Allows EKS worker nodes to join the cluster and pull container images.

**Trust Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Service": "ec2.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }]
}
```

**Attached Policies**:
- `AmazonEKSWorkerNodePolicy` (AWS Managed)
- `AmazonEKS_CNI_Policy` (AWS Managed)
- `AmazonEC2ContainerRegistryReadOnly` (AWS Managed)
- `CloudWatchAgentServerPolicy` (AWS Managed)
- `AmazonSSMManagedInstanceCore` (AWS Managed)

**Permissions**:
- Register nodes with EKS cluster
- Pull images from ECR
- Attach ENIs for VPC CNI
- Write logs to CloudWatch
- Allow SSM access for debugging

**Created By**: `terraform/modules/eks-cluster/main.tf:215-233`

**Used By**: EC2 instances in the node group

---

### 3. VPC CNI Role (IRSA)

**Purpose**: Allows VPC CNI plugin to manage ENIs and IP addresses for pods.

**Trust Policy** (with IRSA):
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/oidc.eks.REGION.amazonaws.com/id/OIDC_ID"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "oidc.eks.REGION.amazonaws.com/id/OIDC_ID:sub": "system:serviceaccount:kube-system:aws-node",
        "oidc.eks.REGION.amazonaws.com/id/OIDC_ID:aud": "sts.amazonaws.com"
      }
    }
  }]
}
```

**Attached Policies**:
- `AmazonEKS_CNI_Policy` (AWS Managed)

**Permissions**:
- Attach/Detach ENIs
- Assign/Unassign private IP addresses
- Describe EC2 instances and ENIs

**Created By**: `terraform/modules/eks-cluster/main.tf:397-419`

**Used By**: `aws-node` DaemonSet in `kube-system` namespace

---

### 4. EBS CSI Driver Role (IRSA)

**Purpose**: Allows EBS CSI driver to create and manage EBS volumes for persistent storage.

**Trust Policy** (with IRSA):
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/oidc.eks.REGION.amazonaws.com/id/OIDC_ID"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "oidc.eks.REGION.amazonaws.com/id/OIDC_ID:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa",
        "oidc.eks.REGION.amazonaws.com/id/OIDC_ID:aud": "sts.amazonaws.com"
      }
    }
  }]
}
```

**Attached Policies**:
- `AmazonEBSCSIDriverPolicy` (AWS Managed)

**Permissions**:
- Create/Delete EBS volumes
- Attach/Detach EBS volumes
- Create/Delete snapshots
- Describe volumes and snapshots

**Created By**: `terraform/modules/eks-cluster/main.tf:449-471`

**Used By**: EBS CSI Driver in `kube-system` namespace

---

### 5. Application Deployment Role (IRSA)

**Purpose**: Allows application pods to access AWS resources (S3, Secrets Manager, etc.).

**Trust Policy** (with IRSA):
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/oidc.eks.REGION.amazonaws.com/id/OIDC_ID"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "oidc.eks.REGION.amazonaws.com/id/OIDC_ID:sub": "system:serviceaccount:default:app-sa",
        "oidc.eks.REGION.amazonaws.com/id/OIDC_ID:aud": "sts.amazonaws.com"
      }
    }
  }]
}
```

**Custom Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-app-bucket/*",
        "arn:aws:s3:::my-app-bucket"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:REGION:ACCOUNT_ID:secret:eks-assessment/*"
    }
  ]
}
```

**Created By**: `terraform/examples/main.tf:60-104`

**Used By**: Application pods using `app-sa` service account

---

### 6. GitHub Actions Role (OIDC)

**Purpose**: Allows GitHub Actions workflows to deploy to AWS without long-lived credentials.

**Trust Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:*"
      }
    }
  }]
}
```

**Required Permissions**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters",
        "eks:DescribeNodegroup",
        "eks:ListNodegroups"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    }
  ]
}
```

**Created By**: Manual (see DEPLOYMENT_GUIDE.md)

**Used By**: GitHub Actions workflows

---

## Kubernetes RBAC

### Default Service Account Permissions

The application uses a custom service account `app-sa` which is bound to the IAM role via IRSA.

**Service Account Definition**:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/eks-assessment-dev-app-deploy"
```

**Location**: `k8s/base/serviceaccount.yaml`

### Additional RBAC (if needed)

For application-specific Kubernetes API access, create ClusterRole/Role:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-role
  namespace: default
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-rolebinding
  namespace: default
subjects:
- kind: ServiceAccount
  name: app-sa
  namespace: default
roleRef:
  kind: Role
  name: app-role
  apiGroup: rbac.authorization.k8s.io
```

---

## OIDC Provider

### EKS OIDC Provider

The OIDC provider enables IRSA by allowing Kubernetes service accounts to assume IAM roles.

**Created By**: `terraform/modules/eks-cluster/main.tf:377-390`

**Configuration**:
- **Issuer URL**: Retrieved from EKS cluster
- **Client ID**: `sts.amazonaws.com`
- **Thumbprint**: Automatically retrieved from TLS certificate

**How It Works**:
1. Pod starts with service account annotation
2. EKS injects AWS credentials via webhook
3. AWS SDK uses Web Identity Token to assume IAM role
4. Temporary credentials are provided to the pod

---

## Permission Boundaries

### Production Recommendations

1. **Implement Permission Boundaries** for all IAM roles:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "*",
    "Resource": "*",
    "Condition": {
      "StringEquals": {
        "aws:RequestedRegion": ["us-west-2"]
      }
    }
  }]
}
```

2. **Add Resource Tags** for all IAM roles:
```hcl
tags = {
  Environment = "production"
  ManagedBy   = "Terraform"
  Owner       = "platform-team"
}
```

3. **Enable AWS CloudTrail** to audit IAM actions

4. **Implement SCP** (Service Control Policies) at organization level

---

## Security Best Practices

### 1. Least Privilege Principle

Each role has only the minimum permissions required:
- ✅ Cluster role: Only EKS control plane actions
- ✅ Node role: Only node operations
- ✅ VPC CNI: Only networking actions
- ✅ EBS CSI: Only volume operations
- ✅ App role: Only specific application resources

### 2. No Long-Lived Credentials

- ✅ Using IRSA instead of storing AWS access keys
- ✅ Temporary credentials automatically rotated
- ✅ No secrets in ConfigMaps or environment variables

### 3. Role Separation

- ✅ Different roles for different components
- ✅ No role reuse across services
- ✅ Clear role naming conventions

### 4. Audit Logging

- ✅ EKS control plane logs to CloudWatch
- ✅ CloudTrail for AWS API calls
- ✅ Kubernetes audit logs enabled

---

## Troubleshooting IAM/RBAC Issues

### Issue: Pod Cannot Assume IAM Role

**Symptoms**:
```
An error occurred (AccessDenied) when calling the GetObject operation
```

**Debug Steps**:

1. Verify OIDC provider exists:
```bash
aws eks describe-cluster --name eks-assessment-dev \
  --query "cluster.identity.oidc.issuer" --output text
```

2. Check service account annotation:
```bash
kubectl get sa app-sa -n default -o yaml
```

3. Verify IAM role trust policy:
```bash
aws iam get-role --role-name eks-assessment-dev-app-deploy
```

4. Check pod environment variables:
```bash
kubectl exec -it <pod-name> -- env | grep AWS
```

Should show:
- `AWS_ROLE_ARN`
- `AWS_WEB_IDENTITY_TOKEN_FILE`

### Issue: Node Cannot Join Cluster

**Symptoms**:
```
Node NotReady
```

**Debug Steps**:

1. Check node IAM role has required policies:
```bash
aws iam list-attached-role-policies --role-name eks-assessment-dev-node-role
```

2. Verify security groups allow node communication

3. Check node logs:
```bash
kubectl logs -n kube-system aws-node-<pod-id>
```

### Issue: GitHub Actions Cannot Deploy

**Symptoms**:
```
Error: could not get token: AccessDenied
```

**Debug Steps**:

1. Verify OIDC provider for GitHub exists
2. Check GitHub Actions role trust policy includes your repo
3. Verify role has required permissions
4. Check GitHub secrets are set correctly

---

## IAM Role ARN Reference

After deployment, get role ARNs:

```bash
cd terraform/examples

# Cluster role
terraform output -raw cluster_arn

# Node role
terraform output -raw node_role_arn

# App deployment role
terraform output -raw app_deploy_role_arn

# OIDC provider
terraform output -raw oidc_provider_arn
```

---

## Adding New Service Accounts

To add a new service account with IRSA:

1. **Create IAM role** in `terraform/examples/main.tf`:
```hcl
resource "aws_iam_role" "new_service_role" {
  name_prefix = "${var.project_name}-new-service"
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
          "${replace(module.eks_cluster.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:NAMESPACE:SERVICE_ACCOUNT_NAME"
        }
      }
    }]
  })
}
```

2. **Attach policies** to the role

3. **Create Kubernetes service account**:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: new-service-sa
  namespace: your-namespace
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/new-service-role"
```

4. **Use in deployment**:
```yaml
spec:
  serviceAccountName: new-service-sa
```

---

## Summary

This infrastructure implements a comprehensive IAM and RBAC strategy using:

- ✅ **IRSA** for secure AWS access from pods
- ✅ **OIDC** for GitHub Actions authentication
- ✅ **Least privilege** IAM policies
- ✅ **Role separation** for different components
- ✅ **No long-lived credentials** in the cluster
- ✅ **Audit logging** for all access

All IAM roles are managed by Terraform for infrastructure as code best practices.
