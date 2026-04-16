# Infrastructure Deployment Quick Reference

Quick reference guide for common infrastructure deployment tasks.

## Quick Start

### First Time Setup (Production Order)

```bash
# 1. Deploy to DEV
Jenkins Job: Infrastructure-Deployment-Main
Parameters:
  ENVIRONMENT=dev
  ACTION=CREATE
  SKIP_CORE=false
  SKIP_BASE=false

# 2. Verify DEV
bash infrastructure/pipelines/utilities/verify_stacks.sh \
    ascend-main-stack-dev us-east-1

# 3. Deploy to TEST
Jenkins Job: Infrastructure-Deployment-Main
Parameters:
  ENVIRONMENT=test
  ACTION=CREATE
  SKIP_CORE=false
  SKIP_BASE=false

# 4. Deploy to PROD
Jenkins Job: Infrastructure-Deployment-Main
Parameters:
  ENVIRONMENT=prod
  ACTION=CREATE
  SKIP_CORE=false
  SKIP_BASE=false
```

## Common Operations

### Deploy New App Policy (Most Common)

```bash
Jenkins Job: Infrastructure-Deployment-App
Parameters:
  ENVIRONMENT=dev|test|prod
  ACTION=UPDATE
  CHANGE_DESCRIPTION="Brief description of changes"
```

### Update Infrastructure (Base Stack)

```bash
# TEST first
Jenkins Job: Infrastructure-Deployment-Base
Parameters:
  ENVIRONMENT=test
  ACTION=UPDATE

# Then PROD
Jenkins Job: Infrastructure-Deployment-Base
Parameters:
  ENVIRONMENT=prod
  ACTION=UPDATE
```

### Verify Stack Health

```bash
# Development
bash infrastructure/pipelines/utilities/verify_stacks.sh \
    ascend-main-stack-dev us-east-1

# Test
bash infrastructure/pipelines/utilities/verify_stacks.sh \
    ascend-main-stack-test us-east-1

# Production
bash infrastructure/pipelines/utilities/verify_stacks.sh \
    ascend-main-stack-prod us-east-1
```

### Delete Stack (Cleanup)

```bash
# App Stack Only (Safe to delete and recreate)
Jenkins Job: Infrastructure-Deployment-App
Parameters:
  ENVIRONMENT=dev
  ACTION=DELETE

# Base Stack (Requires S3/KMS deletion)
Jenkins Job: Infrastructure-Deployment-Base
Parameters:
  ENVIRONMENT=dev
  ACTION=DELETE

# Entire Infrastructure
Jenkins Job: Infrastructure-Deployment-Main
Parameters:
  ENVIRONMENT=dev
  ACTION=DELETE
  SKIP_CORE=false
  SKIP_BASE=false
```

### Rollback Failed Deployment

```bash
# Option 1: Using utility script
bash infrastructure/pipelines/utilities/rollback_stack.sh \
    ascend-app-stack-prod us-east-1

# Option 2: Using CloudFormation
aws cloudformation continue-update-rollback \
    --stack-name ascend-app-stack-prod \
    --region us-east-1
```

## CI/CD Integration

### GitHub Webhook Integration

1. Go to Jenkins job → Configure
2. Scroll to Build Triggers
3. Enable "GitHub hook trigger for GITScm polling"
4. Go to GitHub repository → Settings → Webhooks
5. Add webhook:
   ```
   Payload URL: https://your-jenkins.com/github-webhook/
   Content type: application/json
   Events: Just the push event
   ```

### Automated DEV Deployment

Create GitHub workflow (`.github/workflows/deploy-dev.yml`):

```yaml
name: Deploy to DEV

on:
  push:
    branches: [main]
    paths:
      - 'infrastructure/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Trigger Jenkins Job
        run: |
          curl -X POST \
            -u ${{ secrets.JENKINS_USER }}:${{ secrets.JENKINS_TOKEN }} \
            https://your-jenkins.com/job/Infrastructure-Deployment-Main/buildWithParameters \
            -d "ENVIRONMENT=dev&ACTION=UPDATE"
```

## Parameter File Updates

### Update S3 Bucket Name for Templates

Edit all parameter files:

```bash
# configs/dev/main_parameters.json
# configs/test/main_parameters.json
# configs/prod/main_parameters.json
```

Change:
```json
{
  "ParameterKey": "TemplatesBucketName",
  "ParameterValue": "YOUR-CF-TEMPLATES-BUCKET-NAME"
}
```

### Update AWS Account ID

Edit parameter files:

```json
{
  "ParameterKey": "AwsAccountId",
  "ParameterValue": "123456789012"
}
```

