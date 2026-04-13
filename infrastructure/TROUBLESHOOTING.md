# Infrastructure Deployment Troubleshooting Guide

Comprehensive troubleshooting guide for infrastructure deployment issues.

## Pre-Deployment Issues

### CloudFormation Template Validation Failures

#### Error: "Template format error: invalid JSON"

**Symptoms**: Pipeline fails at template validation stage

**Causes**:
- JSON syntax error in CloudFormation template
- Unquoted keys or values
- Missing commas between properties

**Resolution**:
```bash
# Validate template syntax
aws cloudformation validate-template \
    --template-body file://infrastructure/cloudformation/main/main_template.yaml

# Or use cfn-lint
pip install cfn-lint
cfn-lint infrastructure/cloudformation/**/*.yaml
```

**Example Fix**:
```yaml
# Wrong
Resources
  MyBucket:
    Type: AWS::S3::Bucket

# Right
Resources:
  MyBucket:
    Type: AWS::S3::Bucket
```

#### Error: "Template format error: unresolved reference"

**Symptoms**: Reference to parameter or resource that doesn't exist

**Solution**:
```yaml
# Check all references match defined parameters/resources
Parameters:
  BucketName:
    Type: String

Resources:
  MyBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Ref BucketName  # BucketName must be defined
```

#### Error: "IAM policy contains invalid action"

**Symptoms**: Template validation fails with invalid IAM action

**Solution**:
- Check IAM action names are correct
- Visit AWS documentation for correct action format

```yaml
# Wrong
Action: s3:GetObject,s3:DeleteObject

# Right
- s3:GetObject
- s3:DeleteObject
```

### Parameter File Issues

#### Error: "Invalid parameter format in parameters.json"

**Symptoms**: Jenkins fails to read parameters

**Resolution**:
```bash
# Validate parameter file JSON
python -m json.tool infrastructure/configs/dev/main_parameters.json

# Or use jq
jq empty infrastructure/configs/dev/main_parameters.json
```

**Example Valid Format**:
```json
[
  {
    "ParameterKey": "EnvironmentName",
    "ParameterValue": "dev"
  },
  {
    "ParameterKey": "ProjectName",
    "ParameterValue": "ascend"
  }
]
```

#### Error: "Parameter TemplatesBucketName not provided"

**Symptoms**: Stack creation fails missing parameter

**Resolution**:
1. Verify parameter exists in `main_parameters.json`
2. Verify parameter name matches template exactly
3. Check for typos

```bash
# List parameters in template
grep "^  [A-Z]" infrastructure/cloudformation/main/main_template.yaml | head -20
```

## AWS Credentials and Permissions

### Error: "Unable to assume role"

**Symptoms**: 
- Pipeline fails immediately with authorization error
- "User is not authorized to perform: sts:AssumeRole"

**Diagnosis**:
```bash
# Check current credentials
aws sts get-caller-identity

# Check assumed role
aws sts get-assumed-role-user
```

**Resolution**:
1. Verify AWS credentials in Jenkins:
   - Go to Jenkins → Manage Credentials
   - Edit `aws-infrastructure-deployment` credentials
   - Verify Access Key ID and Secret Access Key

2. Verify IAM permissions:
```bash
# Check inline policies
aws iam list-user-policies --user-name your-jenkins-user

# Check attached policies
aws iam list-attached-user-policies --user-name your-jenkins-user

# Check policy details
aws iam get-user-policy \
    --user-name your-jenkins-user \
    --policy-name CloudFormationAccess
```

3. Ensure policy includes required actions:
```json
{
  "Version": "2012-10-17",
  "Statement": [
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
  ]
}
```

### Error: "AWS credentials not found"

**Symptoms**: 
- Jenkins fails with "Unable to locate credentials"
- Cannot access AWS services

**Resolution**:
1. Verify Jenkins credential ID in Jenkinsfile matches Jenkins configuration:
   ```groovy
   // In Jenkinsfile
   environment {
       AWS_CREDENTIALS = credentials('aws-infrastructure-deployment')
   }
   ```

