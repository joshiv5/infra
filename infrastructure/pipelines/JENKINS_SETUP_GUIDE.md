# Jenkins Pipeline Setup Guide

Comprehensive guide for setting up and using Jenkins pipelines to deploy infrastructure CloudFormation templates.

## Overview

Four Jenkins pipelines are provided for deploying infrastructure in a controlled, hierarchical manner:

1. **Jenkinsfile_main** - Orchestrates entire deployment (Core → Base → App)
2. **Jenkinsfile_core** - Deploys Core IAM Roles (rarely changes)
3. **Jenkinsfile_base** - Deploys Base S3/KMS infrastructure
4. **Jenkinsfile_app** - Deploys App-specific policies (frequent changes)

## Prerequisites

### Jenkins Installation
- Jenkins 2.300+
- Blue Ocean plugin (recommended for better pipeline visualization)
- Pipeline plugin

### AWS Setup
- AWS CLI configured with appropriate credentials
- IAM permissions for CloudFormation operations
- S3 bucket for storing CloudFormation templates

### Jenkins Plugins Required

```groovy
plugins {
    'pipeline-model-definition': '1.10.0+',
    'blueocean': '1.25.0+',
    'github': '1.36.0+',
    'aws-codecommit-trigger': '2.0.0+',
    'timestamper': '1.11.0+'
}
```

Install via Jenkins UI:
1. Go to Manage Jenkins → Manage Plugins
2. Search for each plugin
3. Install and restart Jenkins

## Pipeline Setup

### Step 1: Configure AWS Credentials in Jenkins

1. Go to **Manage Jenkins** → **Manage Credentials**
2. Click **Global credentials** → **Add Credentials**
3. Select **AWS Credentials**
4. Fill in:
   - Access Key ID: `your-access-key`
   - Secret Access Key: `your-secret-key`
   - ID: `aws-infrastructure-deployment`
5. Click Save

### Step 2: Create Jenkins Jobs

#### Create Main Pipeline Job

1. New Item → Pipeline
2. Name: `Infrastructure-Deployment-Main`
3. In Definition section:
   - Select: Pipeline script from SCM
   - SCM: Git
   - Repository URL: `https://github.com/your-repo/ascend.git`
   - Branches: `*/main`
   - Script Path: `infrastructure/pipelines/Jenkinsfile_main`
4. Configure Build Triggers:
   - GitHub push events (if using GitHub)
   - Manual trigger only
5. Click Save

#### Create Core Stack Job

1. New Item → Pipeline
2. Name: `Infrastructure-Deployment-Core`
3. In Definition section:
   - Pipeline script from SCM → Git
   - Script Path: `infrastructure/pipelines/Jenkinsfile_core`
4. Configure for manual trigger only
5. Click Save

#### Create Base Stack Job

1. New Item → Pipeline
2. Name: `Infrastructure-Deployment-Base`
3. Script Path: `infrastructure/pipelines/Jenkinsfile_base`
4. Click Save

#### Create App Stack Job

1. New Item → Pipeline
2. Name: `Infrastructure-Deployment-App`
3. Script Path: `infrastructure/pipelines/Jenkinsfile_app`
4. Click Save

### Step 3: Configure AWS Credentials in Pipeline Scripts

In each Jenkinsfile, add AWS credentials configuration:

```groovy
pipeline {
    agent any
    
    environment {
        AWS_CREDENTIALS = credentials('aws-infrastructure-deployment')
    }
    
    // ... rest of configuration
}
```

## Running Pipelines

### Main Orchestrated Deployment

For initial deployment to an environment:

```bash
1. Go to Jenkins
2. Click "Infrastructure-Deployment-Main"
3. Click "Build with Parameters"
4. Set Parameters:
   - ENVIRONMENT: dev / test / prod
   - ACTION: CREATE
   - SKIP_CORE: false
   - SKIP_BASE: false
   - AWS_REGION: us-east-1
   - CF_TEMPLATES_BUCKET: your-bucket-name
5. Click "Build"
```

**Timeline for complete deployment**: ~20-30 minutes (depending on KMS and S3 provisioning)

### Update App Stack (Most Common)

For pushing new policies/permissions:

```bash
1. Go to Jenkins
2. Click "Infrastructure-Deployment-App"
3. Click "Build with Parameters"
4. Set Parameters:
   - ENVIRONMENT: dev / test / prod
   - ACTION: UPDATE
   - CHANGE_DESCRIPTION: "Add Lambda execution policy"
5. Click "Build"
```

**Timeline**: ~5-10 minutes

### Update Base Stack

For infrastructure changes (rare):

```bash
1. Go to Jenkins
2. Click "Infrastructure-Deployment-Base"
3. Click "Build with Parameters"
4. Set Parameters:
   - ENVIRONMENT: test or prod
   - ACTION: UPDATE
5. Approve when prompted
6. Click "Build"
```

### Delete Stack (Cleanup)

```bash
1. Go to Jenkins
2. Click appropriate pipeline job
3. Click "Build with Parameters"
4. ACTION: DELETE
5. Confirm deletion
6. Click "Build"
```

**Warning**: Deleting Base stack will delete S3 buckets and KMS keys!

## Pipeline Stages Explained

### Main Orchestrated Pipeline Stages:

1. **Validation**
   - Validates environment and action parameters
   - Production confirmation gate

2. **Checkout**
   - Clones repository

3. **Validate Templates**
   - Validates all CloudFormation templates syntax
   - Uses `aws cloudformation validate-template`

