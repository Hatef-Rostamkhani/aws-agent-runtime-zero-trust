# GitHub Actions Workflows

This directory contains GitHub Actions workflows for automated CI/CD.

## Workflows

### deploy-infra.yml

Automated infrastructure deployment workflow that:
- Automatically creates S3 bucket and DynamoDB table for Terraform state
- Deploys infrastructure using Terraform
- Supports manual and automatic triggers

## Setup Instructions

### Required GitHub Secrets

Add these secrets in **Repository Settings → Secrets → Actions**:

#### Minimum Required (for first deployment):
1. **AWS_ACCESS_KEY_ID** - Your AWS access key ID
2. **AWS_SECRET_ACCESS_KEY** - Your AWS secret access key

#### Optional (with defaults):
- **AWS_REGION** - AWS region (default: `us-east-1`)
- **PROJECT_NAME** - Project name (default: `agent-runtime`)

#### Auto-generated (after first deployment):
- **AWS_INFRA_DEPLOY_ROLE** - IAM role ARN (will be shown in workflow output after first run)

### First Time Setup

1. **Add GitHub Secrets**:
   - Go to your repository → Settings → Secrets → Actions
   - Add `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`

2. **Push code**:
   ```bash
   git add .
   git commit -m "Add infrastructure code"
   git push origin main
   ```

3. **Workflow will automatically**:
   - Create S3 bucket for Terraform state
   - Create DynamoDB table for state locking
   - Deploy infrastructure
   - Output IAM role ARN for future deployments

4. **Add IAM Role Secret** (after first deployment):
   - Check workflow output for IAM role ARN
   - Add it as `AWS_INFRA_DEPLOY_ROLE` secret
   - Future deployments will use OIDC authentication

### Manual Deployment

You can also trigger deployment manually:

1. Go to **Actions** tab
2. Select **Deploy Infrastructure** workflow
3. Click **Run workflow**
4. Select environment (staging/production)
5. Click **Run workflow**

### Automatic Deployment

The workflow automatically runs when:
- Code is pushed to `main` branch
- Changes are made in `infra/` directory
- Tags matching `infra-v*` are pushed

## Workflow Steps

1. **bootstrap-backend**: Creates S3 bucket and DynamoDB table if they don't exist
2. **deploy-infrastructure**: 
   - Initializes Terraform
   - Validates configuration
   - Plans changes
   - Applies infrastructure
   - Outputs IAM role ARN (first time)

## Troubleshooting

### Workflow Fails on Bootstrap

- Check AWS credentials are correct
- Verify AWS account has permissions to create S3 buckets and DynamoDB tables
- Check AWS region is correct

### Workflow Fails on Terraform Apply

- Check Terraform plan output in workflow logs
- Verify all required variables are set
- Check AWS account limits (VPCs, NAT gateways, etc.)

### IAM Role Not Found

- First deployment uses AWS access keys
- After first deployment, add IAM role ARN to secrets
- Role is created automatically by Terraform

## Security Best Practices

1. **Use OIDC** (after first deployment):
   - Add IAM role ARN to secrets
   - Remove AWS access keys (optional, but recommended)

2. **Environment Protection**:
   - Enable branch protection rules
   - Require approvals for production environment
   - Use separate AWS accounts for staging/production

3. **Secret Rotation**:
   - Rotate AWS access keys regularly
   - Use least-privilege IAM policies
   - Monitor IAM role usage

## Cost Considerations

The bootstrap process creates:
- **S3 bucket**: ~$0.023/GB/month (minimal for state files)
- **DynamoDB table**: Pay-per-request (very low cost for locking)

These resources are essential for Terraform state management and have minimal cost impact.