2. Create credentials if not exists:
   - Jenkins → Manage Credentials → Global → Add Credentials
   - Type: AWS Credentials
   - ID: `aws-infrastructure-deployment`

3. Or use AWS regional configuration:
   ```bash
   # On Jenkins server
   aws configure set aws_access_key_id YOUR_KEY
   aws configure set aws_secret_access_key YOUR_SECRET
   aws configure set default.region us-east-1
   ```

## CloudFormation Deployment Issues

### Error: "Stack already exists"

**Symptoms**:
- Stack creation fails because stack with same name exists
- "Stack with id ascend-main-stack-prod already exists"

**Resolution**:
1. Use UPDATE action instead of CREATE:
   ```
   ENVIRONMENT=prod ACTION=UPDATE
   ```

2. Or delete existing stack first:
   ```bash
   aws cloudformation delete-stack \
       --stack-name ascend-main-stack-prod \
       --region us-east-1
   
   # Wait for deletion
   aws cloudformation wait stack-delete-complete \
       --stack-name ascend-main-stack-prod \
       --region us-east-1
   ```

3. Then create new stack:
   ```
   ENVIRONMENT=prod ACTION=CREATE
   ```

### Error: "Resource already exists"

**Symptoms**:
- "S3 bucket already exists"
- "KMS key already exists"
- Stack creation fails

**Resolution for S3 Bucket**:
```bash
# Check bucket
aws s3 ls | grep "ascend-infra-bucket-prod"

# If bucket exists from different account/stack:
# Option 1: Delete bucket (if safe)
aws s3 rb s3://ascend-infra-bucket-prod --force

# Option 2: Change bucket name in parameters
# Edit: infrastructure/configs/prod/base_parameters.json
# Change: S3BucketName to unique value
```

**Resolution for KMS Key**:
```bash
# List KMS keys
aws kms list-keys --region us-east-1

# Check key aliases
aws kms list-aliases --region us-east-1

# If key exists and stack needs new one:
# Edit base_parameters.json and change KMS key identifier
```

### Error: "UPDATE_ROLLBACK_FAILED"

**Symptoms**:
- Stack is in failed state
- Cannot update or delete stack
- "Stack is in UPDATE_ROLLBACK_FAILED status"

**Resolution**:
```bash
# Continue rollback to recover stack
aws cloudformation continue-update-rollback \
    --stack-name ascend-main-stack-prod \
    --region us-east-1

# Wait for rollback to complete
aws cloudformation wait stack-update-complete \
    --stack-name ascend-main-stack-prod \
    --region us-east-1

# Or force delete (use with caution)
aws cloudformation delete-stack \
    --stack-name ascend-main-stack-prod \
    --region us-east-1
```

### Error: "CREATE_IN_PROGRESS timeout"

**Symptoms**:
- Stack creation takes longer than expected
- Pipeline times out waiting for stack creation
- "Stack creation exceeded timeout period"

**Causes**:
- S3 bucket creation slow (usually 5-10 seconds)
- KMS key creation slow (usually 10-15 seconds)
- Network issues or AWS service latency

**Resolution**:
1. Increase wait timeout in deploy script:
```bash
# In deploy_stack.sh, increase WAIT_TIME
WAIT_TIME=1800  # 30 minutes instead of 15
```

2. Check stack events to find bottleneck:
```bash
aws cloudformation describe-stack-events \
    --stack-name ascend-main-stack-prod \
    --query "StackEvents[?ResourceStatus=='CREATE_IN_PROGRESS']" \
    --output table
```

3. Check if specific resource is stuck:
```bash
aws cloudformation describe-stack-resources \
    --stack-name ascend-main-stack-prod \
    --query "StackResources[?ResourceStatus=='CREATE_IN_PROGRESS']"
```

### Error: "Encountered unsupported property StackName while deploying main stack"

**Symptoms**:
- CloudFormation template validation fails
- "Encountered unsupported property StackName"
- Stack deployment fails immediately with CoreStack in CREATE_FAILED state

