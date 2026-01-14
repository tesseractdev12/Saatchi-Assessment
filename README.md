# DevOps Engineer Technical Assessment - EKS Kubernetes Deployment Pipeline

## Overview

This repository contains a production-ready, secure, and scalable infrastructure-as-code solution for deploying containerized applications to Amazon EKS (Elastic Kubernetes Service). The implementation demonstrates best practices in cloud infrastructure, CI/CD automation, security, and observability.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud (us-west-2)                           │
│                                                                               │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                         VPC (10.0.0.0/16)                               │ │
│  │                                                                          │ │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐        │ │
│  │  │  Public Subnet  │  │  Public Subnet  │  │  Public Subnet  │        │ │
│  │  │    (AZ-1)       │  │    (AZ-2)       │  │    (AZ-3)       │        │ │
│  │  │                 │  │                 │  │                 │        │ │
│  │  │  ┌───────────┐  │  │  ┌───────────┐  │  │  ┌───────────┐  │        │ │
│  │  │  │ NAT GW    │  │  │  │ NAT GW    │  │  │  │ NAT GW    │  │        │ │
│  │  │  └───────────┘  │  │  └───────────┘  │  │  └───────────┘  │        │ │
│  │  │  ┌───────────┐  │  │  ┌───────────┐  │  │  ┌───────────┐  │        │ │
│  │  │  │ ALB       │◄─┼──┼──┤ ALB       │◄─┼──┼──┤ ALB       │  │        │ │
│  │  │  └───────────┘  │  │  └───────────┘  │  │  └───────────┘  │        │ │
│  │  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘        │ │
│  │           │                    │                    │                   │ │
│  │  ┌────────▼────────┐  ┌────────▼────────┐  ┌────────▼────────┐        │ │
│  │  │ Private Subnet  │  │ Private Subnet  │  │ Private Subnet  │        │ │
│  │  │    (AZ-1)       │  │    (AZ-2)       │  │    (AZ-3)       │        │ │
│  │  │                 │  │                 │  │                 │        │ │
│  │  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │        │ │
│  │  │ │ EKS Node    │ │  │ │ EKS Node    │ │  │ │ EKS Node    │ │        │ │
│  │  │ │  (t3.med)   │ │  │ │  (t3.med)   │ │  │ │  (t3.med)   │ │        │ │
│  │  │ │             │ │  │ │             │ │  │ │             │ │        │ │
│  │  │ │ ┌─────────┐ │ │  │ │ ┌─────────┐ │ │  │ │ ┌─────────┐ │ │        │ │
│  │  │ │ │demo-app │ │ │  │ │ │demo-app │ │ │  │ │ │demo-app │ │ │        │ │
│  │  │ │ │ pods    │ │ │  │ │ │ pods    │ │ │  │ │ │ pods    │ │ │        │ │
│  │  │ │ └─────────┘ │ │  │ │ └─────────┘ │ │  │ │ └─────────┘ │ │        │ │
│  │  │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │        │ │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘        │ │
│  │                                                                          │ │
│  │  ┌──────────────────────────────────────────────────────────────────┐  │ │
│  │  │                    EKS Control Plane                             │  │ │
│  │  │  • API Server (Private + Public endpoint)                        │  │ │
│  │  │  • etcd (Encrypted at rest with KMS)                             │  │ │
│  │  │  • Control Plane Logs → CloudWatch                               │  │ │
│  │  └──────────────────────────────────────────────────────────────────┘  │ │
│  │                                                                          │ │
│  └──────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │     ECR      │  │     KMS      │  │  CloudWatch │  │  IAM/IRSA   │     │
│  │ (Container   │  │ (Encryption  │  │   (Logs &   │  │  (Workload  │     │
│  │  Registry)   │  │    Keys)     │  │   Metrics)  │  │  Identity)  │     │
│  └──────────────┘  └──────────────┘  └─────────────┘  └─────────────┘     │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘

                                    ▲
                                    │
                                    │
┌───────────────────────────────────┴───────────────────────────────────────────┐
│                           GitHub Actions CI/CD                                 │
│                                                                                 │
│  ┌──────────────┐   ┌───────────────┐   ┌──────────────┐   ┌─────────────┐  │
│  │   Terraform  │──▶│   Security    │──▶│ Docker Build │──▶│   Deploy    │  │
│  │  Plan/Apply  │   │   Scanning    │   │  & Push ECR  │   │  to EKS     │  │
│  │              │   │ (Trivy/tfsec) │   │              │   │             │  │
│  └──────────────┘   └───────────────┘   └──────────────┘   └─────────────┘  │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Deployment Flow

