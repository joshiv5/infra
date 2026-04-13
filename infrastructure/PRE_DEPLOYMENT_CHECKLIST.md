# Pre-Deployment Checklist

Use this checklist to ensure all prerequisites are met before deploying infrastructure.

## Environment Setup Checklist

### AWS Account Setup
- [ ] AWS account created and accessible
- [ ] AWS Region selected (e.g., us-east-1)
- [ ] AWS Account ID documented: `________________`
- [ ] AWS credentials configured locally
- [ ] AWS CLI installed and working
  ```bash
  aws --version
  aws sts get-caller-identity
  ```

### IAM User/Role Setup
- [ ] IAM user created for infrastructure deployment: `________________`
- [ ] IAM user has CloudFormation permissions
- [ ] IAM user has S3 permissions for CloudFormation templates bucket
- [ ] IAM user has IAM permissions (to create roles)
- [ ] IAM user has KMS permissions (key creation)
- [ ] Access keys generated and stored securely
- [ ] MFA enabled (for production) ✓ or ✗

### S3 Bucket for Templates
- [ ] S3 bucket created: `________________`
- [ ] Bucket name documented: `________________`
- [ ] Bucket region: `________________`
- [ ] Versioning enabled: ✓ or ✗
- [ ] Block Public Access enabled: ✓ or ✗
- [ ] Server-side encryption enabled: ✓ or ✗
- [ ] Bucket policy configured correctly

### Jenkins Setup
- [ ] Jenkins 2.300+ installed
- [ ] Blue Ocean plugin installed
- [ ] Pipeline plugin installed
- [ ] AWS credentials plugin installed
- [ ] GitHub plugin installed (if using GitHub)
- [ ] Jenkins service running: ✓ or ✗
- [ ] Jenkins URL accessible: `________________`

### Jenkins Jobs Created
- [ ] Infrastructure-Deployment-Main job created ✓ or ✗
- [ ] Infrastructure-Deployment-Core job created ✓ or ✗
- [ ] Infrastructure-Deployment-Base job created ✓ or ✗
- [ ] Infrastructure-Deployment-App job created ✓ or ✗

### Jenkins Credentials
- [ ] AWS credentials added to Jenkins
- [ ] Credential ID: `aws-infrastructure-deployment`
- [ ] AWS Access Key ID tested
- [ ] AWS Secret Access Key tested
- [ ] Jenkins IAM user has required permissions:
  - [ ] cloudformation:*
  - [ ] s3:*
  - [ ] iam:*
  - [ ] kms:*

## Code Repository Setup

### Repository Structure
- [ ] Repository cloned locally
- [ ] Infrastructure folder exists: `infrastructure/`
- [ ] CloudFormation templates folder: `infrastructure/cloudformation/`
- [ ] Parameter files folder: `infrastructure/configs/`
- [ ] Pipelines folder: `infrastructure/pipelines/`
- [ ] All Jenkinsfiles present:
  - [ ] `Jenkinsfile_main`
  - [ ] `Jenkinsfile_core`
  - [ ] `Jenkinsfile_base`
  - [ ] `Jenkinsfile_app`
- [ ] All utility scripts present:
  - [ ] `deploy_stack.sh`
  - [ ] `verify_stacks.sh`
  - [ ] `rollback_stack.sh`
  - [ ] `cleanup_and_report.sh`

### Template Validation
- [ ] All CloudFormation templates valid:
  ```bash
  aws cloudformation validate-template \
      --template-body file://infrastructure/cloudformation/main/main_template.yaml
  ```
- [ ] main_template.yaml validates ✓ or ✗
- [ ] core_iam_roles.yaml validates ✓ or ✗
- [ ] base_s3_kms.yaml validates ✓ or ✗
- [ ] app_policies.yaml validates ✓ or ✗

### Parameter Files
- [ ] Parameter files exist for all environments:
  - [ ] `infrastructure/configs/dev/` (all 4 parameter files)
  - [ ] `infrastructure/configs/test/` (all 4 parameter files)
  - [ ] `infrastructure/configs/prod/` (all 4 parameter files)
- [ ] Parameter files are valid JSON:
  ```bash
  python -m json.tool infrastructure/configs/dev/main_parameters.json
  ```