**Root Cause**:
- `StackName` property is NOT supported on nested stacks (`AWS::CloudFormation::Stack`)
- CloudFormation automatically generates nested stack names with pattern: `ParentStackName-LogicalResourceId-RandomIdentifier`
- Attempting to explicitly set `StackName` causes validation failure

**Common Mistake**:
```yaml
# INCORRECT - StackName is unsupported on nested stacks
Resources:
  CoreStack:
    Type: AWS::CloudFormation::Stack
    Properties:
      StackName: !Sub '${ProjectName}-core-stack-${EnvironmentName}'  # ERROR!
      TemplateURL: !Ref CoreTemplateURL
```

**Correct Solution**:
```yaml
# CORRECT - Remove StackName property entirely
Resources:
  CoreStack:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Ref CoreTemplateURL
      Parameters:
        EnvironmentName: !Ref EnvironmentName
        ProjectName: !Ref ProjectName
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentTag
```

**Resolution Steps**:

1. **Fix main_template.yaml**:
   - Remove `StackName` property from CoreStack, BaseStack, and AppStack resources
   - Keep all other properties (TemplateURL, Parameters, Tags, etc.)

2. **Validate corrected template**:
```bash
aws cloudformation validate-template \
    --template-body file://infrastructure/cloudformation/main/main_template.yaml
```

3. **Delete failed stack** (from AWS Console or CLI):
```bash
aws cloudformation delete-stack \
    --stack-name ascend-main-stack-dev \
    --region us-east-1

# Wait for deletion to complete
aws cloudformation wait stack-delete-complete \
    --stack-name ascend-main-stack-dev \
    --region us-east-1
```

4. **Redeploy**:
```bash
ENVIRONMENT=dev ACTION=CREATE
```

**Note on Nested Stack Naming**:
- CloudFormation will automatically generate a unique name for each nested stack
- Generated names follow pattern: `MainStackName-LogicalId-RandomString`
- Example: `ascend-main-stack-dev-CoreStack-ABC123XYZ`
- You cannot control or customize nested stack names explicitly

### Error: "Export with name X is already exported by stack Y"

**Symptoms**:
- Embedded stack creation fails
- "Export with name ascend-s3-role-arn-dev is already exported by stack ascend-main-stack-dev"
- CloudFormation export naming conflict

**Root Cause**:
- Multiple stacks trying to export the same CloudFormation export name
- Common when both nested stacks AND parent stack export identical names
- CloudFormation export names must be unique within a region and account

**Solution**:
Follow the best practice pattern for nested stacks:
- **Only the parent/orchestrator stack should export** values
- Nested stacks should output values (no exports)
- Parent stack references nested stack outputs and re-exports them if needed

**Implementation**:

1. **Remove exports from nested stack templates**:

   BEFORE (nested stack - WRONG):
   ```yaml
   # core_iam_roles.yaml
   Outputs:
     S3BucketRoleArn:
       Value: !GetAtt S3BucketRole.Arn
       Export:
         Name: !Sub '${ProjectName}-s3-role-arn-${EnvironmentName}'  # ERROR!
   ```

   AFTER (nested stack - CORRECT):
   ```yaml
   # core_iam_roles.yaml
   Outputs:
     S3BucketRoleArn:
       Value: !GetAtt S3BucketRole.Arn
       # No Export!
   ```

2. **Parent stack references nested outputs and exports**:

   ```yaml
   # main_template.yaml
   Resources:
     CoreStack:
       Type: AWS::CloudFormation::Stack
       Properties:
         TemplateURL: ...
   
   Outputs:
     S3BucketRoleArn:
       Value: !GetAtt CoreStack.Outputs.S3BucketRoleArn
       Export:
         Name: !Sub '${ProjectName}-s3-role-arn-${EnvironmentName}'  # OK - unique
   ```

3. **Fixed templates in your infrastructure**:
   - [core_iam_roles.yaml](infrastructure/cloudformation/core/core_iam_roles.yaml) - removed exports
   - [base_s3_kms.yaml](infrastructure/cloudformation/base/base_s3_kms.yaml) - removed exports
   - [app_policies.yaml](infrastructure/cloudformation/app/app_policies.yaml) - removed exports
   - [main_template.yaml](infrastructure/cloudformation/main/main_template.yaml) - added all exports