```
Developer Push → GitHub
                    │
                    ▼
        ┌───────────────────────┐
        │  GitHub Actions       │
        │  Workflow Triggered   │
        └───────────┬───────────┘
                    │
                    ├─────────────────────────────────────────┐
                    ▼                                         ▼
        ┌───────────────────────┐             ┌───────────────────────┐
        │  Terraform Pipeline   │             │   Application Build   │
        │  (Infrastructure)     │             │      Pipeline         │
        └───────────┬───────────┘             └───────────┬───────────┘
                    │                                     │
                    ▼                                     ▼
        ┌───────────────────────┐             ┌───────────────────────┐
        │  Security Scanning    │             │  Security Scanning    │
        │  • tfsec              │             │  • Trivy (fs)         │
        │  • Checkov            │             │  • Semgrep (SAST)     │
        └───────────┬───────────┘             └───────────┬───────────┘
                    │                                     │
                    ▼                                     ▼
        ┌───────────────────────┐             ┌───────────────────────┐
        │  terraform plan       │             │  Docker Build         │
        │  (on PR)              │             │  Multi-arch Support   │
        └───────────┬───────────┘             └───────────┬───────────┘
                    │                                     │
                    ▼                                     ▼
        ┌───────────────────────┐             ┌───────────────────────┐
        │  Infracost Analysis   │             │  Push to ECR          │
        │  (Cost Estimation)    │             │  (Encrypted)          │
        └───────────┬───────────┘             └───────────┬───────────┘
                    │                                     │
                    ▼                                     ▼
        ┌───────────────────────┐             ┌───────────────────────┐
        │  terraform apply      │             │  Image Scanning       │
        │  (on merge to main)   │             │  • Trivy (image)      │
        └───────────┬───────────┘             └───────────┬───────────┘
                    │                                     │
                    │                                     ▼
                    │                         ┌───────────────────────┐
                    │                         │  kubectl/Helm Deploy  │
                    │                         │  Rolling Update       │
                    │                         └───────────┬───────────┘
                    │                                     │
                    └─────────────┬───────────────────────┘
                                  │
                                  ▼
                    ┌─────────────────────────┐
                    │   Application Running   │
                    │   on EKS Cluster        │
                    └─────────────────────────┘
```

## Features

### Infrastructure (Terraform)

✅ **Private EKS Cluster**
- Multi-AZ deployment across 3 availability zones
- Private worker nodes in private subnets
- Configurable public/private API endpoint access
- Network isolation with security groups

✅ **Security Best Practices**
- Encryption at rest using AWS KMS for:
  - EKS secrets
  - EBS volumes
  - ECR images
- IAM Roles for Service Accounts (IRSA) for workload identity
- Network policies enforcement
- IMDSv2 enforced on EC2 instances
- Security group rules following least-privilege principle

✅ **Autoscaling**
- EKS Node Group autoscaling (min: 2, max: 10)
- Horizontal Pod Autoscaler (HPA) for application pods
- Cluster Autoscaler ready configuration

✅ **High Availability**
- Multi-AZ deployment
- NAT Gateways in each AZ
- Pod anti-affinity rules
- Rolling update strategy with zero downtime

✅ **Observability**
- CloudWatch log group for control plane logs
- Prometheus + Grafana monitoring stack
- Application metrics exposed
- Custom dashboards included

### CI/CD Pipeline

✅ **Terraform Automation**
- Automated `terraform plan` on pull requests
- Automated `terraform apply` on merge to main
- State locking and remote state support
- Cost estimation with Infracost

✅ **Security Scanning**
- **tfsec**: Terraform security scanning
- **Checkov**: Infrastructure security policies
- **Trivy**: Filesystem and container image vulnerability scanning
- **Semgrep**: Static application security testing (SAST)
- Results uploaded to GitHub Security tab

✅ **Container Build Pipeline**
- Multi-stage Docker builds for optimal image size
- Multi-architecture support (amd64/arm64)
- Automated push to Amazon ECR
- Image tagging strategy (git sha, branch, semantic version)
- Build caching with GitHub Actions cache

✅ **Kubernetes Deployment**
- Automated kubectl deployments
- Rolling updates with health checks
- Blue-green deployment strategy (bonus feature)
- Post-deployment validation

## Project Structure

