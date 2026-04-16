# Infrastructure as Code - IAM, S3, and KMS Management

## Overview

This infrastructure project provides a hierarchical CloudFormation-based approach for managing IAM roles, S3 buckets, and KMS keys across multiple environments (dev, test, prod).

## Directory Structure

```
infrastructure/
├── cloudformation/
│   ├── main/
│   │   └── main_template.yaml          # Orchestrator template for nested stacks
│   ├── core/
│   │   └── core_iam_roles.yaml         # Stable IAM roles (unchanged in future)
│   ├── base/
│   │   └── base_s3_kms.yaml            # Base S3 bucket and KMS setup
│   └── app/
│       └── app_policies.yaml           # App-specific policies (frequent changes)
└── configs/
    ├── dev/
    │   ├── main_parameters.json        # Dev environment main parameters
    │   ├── core_parameters.json        # Dev environment core parameters
    │   ├── base_parameters.json        # Dev environment base parameters
    │   └── app_parameters.json         # Dev environment app parameters
    ├── test/
    │   ├── main_parameters.json        # Test environment main parameters
    │   ├── core_parameters.json        # Test environment core parameters
    │   ├── base_parameters.json        # Test environment base parameters
    │   └── app_parameters.json         # Test environment app parameters
    └── prod/
        ├── main_parameters.json        # Prod environment main parameters
        ├── core_parameters.json        # Prod environment core parameters
        ├── base_parameters.json        # Prod environment base parameters
        └── app_parameters.json         # Prod environment app parameters
```

## Template Hierarchy and Purpose

### 1. **Main Template** (`main_template.yaml`)
- **Purpose**: Orchestrates the deployment of all nested stacks
- **Change Frequency**: Rarely (only when adding/removing stacks)
- **Responsibility**: 
  - Coordinates Core, Base, and App stacks
  - Passes outputs between stacks
  - Manages stack dependencies
  - Exports key resources for other templates

### 2. **Core Template** (`core_iam_roles.yaml`)
- **Purpose**: Creates foundational IAM roles
- **Change Frequency**: Never (frozen after initial setup)
- **Responsibility**:
  - S3BucketRole - for S3 access
  - KMSKeyRole - for KMS key access
  - Instance profiles for EC2
  - AssumeRolePolicies for services (EC2, ECS, Lambda)
- **Resources**:
  - AWS::IAM::Role
  - AWS::IAM::InstanceProfile

### 3. **Base Template** (`base_s3_kms.yaml`)
- **Purpose**: Creates core infrastructure resources
- **Change Frequency**: Limited (only infrastructure-level changes)
- **Responsibility**:
  - S3 bucket creation
  - KMS key creation and encryption setup
  - Bucket logging and versioning
  - Lifecycle policies
  - Security policies (SSL, encryption enforcement)
- **Resources**:
  - AWS::S3::Bucket
  - AWS::KMS::Key
  - AWS::KMS::Alias
  - AWS::S3::BucketPolicy

### 4. **App Template** (`app_policies.yaml`)
- **Purpose**: Application-specific policies and permissions
- **Change Frequency**: Frequent (can change every sprint)
- **Responsibility**:
  - Fine-grained S3 access policies
  - KMS usage policies
  - CloudWatch logging permissions
  - Application service roles
- **Resources**:
  - AWS::IAM::Policy (inline policies)
  - AWS::IAM::Role (application service roles)

## Deployment Guide

### Prerequisites

1. Upload CloudFormation templates to S3:
   ```bash
   aws s3 cp infrastructure/cloudformation/core/core_iam_roles.yaml s3://your-cf-templates-bucket/infrastructure/cloudformation/core/
   aws s3 cp infrastructure/cloudformation/base/base_s3_kms.yaml s3://your-cf-templates-bucket/infrastructure/cloudformation/base/
   aws s3 cp infrastructure/cloudformation/app/app_policies.yaml s3://your-cf-templates-bucket/infrastructure/cloudformation/app/
   ```

