# Windows Jenkins Setup - Quick Reference Card

## ⏱️ 5-Minute Quick Start

### 1. Verify Prerequisites (2 minutes)

Open **PowerShell** and run:
```powershell
# Check PowerShell version (must be 5.1+)
$PSVersionTable.PSVersion

# Install/verify AWS CLI v2
aws --version

# Verify Git
git --version

# Test AWS credentials
aws sts get-caller-identity
```

### 2. Enable PowerShell Script Execution (1 minute)

Run as **Administrator**:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

### 3. Configure Jenkins Job (2 minutes)

In Jenkins UI:
- Create new **Pipeline** job
- Name: `ascend-infrastructure-deployment`
- **Pipeline** tab → **Pipeline script from SCM**
- **SCM**: `Git`
- **Repository URL**: `https://github.com/chinmay1908/infra.git`
- **Script Path**: `infrastructure/pipelines/Jenkinsfile_main_windows`
- **Save**

## 📋 Required Files

```
infrastructure/
├── pipelines/
│   ├── Jenkinsfile_main_windows          ← USE THIS FILE
│   ├── JENKINS_QUICK_START.md            ← Read first
│   ├── JENKINSFILE_VARIANTS.md           ← Platform guide
│   └── WINDOWS_JENKINS_RESOLUTION.md     ← Troubleshooting
├── cloudformation/
│   ├── main/main_template.yaml
│   ├── core/core_iam_roles.yaml
│   ├── base/base_s3_kms.yaml
│   └── app/app_policies.yaml
└── configs/
    ├── dev/main_parameters.json
    ├── test/main_parameters.json
    └── prod/main_parameters.json
```

## ▶️ Run Your First Deployment

### DEV Environment (Recommended First):
1. Click **Build with Parameters**
2. Set values:
   - **ENVIRONMENT**: `dev`
   - **ACTION**: `CREATE`
   - **AWS_REGION**: `eu-central-1`
   - **CF_TEMPLATES_BUCKET**: `ascend-test-poc`
3. Click **Build**
4. Monitor in **Blue Ocean** interface

### Expected Pipeline Stages:
```
✓ Validation ..................... Parameter checks + prod approval gate
✓ Checkout ....................... Clone repository
✓ Validate Templates ............ CloudFormation validation (all 4 templates)
✓ Upload Templates to S3 ........ Push templates to S3
✓ Deploy Main Stack ............. Create/update/delete CloudFormation stacks
✓ Verify Deployment ............. Check stack status and resources
✓ Generate Report ............... Create deployment artifact
```

**Total Time**: ~15-30 minutes (first deployment slower)

## 🔧 Troubleshooting - Quick Fixes

| Error | Solution |
|-------|----------|
| "Cannot run program 'sh'" | Verify using `Jenkinsfile_main_windows` not `Jenkinsfile_main` |
| "ExecutionPolicy" error | Run: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force` |
| "aws: not found" or "aws: The term 'aws' is not recognized" | Install AWS CLI v2 from https://aws.amazon.com/cli/ |
| "argument --region: expected one argument" | ✅ FIXED - Variable expansion issue resolved in Jenkinsfile_main_windows |
| "Access Denied" error | Check AWS IAM role has CloudFormation, S3, IAM, KMS permissions |
| Template validation fails | Check S3 template URLs in parameters match bucket name |
| Stack creation timeout | Check CloudFormation events in AWS console for blocking conditions |

## 📊 PowerShell Line Continuations (Reference)

**Backquote `` ` `` at end of line** (not backslash):
```powershell
# ✓ CORRECT (Windows PowerShell):
aws cloudformation create-stack `
    --stack-name my-stack `
    --template-body file://template.yaml

# ✗ WRONG (Linux syntax - won't work on Windows):
aws cloudformation create-stack \
    --stack-name my-stack \
    --template-body file://template.yaml
```

## 🔑 Key Parameters

| Parameter | Example Values | Notes |
|-----------|---|---|
| **ENVIRONMENT** | dev, test, prod | Required - controls environment isolation |
| **ACTION** | CREATE, UPDATE, DELETE | Required - CloudFormation action |
| **AWS_REGION** | eu-central-1, us-east-1 | Default: eu-central-1 |
| **CF_TEMPLATES_BUCKET** | ascend-test-poc | Where templates are uploaded |
| **DEPLOY_APP** | true, false | Skip App stack if false |

## ✅ Verification Checklist

Before running pipeline:
- [ ] PowerShell version is 5.1+
- [ ] AWS CLI is installed and working
- [ ] Git is installed
- [ ] AWS credentials configured (`aws sts get-caller-identity` works)
- [ ] Jenkins job points to `Jenkinsfile_main_windows`
- [ ] S3 bucket exists and is accessible

After deployment:
- [ ] Stack creation completed in AWS CloudFormation console
- [ ] All nested stacks show CREATE_COMPLETE or UPDATE_COMPLETE
- [ ] Jenkins build shows "SUCCESS"
- [ ] Deployment report artifact is available

## 📞 Need Help?

### Documentation:
- **Getting Started**: [JENKINS_QUICK_START.md](JENKINS_QUICK_START.md)
- **Platform Comparison**: [JENKINSFILE_VARIANTS.md](JENKINSFILE_VARIANTS.md)
- **Windows Details**: [WINDOWS_JENKINS_RESOLUTION.md](WINDOWS_JENKINS_RESOLUTION.md)
- **Infrastructure Guide**: [../README.md](../README.md)
- **Troubleshooting**: [../TROUBLESHOOTING.md](../TROUBLESHOOTING.md)

### Common Tasks:

**Monitor Stack Creation**:
```powershell
# Watch real-time updates (runs every 5 seconds)
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

**View Deployment Report**:
- Jenkins UI → Build page → Artifacts → `deployment_report.txt`

**Check Stack Outputs**:
```powershell
aws cloudformation describe-stacks `
    --stack-name ascend-main-stack-dev `
    --region eu-central-1 `
    --query 'Stacks[0].Outputs' `
    --output table
```

**List All Nested Stacks**:
```powershell
aws cloudformation list-stacks `
    --region eu-central-1 `
    --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE `
    --query "StackSummaries[?contains(StackName, 'dev')].StackName" `
    --output table
```

## 🚀 Next Steps

1. ✅ Run first deployment to **DEV** environment
2. ✅ Verify resources in **AWS CloudFormation console**
3. ✅ Test stack outputs and Resources tab
4. ✅ Deploy to **TEST** environment (same process)
5. ✅ Deploy to **PROD** environment (requires manual approval)

---

**For detailed guide**: See [JENKINS_QUICK_START.md](JENKINS_QUICK_START.md)
**For troubleshooting**: See [JENKINSFILE_VARIANTS.md](JENKINSFILE_VARIANTS.md#troubleshooting)
