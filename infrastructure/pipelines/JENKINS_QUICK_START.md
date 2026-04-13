# Jenkins Deployment Quick Start Guide

## Overview

Deploy Ascend infrastructure using Jenkins with nested CloudFormation stacks. A single pipeline orchestrates the deployment of Core → Base → App stacks automatically.

## Prerequisites

### AWS Setup
```bash
# Verify AWS CLI is configured
aws sts get-caller-identity

# Ensure S3 bucket exists (templates will be uploaded here)
aws s3 ls s3://ascend-test-poc/infrastructure/cloudformation/
```

### Jenkins Requirements
- Jenkins 2.300+
- AWS CLI installed on Jenkins agent
- AWS IAM credentials configured in Jenkins
- Groovy 2.4+ support

### Windows Jenkins Agent Requirements
If running Jenkins on Windows, ensure the following are installed:
- **PowerShell 5.1+** (Windows PowerShell or PowerShell Core)
- **Git for Windows** (for repository checkout)
- **AWS CLI v2 for Windows** (https://aws.amazon.com/cli/)

#### Windows PowerShell Execution Policy

Allow PowerShell scripts to run:
```powershell
# Run as Administrator in PowerShell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

#### Verify Windows Setup
```powershell
# Check PowerShell version
$PSVersionTable.PSVersion

# Verify AWS CLI
aws --version

# Test AWS credentials
aws sts get-caller-identity
```

### Jenkins Plugins Required

Install via **Manage Jenkins** → **Manage Plugins**:
- Pipeline
- Pipeline: Stage View
- Blue Ocean (recommended)
- Timestamper
- AWS CloudFormation Plugin (optional but recommended)

## Step 1: Configure AWS Credentials in Jenkins

1. Go to **Manage Jenkins** → **Manage Credentials**
2. Click **System** → **Global credentials**
3. Click **Add Credentials**
4. Select **AWS Credentials** from the dropdown
5. Fill in:
   - **Access Key ID**: Your AWS access key
   - **Secret Access Key**: Your AWS secret key
   - **ID**: `aws-credentials-prod` (or similar)
6. Click **Create**

Repeat for other environments if needed.

## Step 2: Create Jenkins Pipeline Job

### Choose Correct Jenkinsfile for Your Platform

- **Linux/Mac Jenkins Agent**: Use `Jenkinsfile_main` (Bash/Shell based)
- **Windows Jenkins Agent**: Use `Jenkinsfile_main_windows` (PowerShell based)

### Option A: Using Blue Ocean (Recommended)

1. Go to Jenkins home
2. Click **New Item**
3. Enter job name: `ascend-infrastructure-deployment`
4. Select **Pipeline**
5. Click **Create**
6. Under **Pipeline**, select **Pipeline script from SCM**
7. Fill in:
   - **SCM**: Git
   - **Repository URL**: `https://github.com/your-org/ascend.git`
   - **Credentials**: Select your Git credentials
   - **Branch**: `*/main`
   - **Script Path**: `infrastructure/pipelines/Jenkinsfile_main` (Linux/Mac) or `infrastructure/pipelines/Jenkinsfile_main_windows` (Windows)
8. Click **Save**

### Option B: Using Classic Jenkins

1. Go to **New Item**
2. Enter job name and select **Pipeline**
3. Click **Scripted pipeline** tab
4. Copy content from [Jenkinsfile_main](Jenkinsfile_main)
5. Click **Save**

## Step 3: Deploy Infrastructure

### First Deployment (DEV Environment)

1. Go to your pipeline job
2. Click **Build with Parameters**
3. Set parameters:
   - **ENVIRONMENT**: `dev`
   - **ACTION**: `CREATE`
   - **AWS_REGION**: `eu-central-1`
   - **CF_TEMPLATES_BUCKET**: `ascend-test-poc`
   - **DEPLOY_APP**: `true`
4. Click **Build**
5. Monitor progress in Blue Ocean

### Subsequent Deployments

For updates:
1. Set **ACTION** to `UPDATE`
2. Click **Build**

The pipeline will:
- ✅ Validate all templates
- ✅ Upload templates to S3
- ✅ Create/update the main stack
- ✅ Wait for nested stacks to complete
- ✅ Verify deployment
- ✅ Generate deployment report

## Pipeline Stages

```
1. Validation      - Parameter validation + prod approval gate
2. Checkout        - Clone repository
3. Validate        - CloudFormation template validation
4. Upload to S3    - Push templates to S3 bucket
5. Deploy Stack    - Create/update main stack
6. Verify          - Check stack status and resources
7. Report          - Generate deployment report
```

## Deployment Parameters

| Parameter | Options | Default | Description |
|-----------|---------|---------|-------------|
| ENVIRONMENT | dev, test, prod | - | Target environment |
| ACTION | CREATE, UPDATE, DELETE | - | CloudFormation action |
| AWS_REGION | Any AWS region | eu-central-1 | Target region |
| CF_TEMPLATES_BUCKET | Any S3 bucket | ascend-test-poc | Templates location |
| DEPLOY_APP | true, false | true | Deploy App stack |

## Monitoring Deployments

### Real-time Logs
1. Click on running build in Jenkins
2. View **Console Output** or use **Blue Ocean** interface

### Stack Status in AWS Console

#### Linux/Mac
```bash
# Watch stack creation in real-time
watch -n 5 'aws cloudformation describe-stacks \
  --stack-name ascend-main-stack-dev \
  --region eu-central-1 \
  --query "Stacks[0].StackStatus" \
  --output text'
```

#### Windows PowerShell
```powershell
# Watch stack creation (runs every 5 seconds)
while ($true) {
    Clear-Host
    aws cloudformation describe-stacks `
        --stack-name ascend-main-stack-dev `
        --region eu-central-1 `
        --query "Stacks[0].[StackStatus,LastUpdatedTime]" `
        --output table
    Start-Sleep -Seconds 5
}
```

### With AWS CLI
```bash
# Get full stack details
aws cloudformation describe-stacks \
  --stack-name ascend-main-stack-dev \
  --region eu-central-1

# View nested stacks
aws cloudformation list-stacks \
  --region eu-central-1 \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE
```

## Common Issues

### Pipeline Fails: "Invalid parameters"
**Solution**: Verify parameter values in Jenkins job configuration match your environment.

### Pipeline Fails: "Access Denied"
**Solution**: 
1. Check AWS IAM role has CloudFormation permissions:
   ```json
   {
     "Effect": "Allow",
     "Action": [
       "cloudformation:*",
       "s3:*",
       "iam:*",
       "kms:*",
       "ec2:*"
     ],
     "Resource": "*"
   }
   ```
2. Verify Jenkins agent can assume CloudFormation role

### Stack Creation Hangs
**Solution**: Check CloudFormation events in AWS console for blocking conditions

### Template Upload Fails
**Solution**: 
1. Verify S3 bucket exists and is accessible
2. Check bucket name spelling in Jenkins parameters
3. Confirm AWS credentials have S3 permissions

## Advanced Usage

### Skip App Stack Deployment
Set **DEPLOY_APP** to `false` to skip App stack (useful for infrastructure-only updates)

### Delete Infrastructure
1. Set **ACTION** to `DELETE`
2. For **PROD**, will require manual approval
3. Pipeline deletes main stack (nested stacks auto-deleted)

### View Deployment Report
After successful deployment:
1. Click **Artifacts** on build page
2. Download `deployment_report.txt`

## Rollback

If deployment fails:

### Automatic Rollback
CloudFormation automatically rolls back on failure (can be disabled if needed)

### Manual Rollback
```bash
aws cloudformation continue-update-rollback \
  --stack-name ascend-main-stack-dev \
  --region eu-central-1
```

## Post-Deployment Verification

### Check Stack Outputs
```bash
aws cloudformation describe-stacks \
  --stack-name ascend-main-stack-dev \
  --region eu-central-1 \
  --query 'Stacks[0].Outputs'
```

### Verify S3 Bucket
```bash
aws s3 ls s3://ascend-bucket-dev-123456789012/
```

### Verify KMS Key
```bash
aws kms list-aliases --region eu-central-1 | grep ascend
```

### Verify IAM Roles
```bash
aws iam list-roles | grep ascend
```

## Next Steps

1. ✅ Set up Jenkins credentials for your AWS account
2. ✅ Create the pipeline job using Jenkinsfile_main
3. ✅ Run first deployment to DEV environment
4. ✅ Verify resources in AWS console
5. ✅ Deploy to TEST environment
6. ✅ Deploy to PROD environment (with approval)

## Support

- **Jenkins Documentation**: https://jenkins.io/doc
- **AWS CloudFormation**: https://docs.aws.amazon.com/cloudformation
- **Troubleshooting**: See [TROUBLESHOOTING.md](../TROUBLESHOOTING.md)