2. Update S3 bucket URLs in parameter files:
   - Edit `configs/<env>/main_parameters.json`
   - Replace `your-cf-templates-bucket` with your actual S3 bucket name

### Deployment Steps

#### Method 1: AWS CloudFormation Console
1. Go to CloudFormation console
2. Create Stack → Upload template file
3. Select `cloudformation/main/main_template.yaml`
4. Provide parameters from `configs/<env>/main_parameters.json`
5. Review and create stack

#### Method 2: AWS CLI

**Deploy for Development:**
```bash
aws cloudformation create-stack \
  --stack-name ascend-main-stack-dev \
  --template-body file://infrastructure/cloudformation/main/main_template.yaml \
  --parameters file://infrastructure/configs/dev/main_parameters.json \
  --capabilities CAPABILITY_NAMED_IAM
```

**Deploy for Test:**
```bash
aws cloudformation create-stack \
  --stack-name ascend-main-stack-test \
  --template-body file://infrastructure/cloudformation/main/main_template.yaml \
  --parameters file://infrastructure/configs/test/main_parameters.json \
  --capabilities CAPABILITY_NAMED_IAM
```

**Deploy for Production:**
```bash
aws cloudformation create-stack \
  --stack-name ascend-main-stack-prod \
  --template-body file://infrastructure/cloudformation/main/main_template.yaml \
  --parameters file://infrastructure/configs/prod/main_parameters.json \
  --capabilities CAPABILITY_NAMED_IAM
```

#### Method 3: Jenkins Pipeline (CI/CD) ⭐ **Recommended for Automation**

Automate infrastructure deployments using Jenkins with nested stack orchestration.

**Setup:**
1. Follow [pipelines/JENKINS_QUICK_START.md](pipelines/JENKINS_QUICK_START.md) for Jenkins configuration
2. Choose the correct Jenkinsfile for your platform:
   - **Windows Jenkins**: Use `pipelines/Jenkinsfile_main_windows`
   - **Linux/Mac Jenkins**: Use `pipelines/Jenkinsfile_main_linux`
3. See [pipelines/JENKINSFILE_VARIANTS.md](pipelines/JENKINSFILE_VARIANTS.md) for detailed comparison

**Deploy via Jenkins:**
1. Go to Jenkins job: `ascend-infrastructure-deployment`
2. Click **Build with Parameters**
3. Select environment and action:
   - **ENVIRONMENT**: dev / test / prod
   - **ACTION**: CREATE / UPDATE / DELETE
4. Monitor in Blue Ocean interface

**Benefits:**
- ✅ Automated validation of all templates
- ✅ Automatic S3 upload of templates
- ✅ Single orchestrated deployment (no manual coordination)
- ✅ Production approval gates
- ✅ Comprehensive deployment reporting
- ✅ Integrated with version control (Git)
- ✅ Audit trail of all deployments

**Example workflow:**
```
Development: Commit → Push → Jenkins triggers → Deploy to DEV
Testing: Manual trigger → Deploy to TEST
Production: Manual trigger + Approval → Deploy to PROD
```

### Updating Stacks

**Update Core Stack** (rare):
```bash
aws cloudformation update-stack \
  --stack-name ascend-core-stack-<env> \
  --template-body file://infrastructure/cloudformation/core/core_iam_roles.yaml \
  --parameters file://infrastructure/configs/<env>/core_parameters.json \
  --capabilities CAPABILITY_NAMED_IAM
```

**Update Base Stack** (occasional):
```bash
aws cloudformation update-stack \
  --stack-name ascend-base-stack-<env> \
  --template-body file://infrastructure/cloudformation/base/base_s3_kms.yaml \
  --parameters file://infrastructure/configs/<env>/base_parameters.json \
  --capabilities CAPABILITY_NAMED_IAM
```

**Update App Stack** (frequent):
```bash
aws cloudformation update-stack \
  --stack-name ascend-app-stack-<env> \
  --template-body file://infrastructure/cloudformation/app/app_policies.yaml \
  --parameters file://infrastructure/configs/<env>/app_parameters.json \
  --capabilities CAPABILITY_NAMED_IAM
```

