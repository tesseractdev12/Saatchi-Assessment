# Quick Reference Card

Essential commands and information for the EKS deployment.

## 🚀 Quick Deploy

```bash
# 1. Configure AWS
aws configure

# 2. Deploy infrastructure
cd terraform/examples
terraform init && terraform apply -auto-approve

# 3. Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name eks-assessment-dev

# 4. Deploy application
cd ../../k8s/base
kubectl apply -f .

# 5. Verify
kubectl get all -n default
```

## 📋 Essential Commands

### Terraform
```bash
# Initialize
terraform init

# Plan
terraform plan

# Apply
terraform apply

# Outputs
terraform output

# Destroy
terraform destroy
```

### kubectl
```bash
# Get nodes
kubectl get nodes

# Get pods
kubectl get pods -n default

# Get all resources
kubectl get all -n default

# Logs
kubectl logs -f <pod-name> -n default

# Describe
kubectl describe pod <pod-name> -n default

# Port forward
kubectl port-forward svc/demo-app 8080:80 -n default

# Exec into pod
kubectl exec -it <pod-name> -n default -- /bin/sh
```

### AWS CLI
```bash
# Get cluster info
aws eks describe-cluster --name eks-assessment-dev --region us-west-2

# Get kubeconfig
aws eks update-kubeconfig --name eks-assessment-dev --region us-west-2

# ECR login
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin <account>.dkr.ecr.us-west-2.amazonaws.com

# List node groups
aws eks list-nodegroups --cluster-name eks-assessment-dev --region us-west-2
```

## 🔧 Troubleshooting

### Pods not starting?
```bash
kubectl describe pod <pod-name> -n default
kubectl logs <pod-name> -n default
kubectl get events -n default --sort-by='.lastTimestamp'
```

### Nodes not ready?
```bash
kubectl get nodes
kubectl describe node <node-name>
aws eks describe-nodegroup --cluster-name eks-assessment-dev --nodegroup-name <nodegroup-name>
```

### Can't access application?
```bash
kubectl get svc -n default
kubectl get ingress -n default
kubectl describe svc demo-app -n default
```

### Terraform errors?
```bash
terraform fmt -recursive
terraform validate
terraform plan -detailed-exitcode
```

## 📊 Monitoring

### Access Grafana
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Open http://localhost:3000
# Username: admin
# Password: see installation output
```

### Access Prometheus
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Open http://localhost:9090
```

### Check metrics
```bash
kubectl port-forward svc/demo-app 8080:80
curl http://localhost:8080/metrics
```

## 💰 Cost Management

### View estimated costs
```bash
cd terraform/examples
infracost breakdown --path .
```

### Monthly estimates
- **Dev**: ~$240-300/month
- **Production**: ~$400-600/month
- **Optimized Dev**: ~$100-150/month (Spot + 1 NAT)

## 🔒 Security

### Check IAM roles
```bash
# List roles
aws iam list-roles | grep eks-assessment

# Get role details
aws iam get-role --role-name eks-assessment-dev-node-role

# List policies attached
aws iam list-attached-role-policies --role-name eks-assessment-dev-node-role
```

### Verify IRSA
```bash
# Check OIDC provider
aws eks describe-cluster --name eks-assessment-dev --query "cluster.identity.oidc.issuer"

# Check service account
kubectl get sa app-sa -n default -o yaml

# Check pod env vars
kubectl exec <pod-name> -n default -- env | grep AWS
```

### Security scanning
```bash
# Scan Terraform
tfsec terraform/

# Scan Docker image
trivy image <image-name>

# Scan filesystem
trivy fs .
```

## 📁 File Locations

| Item | Location |
|------|----------|
| EKS Module | `terraform/modules/eks-cluster/` |
| Example Config | `terraform/examples/` |
| K8s Manifests | `k8s/base/` |
| Monitoring | `k8s/monitoring/` |
| CI/CD Workflows | `.github/workflows/` |
| Application | `app/` |
| Documentation | `*.md` files in root |

## 🌐 URLs After Deployment

```bash
# Application
kubectl get svc demo-app -n default
# or
kubectl get ingress demo-app -n default

# Grafana
kubectl get ingress -n monitoring prometheus-grafana
# or port-forward (see above)
```

## 🎯 GitHub Actions Secrets