- [ ] All required parameters populated:
  - [ ] EnvironmentName
  - [ ] ProjectName
  - [ ] AwsAccountId
  - [ ] TemplatesBucketName
- [ ] S3 bucket names updated in parameters ✓ or ✗
- [ ] Account IDs updated in parameters ✓ or ✗

## Network and Connectivity

### AWS Connectivity
- [ ] AWS API endpoints accessible
- [ ] No network restrictions blocking AWS CLI calls
- [ ] Proxy settings configured (if applicable)
- [ ] VPC endpoints configured (if applicable)
- [ ] NAT gateway configured for private subnets (if applicable)

### Repository Connectivity
- [ ] GitHub accessible (if using GitHub)
- [ ] SSH keys configured (if using SSH for Git)
- [ ] Firewall allows Jenkins to clone repository
- [ ] Webhook configured for automatic triggers (if applicable)

## Documentation Review

### Documentation Complete
- [ ] README.md read and understood
- [ ] JENKINS_SETUP_GUIDE.md read
- [ ] QUICK_REFERENCE.md reviewed
- [ ] TROUBLESHOOTING.md reviewed

### Understanding Documentation
- [ ] Understand 4-layer stack model (Main/Core/Base/App)
- [ ] Understand environment hierarchy (dev/test/prod)
- [ ] Understand deployment sequence (Core → Base → App → Main)
- [ ] Understand rollback procedures
- [ ] Emergency contacts documented

## Pre-Development Deployment (Dev Environment)

### Local Testing
- [ ] All templates passed cfn-lint validation:
  ```bash
  pip install cfn-lint
  cfn-lint infrastructure/cloudformation/**/*.yaml
  ```
- [ ] Parameter files validated as JSON
- [ ] No syntax errors in Groovy Jenkinsfiles

### Jenkins Job Configuration
- [ ] Jenkins job for Infrastructure-Deployment-Main configured
- [ ] Job uses correct Git repository
- [ ] Job tracks correct branch (main)
- [ ] Pipeline script path: `infrastructure/pipelines/Jenkinsfile_main`

### Initial Deployment Plan
- [ ] Will deploy to DEV environment first
- [ ] ACTION parameter set to: `CREATE`
- [ ] S3 bucket path for templates confirmed
- [ ] AWS region confirmed: `us-east-1`
- [ ] Stack names documented:
  - [ ] Core: `ascend-core-stack-dev`
  - [ ] Base: `ascend-base-stack-dev`
  - [ ] App: `ascend-app-stack-dev`
  - [ ] Main: `ascend-main-stack-dev`

## Test Environment Deployment

### Pre-Test Deployment
- [ ] Development deployment verified successful
- [ ] All resources created in dev environment
- [ ] Dev stack outputs verified
- [ ] Dev resources tested and working

### Test Deployment Plan
- [ ] Will deploy to TEST environment
- [ ] ACTION parameter set to: `CREATE`
- [ ] Stack names documented:
  - [ ] Core: `ascend-core-stack-test`
  - [ ] Base: `ascend-base-stack-test`
  - [ ] App: `ascend-app-stack-test`
  - [ ] Main: `ascend-main-stack-test`

### Test Infrastructure Validation
- [ ] S3 bucket created in test account
- [ ] KMS key created and accessible
- [ ] IAM roles created correctly
- [ ] Policies attached to roles
- [ ] All resources have correct tags

## Production Environment Deployment

### Approval and Review
- [ ] Change request submitted and approved
- [ ] Code review completed:
  - [ ] Templates reviewed for security
  - [ ] Parameters reviewed for correctness
  - [ ] Policies reviewed for least privilege
- [ ] Infrastructure team approval obtained
- [ ] Security team approval obtained (if required)

### Pre-Production Checklist
- [ ] Test environment deployment verified successful
- [ ] All rollback procedures tested in test environment
- [ ] Backup procedures documented
- [ ] Disaster recovery plan reviewed

### Production Deployment Configuration
- [ ] Production AWS account confirmed: `________________`
- [ ] Production region confirmed: `us-east-1`
- [ ] Production stack names documented:
  - [ ] Core: `ascend-core-stack-prod`
  - [ ] Base: `ascend-base-stack-prod`
  - [ ] App: `ascend-app-stack-prod`
  - [ ] Main: `ascend-main-stack-prod`
- [ ] Approval gate enabled in Jenkins ✓ or ✗
- [ ] Notification recipients configured