## Key Resources Created

### By Core Stack
- `ascend-s3-bucket-role-<env>`: IAM role for S3 access
- `ascend-kms-key-role-<env>`: IAM role for KMS access
- `ascend-s3-instance-profile-<env>`: EC2 instance profile

### By Base Stack
- `ascend-bucket-<env>-<account-id>`: Main S3 bucket
- `ascend-logs-<env>-<account-id>`: Logging S3 bucket
- `alias/ascend-s3-<env>`: KMS key alias
- S3 bucket policies for encryption enforcement

### By App Stack
- S3 bucket access policies
- KMS key access policies
- CloudWatch logs policies
- `ascend-app-service-role-<env>`: Application service role

## Environment-Specific Configurations

### Development
- **Versioning**: Suspended
- **Logging**: Enabled
- **Encryption**: AWS KMS (Standard)
- **Lifecycle**: 90-day retention for old versions

### Test
- **Versioning**: Suspended
- **Logging**: Enabled
- **Encryption**: AWS KMS (Standard)
- **Lifecycle**: 90-day retention for old versions

### Production
- **Versioning**: Enabled (for data protection)
- **Logging**: Enabled
- **Encryption**: AWS KMS (Standard)
- **Lifecycle**: 90-day retention for old versions, 180-day transition to Glacier

## Security Features

1. **Encryption at Rest**: All S3 objects encrypted with KMS
2. **Encryption in Transit**: SSL enforced (deny unencrypted requests)
3. **Access Control**: 
   - Public access blocked
   - IAM policies for granular permissions
   - KMS key policies for encryption key protection
4. **Logging**: S3 access logs stored in separate logging bucket
5. **Data Protection**: Versioning enabled in production

## Modifying Policies for Sprint/Requirements

To add new permissions for app requirements:

1. Edit `cloudformation/app/app_policies.yaml`
2. Add new IAM::Policy statements in appropriate sections
3. Add new Action permissions needed
4. Update Resource ARNs if needed
5. Deploy using:
   ```bash
   aws cloudformation update-stack \
     --stack-name ascend-app-stack-<env> \
     --template-body file://infrastructure/cloudformation/app/app_policies.yaml \
     --parameters file://infrastructure/configs/<env>/app_parameters.json \
     --capabilities CAPABILITY_NAMED_IAM
   ```

## Outputs and Exports

All stacks export key resources for use in other stacks:

- `ascend-s3-bucket-<env>`: S3 bucket name
- `ascend-s3-bucket-arn-<env>`: S3 bucket ARN
- `ascend-kms-key-id-<env>`: KMS key ID
- `ascend-kms-key-arn-<env>`: KMS key ARN
- `ascend-s3-role-arn-<env>`: S3 role ARN
- `ascend-app-service-role-arn-<env>`: App service role ARN

## Troubleshooting

### Stack Creation Failed
1. Check CloudFormation events for error details
2. Verify IAM permissions (CAPABILITY_NAMED_IAM required)
3. Ensure S3 template URLs are correct and accessible

### Access Denied Errors
1. Verify IAM policies are attached to correct roles
2. Check KMS key policies allow principal actions
3. Check S3 bucket policies for SSL enforcement

### KMS Key Errors
1. Ensure KMS key ARN in policies matches actual key ARN
2. Verify key policies include necessary principals
3. Check key rotation settings if applicable

## Best Practices

1. **Version Control**: Keep all templates in version control
2. **Change Management**: Use app_policies.yaml for sprint changes
3. **Testing**: Test updates in dev/test before production
4. **Documentation**: Update this README when adding features
5. **Tagging**: All resources tagged for cost allocation
6. **Cleanup**: Use CloudFormation to manage resource lifecycle

## Additional Resources

- [AWS CloudFormation Documentation](https://docs.aws.amazon.com/cloudformation/)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [AWS KMS Best Practices](https://docs.aws.amazon.com/kms/latest/developerguide/best-practices.html)
- [AWS S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/BestPractices.html)