4. **Upload Templates to S3**
   - Uploads templates to S3 bucket
   - Makes templates available for nested stacks

5. **Deploy Core Stack**
   - Creates IAM roles (skippable)
   - Dependencies: None

6. **Deploy Base Stack**
   - Creates S3 bucket and KMS key
   - Dependencies: Core Stack

7. **Deploy App Stack**
   - Creates policies and roles
   - Dependencies: Base Stack

8. **Deploy Main Stack**
   - Orchestrates all nested stacks
   - Dependencies: All previous stacks

9. **Verify Deployment**
   - Checks all stacks are in healthy state
   - Generates resource summary

## Environment-Specific Parameters

### Development Environment

```json
{
  "ENVIRONMENT": "dev",
  "ACTION": "CREATE",
  "AWS_REGION": "us-east-1",
  "CF_TEMPLATES_BUCKET": "your-cf-templates-bucket"
}
```

### Test Environment

```json
{
  "ENVIRONMENT": "test",
  "ACTION": "UPDATE",
  "AWS_REGION": "us-east-1",
  "CF_TEMPLATES_BUCKET": "your-cf-templates-bucket"
}
```

### Production Environment

```json
{
  "ENVIRONMENT": "prod",
  "ACTION": "UPDATE",
  "AWS_REGION": "us-east-1",
  "CF_TEMPLATES_BUCKET": "your-cf-templates-bucket"
}
```

## Pipeline Logs and Troubleshooting

### View Pipeline Logs

1. Click on build number (e.g., "#123")
2. Click "Console Output"
3. View real-time logs

### Common Errors and Solutions

#### Error: "Invalid CloudFormation credentials"
- **Solution**: Check AWS credentials in Jenkins → Manage Credentials
- Verify IAM permissions include CloudFormation, S3, IAM, KMS

#### Error: "Stack already exists"
- **Solution**: Use UPDATE action instead of CREATE
- Or use SKIP_CORE/SKIP_BASE to skip already deployed stacks

#### Error: "S3 bucket not found"
- **Solution**: Update CF_TEMPLATES_BUCKET parameter
- Ensure bucket exists and is accessible
- Verify AWS credentials have S3 permissions

#### Error: "KMS key policy error"
- **Solution**: Check KMS key permissions
- Verify IAM role has `kms:*` permissions
- Review KMS key policies in Base stack

#### Error: "Public access denied" on S3
- **Solution**: This is expected - S3 bucket is secured
- Use IAM roles to access bucket

### Debug Mode

Add debug logging to scripts:

```bash
set -x  # Enable debug output at top of script
```

Check CloudFormation events:

```bash
aws cloudformation describe-stack-events \
  --stack-name ascend-main-stack-dev \
  --region us-east-1
```

## Advanced Configuration

### Parameter Stores

Store sensitive parameters in AWS Systems Manager Parameter Store:

```bash
aws ssm put-parameter \
  --name /infrastructure/cf-templates-bucket \
  --value your-bucket-name \
  --type String
```

Reference in pipeline:

```groovy
CF_TEMPLATES_BUCKET = sh(
    script: '''
        aws ssm get-parameter \
            --name /infrastructure/cf-templates-bucket \
            --query 'Parameter.Value' \
            --output text
    ''',
    returnStdout: true
).trim()
```

### Slack Notifications

Add Slack notification to post-build:

```groovy
post {
    success {
        slackSend(
            color: 'good',
            message: "Infrastructure deployment successful for ${ENVIRONMENT}"
        )
    }
    failure {
        slackSend(
            color: 'danger',
            message: "Infrastructure deployment failed for ${ENVIRONMENT}"
        )
    }
}
```

### Email Notifications

```groovy
post {
    always {
        emailext(
            subject: "Infrastructure Deployment ${currentBuild.result}",
            body: "Job: ${env.JOB_NAME}\nBuild: ${env.BUILD_NUMBER}",
            to: "ops-team@company.com"
        )
    }
}
```

## Rollback Procedures

### Manual Rollback using Script

```bash
bash infrastructure/pipelines/utilities/rollback_stack.sh \
    ascend-app-stack-prod \
    us-east-1
```

### Rollback via CloudFormation Console

1. Go to CloudFormation console
2. Select stack
3. Stack Actions → Continue Update Rollback

## Maintenance and Best Practices

### Daily Checks
- Monitor Jenkins logs for pipeline failures
- Verify all stacks in CloudFormation console
- Check S3 bucket access logs

### Weekly Tasks
- Review CloudFormation change sets
- Audit IAM role permissions
- Check KMS key usage

### Monthly Review
- Analyze deployment times
- Review policy changes
- Update documentation

### Security Best Practices
1. **Credentials Management**
   - Rotate AWS access keys quarterly
   - Use IAM roles instead of access keys when possible
   - Never commit credentials to repository

2. **Change Management**
   - Review all policy changes before applying
   - Test in dev/test before production
   - Maintain audit trail of changes

3. **Access Control**
   - Restrict Jenkins job execution to authorized users
   - Use Jenkins roles plugin for role-based access
   - Enable MFA for production deployments

4. **Monitoring**
   - Enable CloudTrail for all AWS API calls
   - Monitor CloudFormation stack events
   - Alert on stack failures

## Support and Documentation

For issues or questions:

1. Check pipeline logs in Jenkins
2. Review CloudFormation events
3. Consult AWS documentation
4. Contact DevOps team

## References

- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)
- [AWS CloudFormation Best Practices](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/best-practices.html)
- [Groovy Syntax Reference](https://groovy-lang.org/syntax.html)