4. **Verify no duplicate exports**:
```bash
# Check all export names across templates
grep -r "Name: !Sub" infrastructure/cloudformation/**/*.yaml | grep "Export:"

# Should show no duplicates
```

5. **Delete failed stack and redeploy**:
```bash
aws cloudformation delete-stack --stack-name ascend-main-stack-dev
aws cloudformation wait stack-delete-complete --stack-name ascend-main-stack-dev
# Then redeploy
```

**Best Practices for Nested Stacks**:
- Nested stacks: Output values WITHOUT Export
- Parent stack: Reference nested outputs and add Export if needed for external consumption
- This keeps the public CloudFormation API at the parent level only

## Deploying App Template Only

### Scenario: Update only app policies after infrastructure is already deployed

**Option 1: Using Main Template with DeployApp=false** (Recommended for CI/CD):

```bash
# First deployment: Deploy everything
ENVIRONMENT=dev DeployApp=true ACTION=CREATE

# Subsequent app-only updates: Skip core and base, deploy only app
ENVIRONMENT=dev DeployApp=true ACTION=UPDATE
```

**Option 2: Using Standalone App Template** (For independent app deployments):

When you need to deploy app policies to existing infrastructure without touching core or base stacks:

1. **Prerequisites**: Core and Base stacks must already be deployed and exports available
   - Export: `ascend-s3-role-arn-dev`
   - Export: `ascend-s3-bucket-dev`
   - Export: `ascend-kms-key-dev`

2. **Deploy with standalone template**:
   ```bash
   # Upload standalone app template to S3
   aws s3 cp infrastructure/cloudformation/app/app_standalone.yaml \
       s3://ascend-cf-templates-bucket/app/app_standalone.yaml

   # Create stack using standalone template (no dependencies needed)
   aws cloudformation create-stack \
       --stack-name ascend-app-policies-dev \
       --template-url https://s3.amazonaws.com/ascend-cf-templates-bucket/app/app_standalone.yaml \
       --parameters \
         ParameterKey=EnvironmentName,ParameterValue=dev \
         ParameterKey=EnvironmentTag,ParameterValue=dev \
         ParameterKey=ProjectName,ParameterValue=ascend \
       --capabilities CAPABILITY_NAMED_IAM \
       --region us-east-1
   ```

3. **For updates**:
   ```bash
   aws cloudformation update-stack \
       --stack-name ascend-app-policies-dev \
       --template-url https://s3.amazonaws.com/ascend-cf-templates-bucket/app/app_standalone.yaml \
       --parameters \
         ParameterKey=EnvironmentName,ParameterValue=dev \
         ParameterKey=EnvironmentTag,ParameterValue=dev \
         ParameterKey=ProjectName,ParameterValue=ascend \
       --capabilities CAPABILITY_NAMED_IAM \
       --region us-east-1
   ```

**When to use each option**:
- **Option 1 (DeployApp parameter)**: Normal CI/CD pipeline, want single stack orchestration
- **Option 2 (Standalone template)**: Independent app deployments, separate release cycles, existing infrastructure