## Backup and Disaster Recovery

### Backup Procedures
- [ ] Backup strategy documented
- [ ] Backup location: `________________`
- [ ] Backup retention policy: ___ days
- [ ] CloudFormation templates backed up
- [ ] Parameter files backed up
- [ ] IAM policies backed up

### Disaster Recovery
- [ ] Disaster recovery plan documented
- [ ] RTO (Recovery Time Objective) defined: ___ hours
- [ ] RPO (Recovery Point Objective) defined: ___hours
- [ ] Recovery procedures tested
- [ ] Contact list updated

## Monitoring and Alerts

### CloudFormation Monitoring
- [ ] CloudFormation events monitored
- [ ] SNS notifications configured
- [ ] Email alerts enabled
- [ ] Slack notifications enabled (if applicable)

### Resource Monitoring
- [ ] CloudWatch alarms configured
- [ ] IAM role usage monitored
- [ ] S3 bucket access monitored
- [ ] KMS key usage monitored

### Logging
- [ ] CloudTrail enabled for audit
- [ ] S3 access logs enabled
- [ ] VPC Flow Logs enabled (if applicable)
- [ ] CloudFormation drift detection enabled

## Security Review

### Infrastructure Security
- [ ] S3 bucket has public access blocked ✓ or ✗
- [ ] S3 objects encrypted with KMS ✓ or ✗
- [ ] KMS key policy reviewed
- [ ] KMS key rotation enabled ✓ or ✗
- [ ] S3 versioning enabled ✓ or ✗

### IAM Security
- [ ] Principle of least privilege applied ✓ or ✗
- [ ] Permissions scoped to resources ✓ or ✗
- [ ] IAM roles reviewed by security team
- [ ] No overly permissive statements (*:*)
- [ ] MFA enforcement configured

### Pipeline Security
- [ ] Jenkins credentials encrypted ✓ or ✗
- [ ] Pipeline script reviewed for security issues
- [ ] Approval gates configured for production
- [ ] Build logs do not contain sensitive data
- [ ] Secrets not stored in repository

## Final Sign-Off

### Team Lead Review
- [ ] All checklist items completed
- [ ] Infrastructure design reviewed
- [ ] Deployment plan approved
- [ ] Risk assessment completed

### DevOps Engineer Confirmation
- [ ] Ready to deploy to DEV: ✓ or ✗ (Date: _________)
- [ ] Ready to deploy to TEST: ✓ or ✗ (Date: _________)
- [ ] Ready to deploy to PROD: ✓ or ✗ (Date: _________)

### Deployment Log
```
Deployment Date: __________
Deployed By: __________
Environment: DEV / TEST / PROD
Status: SUCCESS / partial / FAILED
Notes: ________________________

Deployment Date: __________
Deployed By: __________
Environment: DEV / TEST / PROD
Status: SUCCESS / partial / FAILED
Notes: ________________________
```

## Post-Deployment Verification

### Immediate Post-Deployment (1 hour)
- [ ] All stacks in CREATE_COMPLETE or UPDATE_COMPLETE state
- [ ] All resources successfully created
- [ ] Stack outputs verified
- [ ] No errors in CloudFormation events

### Short-Term Post-Deployment (24 hours)
- [ ] All resources accessible
- [ ] All IAM roles functional
- [ ] S3 bucket accessible
- [ ] KMS key working correctly
- [ ] Policies applied correctly
- [ ] No suspicious access patterns

### Long-Term Post-Deployment (1 week)
- [ ] Infrastructure stable and operational
- [ ] No failed deployments or rollbacks
- [ ] Monitoring and alerts working
- [ ] Documentation updated
- [ ] Team trained on new infrastructure

## Completed Deployments

### Development
- [ ] Date Deployed: __________
- [ ] Status: ✓ Complete or ✗ Pending
- [ ] Notes: ________________________________________

### Test
- [ ] Date Deployed: __________
- [ ] Status: ✓ Complete or ✗ Pending
- [ ] Notes: ________________________________________

### Production
- [ ] Date Deployed: __________
- [ ] Status: ✓ Complete or ✗ Pending
- [ ] Notes: ________________________________________

---

**Deployment Approved By**: _________________________ (Signature/Name)

**Date**: _______________

**Next Review Date**: _______________
