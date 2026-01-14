# Quick Deployment Guide

This is a condensed guide for deploying the EKS infrastructure. For detailed information, see the main README.md.

## Prerequisites

- AWS Account
- GitHub repository
- Required CLI tools installed (optional for CI/CD deployment)

## Option 1: Automated Deployment via GitHub Actions (Recommended)

### Step 1: Fork/Clone Repository

```bash
git clone <your-repo-url>
cd <repo-name>
```

### Step 2: Configure GitHub Secrets

Navigate to: `Settings` → `Secrets and variables` → `Actions` → `New repository secret`

Add these secrets:
```
AWS_ROLE_ARN          # arn:aws:iam::ACCOUNT_ID:role/github-actions-role
EKS_CLUSTER_NAME      # eks-assessment-dev
INFRACOST_API_KEY     # (optional) Get from infracost.io
```

### Step 3: Set Up AWS OIDC Provider

Create the OIDC provider for GitHub Actions:

```bash
# Download and run the setup script
curl -o setup-github-oidc.sh https://raw.githubusercontent.com/aws-actions/configure-aws-credentials/main/scripts/create-oidc-provider.sh
chmod +x setup-github-oidc.sh
./setup-github-oidc.sh
```

Or manually via AWS Console:
1. Go to IAM → Identity providers → Add provider
2. Provider type: OpenID Connect
3. Provider URL: `https://token.actions.githubusercontent.com`
4. Audience: `sts.amazonaws.com`

Create IAM role with trust relationship:
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
          "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:*"
        }
      }
    }
  ]
}
```

Attach policies:
- AmazonEKSClusterPolicy
- AmazonEC2FullAccess
- IAMFullAccess
- AmazonVPCFullAccess

### Step 4: Trigger Deployment

```bash
# Make any change and push
git add .
git commit -m "Initial deployment"
git push origin main
```

GitHub Actions will:
1. ✅ Validate Terraform code
2. ✅ Run security scans
3. ✅ Apply infrastructure
4. ✅ Deploy application

Monitor progress: `Actions` tab in GitHub

### Step 5: Access Your Cluster

After deployment completes (15-20 minutes):

```bash
# Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name eks-assessment-dev

# Verify
kubectl get nodes
kubectl get pods -n default
```

## Option 2: Manual Deployment

### Step 1: Configure AWS Credentials

```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and region
```

### Step 2: Set Up Terraform Backend (Recommended)

```bash
# Create S3 bucket
aws s3 mb s3://my-terraform-state-bucket-$(date +%s) --region us-west-2

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket YOUR-BUCKET-NAME \
  --versioning-configuration Status=Enabled

# Create DynamoDB table
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-west-2
```

Edit `terraform/examples/main.tf` and uncomment the backend block.

### Step 3: Deploy Infrastructure

```bash
cd terraform/examples

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your settings
nano terraform.tfvars

# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Apply the configuration
terraform apply
# Type "yes" when prompted
```

This will take approximately 15-20 minutes.

### Step 4: Configure kubectl

```bash
# Get cluster credentials
aws eks update-kubeconfig \
  --region us-west-2 \
  --name $(terraform output -raw cluster_name)

# Verify connection
kubectl get nodes
```

### Step 5: Build and Push Application

```bash
# Get ECR repository URL
ECR_REPO=$(terraform output -raw ecr_repository_url)

# Login to ECR
aws ecr get-login-password --region us-west-2 | \
  docker login --username AWS --password-stdin $ECR_REPO

# Build application
cd ../../app
docker build -t demo-app:latest .

# Tag and push
docker tag demo-app:latest $ECR_REPO:latest
docker push $ECR_REPO:latest
```

### Step 6: Deploy Application

```bash
cd ../k8s/base

# Update deployment manifest with ECR URL and image tag
sed -i "s|ECR_REGISTRY|$ECR_REPO|g" deployment.yaml
sed -i "s|IMAGE_TAG|latest|g" deployment.yaml

# Apply Kubernetes manifests
kubectl apply -f namespace.yaml
kubectl apply -f serviceaccount.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f hpa.yaml
kubectl apply -f network-policy.yaml