**Important Notes**:
- Standalone template uses `!ImportValue` to reference existing exports
- Exports must be available (from main stack's Core and Base stacks)
- Standalone app stack is independent and won't break if main stack is updated
- Both approaches create the same policies and roles - choose based on your workflow

## S3 and Encryption Issues

### Error: "Access Denied to S3 bucket"

**Symptoms**:
- "Access Denied" when uploading templates to S3
- "User: arn:aws:iam::123456789012:user/jenkins is not authorized to perform: s3:PutObject"

**Resolution**:
1. Check IAM permissions:
```bash
aws iam get-user-policy \
    --user-name your-jenkins-user \
    --policy-name S3Access
```

2. Add missing S3 permissions:
```json
{
  "Effect": "Allow",
  "Action": [
    "s3:PutObject",
    "s3:GetObject",
    "s3:DeleteObject",
    "s3:ListBucket"
  ],
  "Resource": [
    "arn:aws:s3:::ascend-cf-templates-bucket/*",
    "arn:aws:s3:::ascend-cf-templates-bucket"
  ]
}
```

3. Update CloudFormation templates bucket policy:
```bash
# Get current policy
aws s3api get-bucket-policy \
    --bucket ascend-cf-templates-bucket

# Update policy to allow Jenkins user
aws s3api put-bucket-policy \
    --bucket ascend-cf-templates-bucket \
    --policy file://bucket-policy.json
```

### Error: "KMS key not found"

**Symptoms**:
- "KMS key not found: arn:aws:kms:region:account:key/id"
- S3 bucket encryption fails

**Resolution**:
```bash
# List available KMS keys
aws kms list-keys --region us-east-1

# List key aliases
aws kms list-aliases --region us-east-1 | grep ascend

# Describe specific key
aws kms describe-key \
    --key-id arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012

# If key doesn't exist, create new one
aws kms create-key --region us-east-1 --description "ascend-infra-key-prod"
```

### Error: "KMS permission denied"

**Symptoms**:
- "User: arn:aws is not authorized to perform: kms:Decrypt"
- S3 bucket operations fail

**Resolution**:
1. Check KMS key policy:
```bash
aws kms get-key-policy \
    --key-id arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012 \
    --policy-name default \
    --query "Policy" \
    --output text | python -m json.tool
```

2. Add Jenkins user to KMS key policy:
```bash
# Get current policy
aws kms get-key-policy \
    --key-id arn:aws:kms:us-east-1:123456789012:key/xxxxx \
    --policy-name default > kms-policy.json

# Edit policy to add Jenkins user
{
  "Sid": "Allow Jenkins",
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::123456789012:user/jenkins"
  },
  "Action": "kms:*",
  "Resource": "*"
}

# Apply policy
aws kms put-key-policy \
    --key-id arn:aws:kms:us-east-1:123456789012:key/xxxxx \
    --policy-name default \
    --policy file://kms-policy.json
```

### Error: "S3 bucket is not versioning-enabled"

**Symptoms**:
- Stack creation succeeds but bucket not properly configured
- Versioning not enabled for prod environment

**Resolution**:
1. Check bucket versioning status:
```bash
aws s3api get-bucket-versioning \
    --bucket ascend-infra-bucket-prod
```

2. Enable versioning:
```bash
aws s3api put-bucket-versioning \
    --bucket ascend-infra-bucket-prod \
    --versioning-configuration Status=Enabled
```

3. Or re-deploy stack with versioning enabled in template

## IAM and Policy Issues

### Error: "Invalid policy document"

**Symptoms**:
- CloudFormation fails to create IAM policy
- "Invalid policy document"
- Policy syntax validation error

**Resolution**:
1. Validate policy syntax:
```bash
# Check policy JSON structure
python -m json.tool app_policies.yaml
```

2. Common errors:
```json
// Wrong - missing Resource
{
  "Effect": "Allow",
  "Action": "s3:GetObject"
}

// Right - Resource required
{
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::bucket/*"
}
```

### Error: "Role already exists"

**Symptoms**:
- "EntityAlreadyExists: Role with name ascend-S3BucketRole already exists"

**Resolution**:
1. Update stack instead of create:
   ```
   ACTION=UPDATE
   ```

2. Or import existing role:
   - Delete and recreate with different name
   - Or modify template to import existing role

### Error: "Service role not trusted"

**Symptoms**:
- "AssumeRolePolicyDocument not valid"
- Trust policy validation fails

**Resolution**:
```bash
# Check role trust policy
aws iam get-role --role-name ascend-S3BucketRole

# Update trust policy
aws iam update-assume-role-policy \
    --role-name ascend-S3BucketRole \
    --policy-document file://trust-policy.json
```

**Example Trust Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

## Jenkins Pipeline Issues

### Error: "Pipeline script not found"

**Symptoms**:
- "Script path does not exist: infrastructure/pipelines/Jenkinsfile_main"
- Pipeline job fails to start

**Resolution**:
1. Verify Jenkinsfile exists in repository:
```bash
ls -la infrastructure/pipelines/Jenkinsfile_*
```

2. Check Jenkins job configuration:
   - Jenkins → Job → Configure
   - Definition → Script Path
   - Verify path matches actual location

3. Trigger SCM polling:
   ```bash
   # In Jenkins job page, click "Build Now"
   # Then check if script path is recognized
   ```

### Error: "Build step failed with exception null"

**Symptoms**:
- Generic build failure
- No clear error message

**Resolution**:
1. Check Jenkins logs:
```bash
# On Jenkins server
tail -f /var/log/jenkins/jenkins.log
```

2. Check build console output:
   - Click build number → Console Output
   - Scroll to bottom for error details

3. Add debug output:
   - Edit Jenkinsfile, add `set -x` to bash steps
   - Redeploy and check console

### Error: "Approval timeout"

**Symptoms**:
- Production deployment stuck waiting for approval
- "Pipeline is paused"

**Resolution**:
1. Find pending approval:
   - Jenkins → Infrastructure-Deployment-App
   - Click build number
   - "Paused for Input"

2. Approve deployment:
   - Click "Proceed" button
   - Or reject to cancel

3. Increase approval timeout:
```groovy
// In Jenkinsfile
timeout(time: 2, unit: 'HOURS') {
    input 'Approve deployment to production?'
}
```

## Recovery Procedures

### Recover from Failed Deployment

**Step 1: Identify the issue**
```bash
aws cloudformation describe-stack-events \
    --stack-name ascend-main-stack-prod \
    --query "StackEvents[?ResourceStatus=='CREATE_FAILED']"
```

**Step 2: Rollback**
```bash
aws cloudformation continue-update-rollback \
    --stack-name ascend-main-stack-prod
```

**Step 3: Fix the issue**
- Update template
- Update parameters
- Check permissions

**Step 4: Redeploy**
```
ACTION=UPDATE
ENVIRONMENT=prod
```

### Recover from Deleted Stack

**If stack was accidentally deleted**:
```bash
# Check stack deletion
aws cloudformation describe-stacks \
    --stack-name ascend-main-stack-prod

# If gone, recreate from pipeline
Jenkins Job: Infrastructure-Deployment-Main
Parameters:
  ENVIRONMENT=prod
  ACTION=CREATE
```

**Note**: Recreating will fail if resources still exist:
- Find and delete orphaned resources
- Or change resource names in parameters

### Emergency Cleanup

**If infrastructure is corrupted and needs rebuild**:

```bash
# 1. Delete all stacks (in reverse order)
bash infrastructure/pipelines/utilities/cleanup_and_report.sh \
    ascend-main-stack-prod us-east-1

# 2. Manually delete any orphaned resources
aws s3 rb s3://ascend-infra-bucket-prod --force
aws kms schedule-key-deletion \
    --key-id arn:aws:kms:us-east-1:123456789012:key/xxxxx \
    --pending-window-in-days 7

# 3. Redeploy from scratch
Jenkins Job: Infrastructure-Deployment-Main
Parameters:
  ENVIRONMENT=prod
  ACTION=CREATE
  SKIP_CORE=false
  SKIP_BASE=false
```

## Getting Help

### Collect Diagnostic Information

When reporting issues, collect:

```bash
# Jenkins configuration
aws --version
aws sts get-caller-identity

# Stack information
aws cloudformation describe-stacks \
    --stack-name ascend-main-stack-prod

# Stack events (last 20)
aws cloudformation describe-stack-events \
    --stack-name ascend-main-stack-prod \
    --max-items 20

# Create support bundle
mkdir -p support-bundle
aws cloudformation describe-stacks > support-bundle/stacks.json
aws cloudformation describe-stack-events \
    --stack-name ascend-main-stack-prod > support-bundle/events.json
aws iam list-roles | grep ascend > support-bundle/roles.json
```

### Contact Support

- **DevOps Team**: ops-team@company.com
- **AWS Support**: support.aws.amazon.com
- **Jenkins Admin**: jenkins-admin@company.com