Required secrets:
```
AWS_ROLE_ARN          # arn:aws:iam::ACCOUNT:role/github-actions-role
EKS_CLUSTER_NAME      # eks-assessment-dev
INFRACOST_API_KEY     # (optional) from infracost.io
```

## 📝 Important Variables

### terraform.tfvars
```hcl
aws_region          = "us-west-2"
project_name        = "eks-assessment"
environment         = "dev"
node_min_size       = 2
node_max_size       = 10
node_instance_types = ["t3.medium"]
```

## 🔄 Common Workflows

### Deploy infrastructure
```bash
cd terraform/examples
terraform apply
```

### Update application
```bash
# Build
docker build -t demo-app:v2 ./app

# Tag
docker tag demo-app:v2 <ecr-url>/demo-app:v2

# Push
docker push <ecr-url>/demo-app:v2

# Update deployment
kubectl set image deployment/demo-app demo-app=<ecr-url>/demo-app:v2 -n default

# Rollout status
kubectl rollout status deployment/demo-app -n default
```

### Rollback
```bash
kubectl rollout undo deployment/demo-app -n default
kubectl rollout status deployment/demo-app -n default
```

### Scale manually
```bash
# Scale pods
kubectl scale deployment demo-app --replicas=5 -n default

# Scale nodes (via Terraform)
# Edit terraform.tfvars: node_desired_size = 5
terraform apply
```

## 🧪 Testing

### Health check
```bash
curl http://localhost:8080/health
```

### Load test
```bash
kubectl run -it --rm load-test --image=busybox --restart=Never -- \
  wget -q -O- http://demo-app/
```

### Verify autoscaling
```bash
# Watch HPA
kubectl get hpa -w

# Generate load
kubectl run -it --rm load-gen --image=busybox --restart=Never -- \
  sh -c "while true; do wget -q -O- http://demo-app/; done"

# In another terminal, watch pods scale
kubectl get pods -w
```

## 🗑️ Cleanup

### Delete application
```bash
kubectl delete -f k8s/base/
```

### Delete monitoring
```bash
helm uninstall prometheus -n monitoring
kubectl delete namespace monitoring
```

### Destroy infrastructure
```bash
cd terraform/examples
terraform destroy
```

## 📞 Support Resources

- **AWS EKS Docs**: https://docs.aws.amazon.com/eks/
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/
- **Kubernetes Docs**: https://kubernetes.io/docs/
- **GitHub Actions**: https://docs.github.com/en/actions

## 🎓 Learning Resources

### Included Documentation
1. `README.md` - Architecture and overview
2. `DEPLOYMENT_GUIDE.md` - Step-by-step deployment
3. `IAM_RBAC_DOCUMENTATION.md` - IAM and RBAC details
4. `ASSESSMENT_CHECKLIST.md` - Requirements tracking
5. `SUBMISSION_SUMMARY.md` - Executive summary

### Code Structure
- **Terraform modules**: Reusable infrastructure components
- **K8s manifests**: Production-ready configurations
- **CI/CD workflows**: GitHub Actions automation
- **Monitoring**: Prometheus + Grafana setup

## 💡 Pro Tips

1. **Use workspaces** for multiple environments:
   ```bash
   terraform workspace new staging
   terraform workspace select staging
   ```

2. **Save costs** in dev:
   - Set `node_capacity_type = "SPOT"`
   - Use `availability_zones_count = 1`
   - Stop cluster outside work hours

3. **Debug faster**:
   ```bash
   kubectl get events --sort-by='.lastTimestamp' -A
   ```

4. **Monitor costs**:
   ```bash
   infracost breakdown --path terraform/examples --show-skipped
   ```

5. **Backup configs**:
   ```bash
   kubectl get all -o yaml -n default > backup.yaml
   ```

## ⚡ Quick Verification

After deployment, verify everything:

```bash
# Infrastructure
terraform output
aws eks describe-cluster --name eks-assessment-dev

# Kubernetes
kubectl cluster-info
kubectl get nodes
kubectl get pods -A

# Application
kubectl get all -n default
kubectl logs -l app=demo-app -n default --tail=10

# Networking
kubectl get svc,ingress -n default

# Autoscaling
kubectl get hpa -n default

# Security
kubectl get networkpolicy -n default
```

All should show healthy status!

---

**Keep this handy for quick reference during deployment and operations.**