```
.
├── .github/
│   └── workflows/
│       ├── terraform.yml          # Infrastructure CI/CD pipeline
│       └── build-deploy.yml       # Application build & deploy pipeline
│
├── .infracost/
│   ├── infracost.yml              # Infracost configuration
│   └── infracost-usage.yml        # Usage estimates for cost calculation
│
├── terraform/
│   ├── modules/
│   │   └── eks-cluster/
│   │       ├── main.tf            # Main EKS cluster resources
│   │       ├── variables.tf       # Input variables
│   │       ├── outputs.tf         # Output values
│   │       └── userdata.sh        # Node bootstrap script
│   │
│   └── examples/
│       ├── main.tf                # Example cluster deployment
│       ├── variables.tf           # Environment-specific variables
│       ├── outputs.tf             # Outputs for CI/CD
│       └── terraform.tfvars.example  # Sample configuration
│
├── app/
│   ├── Dockerfile                 # Multi-stage container build
│   ├── package.json               # Node.js dependencies
│   ├── server.js                  # Demo application
│   ├── healthcheck.js             # Container health check
│   └── .dockerignore              # Build exclusions
│
├── k8s/
│   ├── base/
│   │   ├── namespace.yaml         # Kubernetes namespace
│   │   ├── serviceaccount.yaml    # Service account with IRSA
│   │   ├── deployment.yaml        # Application deployment
│   │   ├── service.yaml           # ClusterIP service
│   │   ├── ingress.yaml           # ALB ingress controller
│   │   ├── hpa.yaml               # Horizontal Pod Autoscaler
│   │   └── network-policy.yaml    # Network policies
│   │
│   └── monitoring/
│       ├── prometheus-values.yaml # Prometheus Helm values
│       ├── install-monitoring.sh  # Monitoring setup script
│       └── application-dashboard.json  # Grafana dashboard
│
└── README.md                      # This file
```

## Prerequisites

- AWS Account with appropriate permissions
- GitHub repository with Actions enabled
- Required tools (for local development):
  - Terraform >= 1.0
  - kubectl >= 1.28
  - AWS CLI v2
  - Docker
  - Helm 3

## Setup Instructions

### 1. Configure AWS Credentials

#### Option A: OIDC with GitHub Actions (Recommended)

```bash
# Create OIDC provider and IAM role for GitHub Actions
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# Create IAM role with trust policy for GitHub Actions
# Replace YOUR_GITHUB_ORG and YOUR_REPO
```

Trust policy example:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
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
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/YOUR_REPO:*"
        }
      }
    }
  ]
}
```

#### Option B: Access Keys (Not Recommended for Production)

Store in GitHub Secrets:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

### 2. Configure GitHub Secrets

Add the following secrets to your GitHub repository:

```
AWS_ROLE_ARN              # IAM role ARN for GitHub Actions (if using OIDC)
EKS_CLUSTER_NAME          # Name of your EKS cluster (eks-assessment-dev)
INFRACOST_API_KEY         # API key from Infracost (optional)
```

### 3. Configure Terraform Backend (Optional but Recommended)

Create S3 bucket and DynamoDB table for state management:

```bash
# Create S3 bucket for state
aws s3 mb s3://my-terraform-state-bucket --region us-west-2
aws s3api put-bucket-versioning \
  --bucket my-terraform-state-bucket \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption \
  --bucket my-terraform-state-bucket \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-west-2
```

Update `terraform/examples/main.tf` backend configuration.

### 4. Customize Configuration

Copy and edit the example variables:

```bash
cd terraform/examples
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your preferences:
```hcl
aws_region   = "us-west-2"
project_name = "your-project"
environment  = "dev"

# For production, restrict public access
enable_public_access = false
public_access_cidrs  = ["YOUR_IP/32"]
```

### 5. Deploy Infrastructure

#### Manual Deployment

```bash
cd terraform/examples

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply

# Get cluster credentials
aws eks update-kubeconfig \
  --region us-west-2 \
  --name eks-assessment-dev
```

#### Automated Deployment via CI/CD

1. Create a pull request with your changes
2. Review the Terraform plan in PR comments
3. Merge to `main` branch to trigger deployment

### 6. Deploy Application

```bash
# Update image registry and tag in manifests
# This is automated in CI/CD pipeline

# Apply Kubernetes manifests
kubectl apply -f k8s/base/

# Verify deployment
kubectl get pods -n default
kubectl get svc -n default
```

### 7. Install Monitoring (Optional)

```bash
cd k8s/monitoring
chmod +x install-monitoring.sh
./install-monitoring.sh
```

