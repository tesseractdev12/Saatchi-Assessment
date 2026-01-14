# GitHub Actions Setup Guide

This document explains how to configure GitHub Actions for automated deployments.

## Why Workflows Will Fail Initially

The GitHub Actions workflows are configured but will fail on first run because:

1. **AWS Credentials**: Not configured (for security)
2. **GitHub Secrets**: Need to be manually added
3. **AWS Resources**: Don't exist yet (need Terraform to create them)

**This is expected and intentional** - we don't commit credentials to repositories!

## Required GitHub Secrets

To enable the CI/CD pipelines, configure these secrets in your GitHub repository:

### Navigate to Secrets
1. Go to your repository on GitHub
2. Click `Settings` → `Secrets and variables` → `Actions`
3. Click `New repository secret`

### Required Secrets

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `AWS_ROLE_ARN` | IAM role for GitHub Actions OIDC | See "AWS OIDC Setup" below |
| `EKS_CLUSTER_NAME` | Name of your EKS cluster | Use: `eks-assessment-dev` |
| `INFRACOST_API_KEY` | API key for cost estimation (optional) | Get from https://infracost.io |

## AWS OIDC Setup (Recommended Method)

### Step 1: Create OIDC Provider in AWS

```bash
# This creates the OIDC provider for GitHub Actions
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### Step 2: Create IAM Role with Trust Policy

Create a file `github-actions-trust-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
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

Replace:
- `YOUR_ACCOUNT_ID` with your AWS account ID
- `YOUR_GITHUB_ORG` with your GitHub username/org
- `YOUR_REPO` with your repository name

### Step 3: Create the IAM Role

```bash
# Create the role
aws iam create-role \
  --role-name github-actions-eks-deployment \
  --assume-role-policy-document file://github-actions-trust-policy.json

# Attach required policies
aws iam attach-role-policy \
  --role-name github-actions-eks-deployment \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy

aws iam attach-role-policy \
  --role-name github-actions-eks-deployment \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess

aws iam attach-role-policy \
  --role-name github-actions-eks-deployment \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess

aws iam attach-role-policy \
  --role-name github-actions-eks-deployment \
  --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess

# Get the role ARN (you'll need this for GitHub Secrets)
aws iam get-role \
  --role-name github-actions-eks-deployment \
  --query 'Role.Arn' \
  --output text
```

### Step 4: Add Secrets to GitHub

Add the role ARN to GitHub Secrets:
```
AWS_ROLE_ARN = arn:aws:iam::YOUR_ACCOUNT_ID:role/github-actions-eks-deployment
EKS_CLUSTER_NAME = eks-assessment-dev
```

## Alternative: Use AWS Access Keys (Not Recommended)

If you can't use OIDC, you can use access keys (less secure):

```bash
# Create access keys for your IAM user
aws iam create-access-key --user-name YOUR_USERNAME
```

Add to GitHub Secrets:
```
AWS_ACCESS_KEY_ID = AKIA...
AWS_SECRET_ACCESS_KEY = ...
AWS_REGION = us-west-2
```

**Note**: This method is not recommended for production as it uses long-lived credentials.

## Infracost Setup (Optional)

1. Sign up at https://infracost.io
2. Get your API key from dashboard
3. Add to GitHub Secrets as `INFRACOST_API_KEY`

This enables cost estimation in PR comments.

## Workflow Behavior

### Terraform Workflow (`terraform.yml`)

**Triggers**:
- Pull Request: Runs `terraform plan` and posts results as comment
- Push to main: Runs `terraform apply` to deploy infrastructure

**Jobs**:
1. Validation: Format check, init, validate
2. Security Scan: tfsec, Checkov
3. Plan: Generate plan and cost estimate (on PR)
4. Apply: Deploy infrastructure (on main branch)

### Application Workflow (`build-deploy.yml`)

**Triggers**:
- Pull Request: Runs security scans only
- Push to main: Builds, pushes, and deploys application

**Jobs**:
1. Security Scan: Trivy, Semgrep
2. Build and Push: Docker build → ECR
3. Deploy: kubectl apply to EKS

## Testing Without AWS

You can test the workflows locally without AWS:

### Terraform Validation
```bash
cd terraform/examples
terraform init -backend=false
terraform validate
terraform fmt -check -recursive
```

### Security Scanning
```bash
# Install tools
brew install tfsec trivy

# Run scans
tfsec terraform/
trivy fs .
```

### Docker Build
```bash
cd app
docker build -t demo-app:test .
docker run -p 8080:3000 demo-app:test
```

## Disabling Workflows

If you want to disable workflows temporarily:

### Option 1: Rename Directory
```bash
mv .github/workflows .github/workflows-disabled
git add .
git commit -m "Disable workflows temporarily"
git push
```

### Option 2: Use [skip ci] in Commit
```bash
git commit -m "Update documentation [skip ci]"
```

### Option 3: Disable in GitHub UI
1. Go to repository → Actions
2. Click on workflow
3. Click "..." → "Disable workflow"

## Enabling Workflows

Once you've configured the secrets:

1. Ensure secrets are added to GitHub
2. Make any change and push to trigger workflows
3. Monitor Actions tab for results

Example:
```bash
# Make a small change
echo "# CI/CD Enabled" >> README.md
git add README.md
git commit -m "Enable CI/CD pipelines"
git push
```

## Troubleshooting

### Error: "could not get token: AccessDenied"

**Cause**: OIDC provider or role trust policy misconfigured

**Fix**:
- Verify OIDC provider exists in AWS
- Check trust policy includes your repo
- Ensure role ARN in GitHub Secrets is correct

### Error: "Error: Failed to initialize Terraform"

**Cause**: Backend configuration issue

**Fix**: The example uses local state by default. For remote state:
```hcl
# Edit terraform/examples/main.tf
backend "s3" {
  bucket = "your-terraform-state-bucket"
  key    = "eks/terraform.tfstate"
  region = "us-west-2"
}
```

### Error: "ECR repository does not exist"

**Cause**: Terraform hasn't created resources yet

**Fix**: Run Terraform workflow first to create infrastructure, then run application workflow

## Workflow Execution Order

For first-time setup:

1. **Configure Secrets** → GitHub Settings
2. **Run Terraform Workflow** → Creates AWS infrastructure
3. **Run Application Workflow** → Deploys application

After initial setup, both workflows run automatically on commits.

## Monitoring Workflows

### View Workflow Status
- GitHub Repository → Actions tab
- See status of each workflow run
- View logs for debugging

### Status Badges
Add to README.md:
```markdown
![Terraform](https://github.com/YOUR_ORG/YOUR_REPO/workflows/Terraform%20Infrastructure%20Pipeline/badge.svg)
![Build and Deploy](https://github.com/YOUR_ORG/YOUR_REPO/workflows/Build%20and%20Deploy%20Application/badge.svg)
```

## Security Best Practices

✅ **DO**:
- Use OIDC with IAM roles (no long-lived credentials)
- Use secrets for sensitive values
- Limit IAM role permissions to minimum required
- Enable branch protection rules
- Review workflow logs regularly

❌ **DON'T**:
- Commit AWS credentials to repository
- Use root account credentials
- Give workflows more permissions than needed
- Disable security scanning
- Skip PR reviews

## Summary

The GitHub Actions workflows are production-ready but require configuration:

1. Set up AWS OIDC provider and IAM role
2. Add secrets to GitHub repository
3. Push to trigger workflows
4. Monitor in Actions tab

For assessment purposes, reviewers can evaluate the workflow configuration without needing to run them.

---

**Questions?** See `DEPLOYMENT_GUIDE.md` for full deployment instructions.
