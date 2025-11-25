# Setup Guide

## Prerequisites

### AWS Account Setup
1. **Create AWS Account** or use existing account
2. **Configure AWS CLI**:
   ```bash
   aws configure
   # Enter your access key, secret key, default region (us-east-1), and output format (json)
   ```

3. **Verify Account Limits**:
   - ECS: 10 clusters, 100 services
   - Lambda: 1000 concurrent executions
   - DynamoDB: 40 read/write capacity units

### Local Development Setup
1. **Install Required Tools**:
   ```bash
   # Terraform
   curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
   sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
   sudo apt-get update && sudo apt-get install terraform

   # AWS CLI v2
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install

   # Docker
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh

   # Go (for local development)
   wget https://golang.org/dl/go1.21.0.linux-amd64.tar.gz
   sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
   export PATH=$PATH:/usr/local/go/bin
   ```

2. **Clone Repository**:
   ```bash
   git clone https://github.com/your-org/aws-agent-runtime-zero-trust.git
   cd aws-agent-runtime-zero-trust
   ```

3. **Initialize Project**:
   ```bash
   ./scripts/setup.sh
   ```

## Infrastructure Deployment

### Step 1: Configure Environment
```bash
# Copy and edit environment configuration
cp .env.local.example .env.local
nano .env.local

# Required variables:
# AWS_REGION=us-east-1
# PROJECT_NAME=agent-runtime
# ENVIRONMENT=dev
```

### Step 2: Deploy Infrastructure
```bash
cd infra

# Initialize Terraform
terraform init

# Review planned changes
terraform plan -out=tfplan

# Apply changes
terraform apply tfplan
```

### Step 3: Verify Infrastructure
```bash
# Check VPC creation
aws ec2 describe-vpcs --filters Name=tag:Name,Values=${PROJECT_NAME}-vpc

# Verify ECS cluster
aws ecs describe-clusters --clusters ${PROJECT_NAME}-cluster

# Check ECR repositories
aws ecr describe-repositories --repository-names ${PROJECT_NAME}/axon ${PROJECT_NAME}/orbit
```

## Service Deployment

### Step 1: Build Services
```bash
# Build Axon service
cd services/axon
docker build -t axon:latest .

# Build Orbit service
cd ../orbit
docker build -t orbit:latest .
```

### Step 2: Push Images to ECR
```bash
# Authenticate with ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

# Tag and push Axon
docker tag axon:latest ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/${PROJECT_NAME}/axon:latest
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/${PROJECT_NAME}/axon:latest

# Tag and push Orbit
docker tag orbit:latest ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/${PROJECT_NAME}/orbit:latest
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/${PROJECT_NAME}/orbit:latest
```

### Step 3: Deploy Services
```bash
cd infra

# Update task definitions with new image URIs
terraform apply -target=module.ecs

# Deploy services
aws ecs update-service --cluster ${PROJECT_NAME}-cluster --service ${PROJECT_NAME}-axon --force-new-deployment
aws ecs update-service --cluster ${PROJECT_NAME}-cluster --service ${PROJECT_NAME}-orbit --force-new-deployment
```

### Step 4: Configure Governance
```bash
cd governance/terraform

# Deploy governance infrastructure
terraform init
terraform apply

# Load default policies
cd ../scripts
python load-policies.py
```

## CI/CD Setup

### GitHub Actions Configuration
1. **Create GitHub Repository** (if not already done)
2. **Add Secrets** to repository settings:
   ```
   AWS_REGION: us-east-1
   AWS_ECR_REGISTRY: <account-id>.dkr.ecr.us-east-1.amazonaws.com
   AWS_GITHUB_ACTIONS_ROLE: arn:aws:iam::<account-id>:role/github-actions-role
   AWS_DEPLOY_ROLE: arn:aws:iam::<account-id>:role/deploy-role
   PROJECT_NAME: agent-runtime
   ```
3. **Enable GitHub Actions** in repository settings
4. **Configure Branch Protection**:
   - Require pull request reviews
   - Require status checks (build, security, test)
   - Require branches to be up to date

### OIDC Provider Setup
```bash
# This is handled by Terraform in infra/modules/cicd/github-oidc.tf
cd infra
terraform apply -target=module.cicd
```

## Verification

### Health Checks
```bash
# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers --names ${PROJECT_NAME}-alb --query 'LoadBalancers[0].DNSName' --output text)

# Test health endpoints
curl -f https://${ALB_DNS}/health

# Test governance
curl -X POST https://${ALB_DNS}/dispatch \
  -H "Content-Type: application/json" \
  -d "{}"
```

### Monitoring Setup
```bash
# Check CloudWatch dashboards
aws cloudwatch list-dashboards --query "DashboardEntries[?contains(DashboardName, \`${PROJECT_NAME}\`)]"

# Verify alarms
aws cloudwatch describe-alarms --alarm-name-prefix "${PROJECT_NAME}"

# Check log groups
aws logs describe-log-groups --log-group-name-prefix "/ecs/${PROJECT_NAME}"
```

## Troubleshooting

### Common Issues

#### Terraform Apply Fails
```bash
# Check AWS limits
aws service-quotas get-service-quota --service-code ecs --quota-code L-21DAFBDC

# Verify permissions
aws sts get-caller-identity

# Check Terraform state
cd infra
terraform state list
```

#### Service Deployment Fails
```bash
# Check ECS service events
aws ecs describe-services --cluster ${PROJECT_NAME}-cluster --services ${PROJECT_NAME}-axon \
  --query 'services[0].events[0:5]'

# Check task status
aws ecs list-tasks --cluster ${PROJECT_NAME}-cluster --service-name ${PROJECT_NAME}-axon
aws ecs describe-tasks --cluster ${PROJECT_NAME}-cluster --tasks <task-arn>
```

#### Image Push Fails
```bash
# Check ECR permissions
aws ecr get-authorization-token

# Verify repository exists
aws ecr describe-repositories --repository-names ${PROJECT_NAME}/axon
```

### Logs and Debugging

#### Application Logs
```bash
# Axon logs
aws logs tail /ecs/${PROJECT_NAME}-axon --follow

# Orbit logs
aws logs tail /ecs/${PROJECT_NAME}-orbit --follow

# Governance logs
aws logs tail /aws/lambda/${PROJECT_NAME}-governance --follow
```

#### Infrastructure Logs
```bash
# VPC Flow Logs
aws ec2 describe-flow-logs --query 'FlowLogs[*].FlowLogId'

# CloudTrail events
aws cloudtrail lookup-events --max-items 10
```

## Next Steps

1. **Configure Monitoring**: Set up alerts and notifications
2. **Security Review**: Run security audit and penetration testing
3. **Performance Testing**: Load test the system
4. **Documentation**: Complete operational runbooks
5. **Backup Strategy**: Configure automated backups

## Support

For issues or questions:
- Check the [troubleshooting guide](./troubleshooting.md)
- Review [architecture documentation](./architecture.md)
- Create an issue in the GitHub repository
- Contact the DevOps team

## Cost Estimation

### Monthly Costs (approximate)
- **ECS Fargate**: $50-100 (2 tasks, 24/7)
- **Lambda**: $5-10 (governance calls)
- **DynamoDB**: $5-15 (on-demand)
- **CloudWatch**: $10-20 (logs and metrics)
- **ALB**: $15-25 (data transfer)
- **ECR**: $5 (storage)
- **Secrets Manager**: $5 (secrets)

**Total Estimated Monthly Cost**: $90-190

### Cost Optimization
- Use Fargate Spot for non-production
- Configure auto-scaling to scale to zero
- Set up log retention policies
- Use reserved instances for steady workloads