Access Grafana:
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

Navigate to http://localhost:3000 (admin / check password in script output)

## IAM/RBAC Roles Required

### For Terraform Deployment

The IAM role/user running Terraform needs these permissions:
- `ec2:*` (VPC, subnets, security groups, NAT gateways)
- `eks:*` (EKS cluster and node groups)
- `iam:*` (Roles and policies for EKS)
- `kms:*` (Encryption keys)
- `logs:*` (CloudWatch log groups)
- `ecr:*` (Container registry)

Managed policies:
- `AmazonEKSClusterPolicy`
- `AmazonEKSVPCResourceController`
- `AmazonEC2FullAccess`
- `IAMFullAccess`

### For Application Deployment

The service account (`app-sa`) uses IRSA with permissions for:
- `s3:GetObject`, `s3:PutObject`, `s3:ListBucket` (example)
- `secretsmanager:GetSecretValue`

### For Kubernetes Deployments (CI/CD)

GitHub Actions role needs:
- `eks:DescribeCluster`
- `eks:ListClusters`
- Permissions to assume the EKS cluster admin role

## Security Considerations

### Implemented Security Measures

1. **Network Security**
   - Private worker nodes (no public IPs)
   - Network policies restricting pod-to-pod communication
   - Security groups with least-privilege rules
   - Private API endpoint option

2. **Encryption**
   - EKS secrets encrypted with KMS
   - EBS volumes encrypted
   - ECR images encrypted at rest
   - TLS for all communications

3. **Access Control**
   - IAM Roles for Service Accounts (IRSA)
   - No long-lived credentials in pods
   - IMDSv2 enforced (prevents SSRF attacks)
   - RBAC for Kubernetes resources

4. **Container Security**
   - Non-root container execution
   - Read-only root filesystem
   - Dropped Linux capabilities
   - Security scanning in CI/CD
   - Image signing support (Cosign)

5. **Compliance**
   - Automated security scanning (tfsec, Checkov, Trivy)
   - CloudWatch audit logs enabled
   - Resource tagging for governance

### Production Recommendations

1. **Restrict API endpoint access**
   ```hcl
   enable_public_access = false  # or restrict IPs
   ```

2. **Use private ECR with VPC endpoints**
3. **Enable GuardDuty and Security Hub**
4. **Implement AWS WAF on ALB**
5. **Use AWS Secrets Manager for sensitive data**
6. **Enable pod security standards**
7. **Implement OPA/Gatekeeper policies**
8. **Regular security patching and updates**

## Cost Estimation

### Monthly Cost Breakdown (Approximate)

Using default configuration (`t3.medium`, 2-10 nodes):

| Resource | Cost |
|----------|------|
| EKS Control Plane | $73/month |
| EC2 Instances (2x t3.medium) | ~$60/month |
| NAT Gateways (3x) | ~$97/month |
| EBS Volumes | ~$10/month |
| Data Transfer | Variable |
| **Estimated Total** | **~$240-300/month** |

### Cost Optimization Strategies

1. **Use Spot Instances** for non-production
   ```hcl
   node_capacity_type = "SPOT"
   ```

2. **Reduce NAT Gateways** to 1 (single AZ) for dev
3. **Use smaller instance types** (t3.small)
4. **Enable cluster autoscaler** to scale down during off-hours
5. **Use Fargate** for variable workloads (separate module needed)

Run Infracost locally:
```bash
infracost breakdown --path terraform/examples
```

## Monitoring and Observability

### Metrics Available

1. **Cluster Metrics**
   - Node CPU/Memory utilization
   - Pod count and status
   - Persistent volume usage

2. **Application Metrics**
   - Request rate and latency
   - Error rates
   - Custom business metrics

3. **Infrastructure Metrics**
   - EKS control plane metrics
   - NAT Gateway metrics
   - Load balancer metrics

### Accessing Dashboards

**Grafana**: Custom dashboards for application and cluster monitoring
**Prometheus**: Raw metrics and PromQL queries
**CloudWatch**: Control plane logs and container insights

## Blue-Green Deployment Strategy

The pipeline includes a blue-green deployment workflow (disabled by default). To enable:

1. Set the condition in `.github/workflows/build-deploy.yml`:
   ```yaml
   if: github.ref == 'refs/heads/main' && true  # Change false to true
   ```

2. Blue-green process:
   - Deploy new version as "green"
   - Run validation tests
   - Switch service selector to green
   - Monitor for issues
   - Remove old "blue" deployment