# Verify deployment
kubectl get pods -n default
kubectl wait --for=condition=available --timeout=300s deployment/demo-app -n default
```

### Step 7: Install Monitoring (Optional)

```bash
cd ../monitoring
chmod +x install-monitoring.sh
./install-monitoring.sh
```

## Accessing the Application

### Get Application URL

```bash
# If using LoadBalancer service
kubectl get svc demo-app -n default

# If using Ingress
kubectl get ingress demo-app -n default
```

### Port Forward (for testing)

```bash
kubectl port-forward svc/demo-app 8080:80 -n default
```

Test the application:
```bash
curl http://localhost:8080/
curl http://localhost:8080/health
curl http://localhost:8080/metrics
```

## Verify Everything Works

### Check Cluster Health

```bash
# Nodes
kubectl get nodes

# Pods
kubectl get pods -n default
kubectl get pods -n kube-system

# Services
kubectl get svc -n default
```

### Check Application Health

```bash
# Pod logs
kubectl logs -l app=demo-app -n default

# Deployment status
kubectl rollout status deployment/demo-app -n default

# HPA status
kubectl get hpa -n default
```

### Check Monitoring (if installed)

```bash
# Port forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Access at http://localhost:3000
# Username: admin
# Password: (from installation output)
```

## Cost Management

### View Current Costs

```bash
# Using Infracost
cd terraform/examples
infracost breakdown --path .
```

### Estimated Monthly Cost

- **Development**: ~$240-300/month
  - EKS Control Plane: $73
  - 2x t3.medium nodes: ~$60
  - 3x NAT Gateways: ~$97
  - Other resources: ~$10-70

### Cost Optimization

For development/testing, modify `terraform.tfvars`:

```hcl
# Use Spot instances
node_capacity_type = "SPOT"

# Reduce NAT Gateways to 1 (single AZ)
availability_zones_count = 1

# Use smaller instances
node_instance_types = ["t3.small"]

# Reduce max nodes
node_max_size = 5
```

## Cleanup

### Destroy Everything

```bash
# Delete Kubernetes resources first
kubectl delete -f k8s/base/

# If monitoring is installed
helm uninstall prometheus -n monitoring

# Destroy Terraform infrastructure
cd terraform/examples
terraform destroy
# Type "yes" when prompted
```

**Important**: This will delete all resources and cannot be undone.

## Troubleshooting

### Issue: Terraform Apply Fails

**Solution**: Check IAM permissions
```bash
aws sts get-caller-identity
```

### Issue: Pods Not Starting

**Solution**: Check pod events
```bash
kubectl describe pod <pod-name> -n default
kubectl logs <pod-name> -n default
```

### Issue: Cannot Access Application

**Solution**: Check service and ingress
```bash
kubectl get svc -n default
kubectl get ingress -n default
kubectl describe svc demo-app -n default
```

### Issue: Node Group Not Scaling

**Solution**: Check node group configuration
```bash
aws eks describe-nodegroup \
  --cluster-name eks-assessment-dev \
  --nodegroup-name eks-assessment-dev-node-group
```

### Issue: GitHub Actions Failing

**Solution**: Check GitHub Action logs and verify secrets are set correctly

## Next Steps

1. ✅ Configure custom domain name
2. ✅ Add SSL/TLS certificate
3. ✅ Set up alerting (Slack, PagerDuty)
4. ✅ Implement backup strategy (Velero)
5. ✅ Add more monitoring dashboards
6. ✅ Implement GitOps with ArgoCD
7. ✅ Enable cluster autoscaler
8. ✅ Add more security policies

## Support

- AWS Documentation: https://docs.aws.amazon.com/eks/
- Terraform Registry: https://registry.terraform.io/providers/hashicorp/aws/
- Kubernetes Documentation: https://kubernetes.io/docs/

## Estimated Deployment Times

- **Terraform Apply**: 15-20 minutes
- **Application Deployment**: 2-5 minutes
- **Monitoring Stack**: 5-10 minutes
- **Total**: ~25-35 minutes

---

**Remember**: Always destroy resources when not in use to avoid unnecessary AWS charges!