## Monitoring and Alerts

### CloudFormation Stack Events

```bash
# Watch stack events in real-time
watch -n 5 'aws cloudformation describe-stack-events \
    --stack-name ascend-main-stack-prod \
    --query "StackEvents[0:5]" \
    --output table'

# Get specific event details
aws cloudformation describe-stack-events \
    --stack-name ascend-main-stack-prod \
    --query "StackEvents[?ResourceStatus=='CREATE_FAILED']"
```

### Stack Resource Status

```bash
# List all resources in stack
aws cloudformation describe-stack-resources \
    --stack-name ascend-main-stack-prod \
    --query "StackResources[*].[LogicalResourceId,ResourceStatus]" \
    --output table

# Get specific resource
aws cloudformation describe-stack-resource \
    --stack-name ascend-main-stack-prod \
    --logical-resource-id S3Bucket
```

### Stack Outputs

```bash
# Get all outputs
aws cloudformation describe-stacks \
    --stack-name ascend-main-stack-prod \
    --query "Stacks[0].Outputs[*].[OutputKey,OutputValue]" \
    --output table

# Get specific output
aws cloudformation describe-stacks \
    --stack-name ascend-main-stack-prod \
    --query "Stacks[0].Outputs[?OutputKey=='S3BucketName'].OutputValue" \
    --output text
```

## Troubleshooting Quick Fixes

### Stack in UPDATE_ROLLBACK_FAILED

```bash
# Continue rollback
aws cloudformation continue-update-rollback \
    --stack-name ascend-main-stack-prod

# Or delete and recreate
aws cloudformation delete-stack \
    --stack-name ascend-main-stack-prod
```

### S3 Bucket Already Exists

```bash
# Check bucket ownership
aws s3api head-bucket --bucket ascend-infra-bucket-prod

# List bucket contents
aws s3 ls s3://ascend-infra-bucket-prod/
```

### KMS Key Permission Issues

```bash
# Check key policy
aws kms get-key-policy \
    --key-id arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012 \
    --policy-name default

# Check key grants
aws kms list-grants \
    --key-id arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012
```

### IAM Role Not Found

```bash
# List all roles
aws iam list-roles \
    --query "Roles[?contains(RoleName, 'ascend')].[RoleName]" \
    --output table

# Get role details
aws iam get-role --role-name ascend-S3BucketRole
```

## Environment-Specific Commands

### Development Environment

```bash
# Deploy
ENVIRONMENT=dev ACTION=CREATE

# S3 Bucket Name
aws s3 ls | grep "ascend-infra-bucket-dev"

# KMS Key
aws kms list-keys --region us-east-1 | grep ascend-key-dev

# Verify
bash infrastructure/pipelines/utilities/verify_stacks.sh \
    ascend-main-stack-dev us-east-1
```

### Test Environment

```bash
# Deploy
ENVIRONMENT=test ACTION=CREATE

# S3 Bucket Name
aws s3 ls | grep "ascend-infra-bucket-test"

# Verify
bash infrastructure/pipelines/utilities/verify_stacks.sh \
    ascend-main-stack-test us-east-1
```

### Production Environment

```bash
# Deploy (requires approval)
ENVIRONMENT=prod ACTION=UPDATE

# S3 Bucket Name
aws s3 ls | grep "ascend-infra-bucket-prod"

# Verify
bash infrastructure/pipelines/utilities/verify_stacks.sh \
    ascend-main-stack-prod us-east-1
```

## Cleanup After Completion

### Generate Deployment Report

```bash
bash infrastructure/pipelines/utilities/cleanup_and_report.sh \
    ascend-main-stack-prod us-east-1
```

### Archive Old Templates

```bash
# Create backup of templates
tar -czf infrastructure-templates-backup-$(date +%Y%m%d).tar.gz \
    infrastructure/cloudformation/

# Move to archive
mv infrastructure-templates-backup-*.tar.gz backups/
```

### Remove Temporary Files

```bash
# Clean up temporary files
rm -f infrastructure/cloudformation/*/temp.yaml
rm -f infrastructure/configs/*/temp-params.json
```

## Emergency Contacts

- **DevOps Lead**: ops-lead@company.com
- **Infrastructure Team**: ops-team@company.com
- **AWS Support**: support@company.com

## Useful Links

- [Jenkins Dashboard](https://your-jenkins.com)
- [AWS CloudFormation Console](https://console.aws.amazon.com/cloudformation)
- [AWS IAM Console](https://console.aws.amazon.com/iam)
- [AWS S3 Console](https://s3.console.aws.amazon.com)
- [AWS KMS Console](https://console.aws.amazon.com/kms)