## Troubleshooting

### Common Issues

1. **Terraform State Lock**
   ```bash
   # Force unlock (use with caution)
   terraform force-unlock LOCK_ID
   ```

2. **Pods Not Starting**
   ```bash
   kubectl describe pod <pod-name> -n default
   kubectl logs <pod-name> -n default
   ```

3. **Node Group Not Scaling**
   ```bash
   # Check node group status
   aws eks describe-nodegroup \
     --cluster-name eks-assessment-dev \
     --nodegroup-name eks-assessment-dev-node-group
   ```

4. **ALB Not Created**
   ```bash
   # Ensure AWS Load Balancer Controller is installed
   kubectl get deployment -n kube-system aws-load-balancer-controller
   ```

5. **IRSA Not Working**
   ```bash
   # Verify OIDC provider is configured
   aws eks describe-cluster \
     --name eks-assessment-dev \
     --query "cluster.identity.oidc.issuer"
   ```

## Testing the Deployment

### Verify Infrastructure

```bash
# Check cluster status
kubectl cluster-info
kubectl get nodes

# Check all resources
kubectl get all -n default
```

### Test Application

```bash
# Get service endpoint
kubectl get svc demo-app -n default

# Port forward to test locally
kubectl port-forward svc/demo-app 8080:80 -n default

# Test endpoints
curl http://localhost:8080/
curl http://localhost:8080/health
curl http://localhost:8080/metrics
```

### Load Testing

```bash
# Install k6 or Apache Bench
kubectl run -it --rm load-test --image=grafana/k6 --restart=Never -- \
  run -u 10 -d 30s http://demo-app/
```

## Architecture Decisions and Trade-offs

### Decision: Private EKS Cluster with Public Endpoint Option

**Rationale**: Balances security with ease of access for development/demo
**Trade-off**: Slightly less secure than fully private, but more practical
**Production**: Disable public access and use VPN/bastion

### Decision: Multi-AZ NAT Gateways

**Rationale**: High availability and fault tolerance
**Trade-off**: Higher cost (~$97/month for 3)
**Alternative**: Single NAT Gateway for cost savings in non-production

### Decision: EKS Add-ons vs Self-managed

**Rationale**: Using AWS-managed add-ons (VPC CNI, CoreDNS, kube-proxy, EBS CSI)
**Benefits**: Automatic updates, AWS support, simpler management
**Trade-off**: Less customization flexibility

### Decision: Rolling Updates vs Blue-Green

**Rationale**: Rolling updates as default, blue-green as optional
**Benefits**: Rolling is simpler and requires fewer resources
**Trade-off**: Blue-green provides instant rollback

### Decision: GitHub Actions vs Other CI/CD

**Rationale**: Native GitHub integration, free for public repos
**Alternative**: Jenkins, GitLab CI, AWS CodePipeline
**Trade-off**: Vendor lock-in, but excellent integration

## Assumptions

1. **Cloud Provider**: AWS chosen for EKS assessment requirement
2. **Region**: us-west-2 selected (easily changed via variables)
3. **Kubernetes Version**: 1.28 (current stable, adjust as needed)
4. **Instance Types**: t3.medium for nodes (suitable for demo/dev)
5. **Scaling**: Min 2, max 10 nodes (adjust based on workload)
6. **State Management**: Local state (should use S3 backend for production)
7. **DNS**: No custom domain configured (use LoadBalancer DNS)
8. **SSL/TLS**: Not configured (should add ACM certificate in production)
9. **Multi-region**: Single region deployment (can extend to multi-region)
10. **Backup/DR**: Not implemented (should add Velero for backups)

## Future Enhancements

- [ ] ArgoCD for GitOps deployment model
- [ ] Istio/Linkerd service mesh
- [ ] Velero for cluster backups
- [ ] External Secrets Operator for secret management
- [ ] Karpenter for advanced autoscaling
- [ ] Multi-region active-active setup
- [ ] Chaos engineering with Chaos Mesh
- [ ] Advanced monitoring with Datadog/New Relic
- [ ] Compliance scanning with OPA/Gatekeeper
- [ ] Automated SSL certificate management

## License

MIT License - Feel free to use this for your assessment or learning purposes.

## Contact

For questions about this implementation, please refer to the code comments and AWS documentation.

---

**Note**: This is a technical assessment submission. The infrastructure incurs AWS costs. Remember to destroy resources when not in use:

```bash
cd terraform/examples
terraform destroy
```
