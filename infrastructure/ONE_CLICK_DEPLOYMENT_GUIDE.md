# One-Click Infrastructure Deployment with App Roles

## Architecture Overview

```
Main Stack (ascend-main-stack-{env})
├── Core Stack (Nested)
│   ├── S3BucketRole
│   ├── EC2Role (if extended)
│   └── KMSKeyRole
│
├── Base Stack (Nested)
│   ├── S3 Bucket + Logging
│   └── KMS Key
│
├── App Stack (Nested) - Policies
│   ├── S3 Access Policy
│   ├── KMS Access Policy
│   └── CloudWatch Logs Policy
│
└── Application Roles Stacks (Nested)
    ├── Cumulus Roles Stack
    │   ├── S3 Role
    │   └── Lambda Role
    ├── Retina Roles Stack
    │   ├── S3 Role
    │   └── Lambda Role
    ├── DataAPI Roles Stack
    │   ├── S3 Role
    │   └── Lambda Role
    └── LeanRetina Roles Stack
        ├── S3 Role
        └── Lambda Role
```

---

## One-Click Deployment: Jenkinsfile_main_windows

### **Scenario 1: FIRST-TIME DEPLOYMENT (All Resources)**

1. **Open Jenkins Dashboard**
2. **Select Job:** `Jenkinsfile_main_windows`
3. **Click:** "Build with Parameters"
4. **Set Parameters:**
   - **ENVIRONMENT**: `dev`
   - **ACTION**: `CREATE`
   - **AWS_REGION**: `eu-central-1`
   - **CF_TEMPLATES_BUCKET**: `ascend-test-poc`
   - **DEPLOY_APP**: ✅ (checked)
   - **DEPLOY_APP_ROLES**: ✅ (checked)

5. **Click:** "Build"
6. **Wait** for pipeline to complete

**What Gets Deployed:**
- ✅ Core Stack (IAM Roles)
- ✅ Base Stack (S3 + KMS)
- ✅ App Stack (Policies)
- ✅ Cumulus Roles Stack
- ✅ Retina Roles Stack
- ✅ DataAPI Roles Stack
- ✅ LeanRetina Roles Stack

**Expected Result:** All 7 nested stacks created under one Main Stack

**Deploy to Test:**
- Repeat with ENVIRONMENT: `test`

**Deploy to Prod:**
- Repeat with ENVIRONMENT: `prod` (will require approval)

---

### **Scenario 2: DEPLOY WITHOUT APP STACKS**

If you want infrastructure without role stacks:

- **DEPLOY_APP**: ✅ (checked)
- **DEPLOY_APP_ROLES**: ❌ (unchecked)

This deploys only: Core → Base → App (skips all app role stacks)

---

### **Scenario 3: DEPLOY ONLY NEW APP ROLES**

If infrastructure already exists and you only want to add app roles:

1. Modify main_parameters.json:
   - Set **DeployApp**: `false`
   - Keep **DeployAppRoles**: `true`

2. Run Jenkinsfile_main_windows with UPDATE action

This updates only the app role nested stacks

---

## Later Updates: Jenkinsfile_selective_update

### **Update Scenario 1: Modify Cumulus Lambda Role**

1. Edit `cloudformation/app/app_cumulus_roles.yaml`
   - Add/modify Lambda role policies or permissions

2. **Select Job:** `Jenkinsfile_selective_update`
3. **Set Parameters:**
   - **ENVIRONMENT**: `dev`
   - **UPDATE_CORE**: ❌
   - **UPDATE_BASE**: ❌
   - **UPDATE_APP**: ❌
   - **DRY_RUN**: ✅ (true - to Preview)

4. **Click:** "Build"
5. Review ChangeSet showing only Lambda role changes
6. **Re-run with DRY_RUN**: ❌ to apply changes

---

### **Update Scenario 2: Modify All App Roles**

If you update template structure affecting all app role stacks:

1. Edit `cloudformation/main/main_template.yaml` if needed
2. Edit all 4 app role templates
3. Update S3 bucket templates in parameter files

4. **Select Job:** `Jenkinsfile_selective_update`
5. **Set Parameters:**
   - **ENVIRONMENT**: `dev`
   - **UPDATE_CORE**: ❌
   - **UPDATE_BASE**: ❌
   - **UPDATE_APP**: ❌
   - **DRY_RUN**: ✅
   - Set any custom change description

6. **Click:** "Build"

---

### **Update Scenario 3: Modify Core or Base**

Only update infrastructure layers if needed:

**For Core IAM Changes:**
- **UPDATE_CORE**: ✅
- Others: ❌

**For Base S3/KMS Changes:**
- **UPDATE_BASE**: ✅
- Others: ❌

**For App Policies Changes:**
- **UPDATE_APP**: ✅
- Others: ❌

---

## Pre-Deployment Checklist

Before running deployments:

### **1. Verify Configuration Files**

✅ All main_parameters.json files have correct URLs:

```bash
# Check dev
cat configs/dev/main_parameters.json | grep -i "RolesTemplateURL"

# Output should show:
# "CumulusRolesTemplateURL"
# "RetinaRolesTemplateURL"
# "DataAPIRolesTemplateURL"
# "LeanRetinaRolesTemplateURL"
```

### **2. Verify Templates Exist**

```bash
# All 7 templates should exist:
ls -la cloudformation/core/core_iam_roles.yaml
ls -la cloudformation/base/base_s3_kms.yaml
ls -la cloudformation/app/app_policies.yaml
ls -la cloudformation/app/app_cumulus_roles.yaml
ls -la cloudformation/app/app_retina_roles.yaml
ls -la cloudformation/app/app_dataapi_roles.yaml
ls -la cloudformation/app/app_leanretina_roles.yaml
ls -la cloudformation/main/main_template.yaml
```

### **3. Update Bucket Names**

Update master parameter files if bucket name is different:

```json
# In all main_parameters.json files:
{
  "ParameterKey": "CumulusRolesTemplateURL",
  "ParameterValue": "https://YOUR-BUCKET.s3.REGION.amazonaws.com/infrastructure/cloudformation/app/app_cumulus_roles.yaml"
}
```

### **4. Verify S3 Bucket Access**

```powershell
# Test S3 access
aws s3 ls s3://your-cf-templates-bucket/

# You should have permissions to:
# - upload templates
# - create stack from URL
```

---

## Directory Structure Summary

```
infrastructure/
├── cloudformation/
│   ├── core/
│   │   └── core_iam_roles.yaml
│   ├── base/
│   │   └── base_s3_kms.yaml
│   ├── app/
│   │   ├── app_policies.yaml
│   │   ├── app_cumulus_roles.yaml      ← NEW
│   │   ├── app_retina_roles.yaml       ← NEW
│   │   ├── app_dataapi_roles.yaml      ← NEW
│   │   └── app_leanretina_roles.yaml   ← NEW
│   └── main/
│       └── main_template.yaml          ← UPDATED
│
├── configs/
│   ├── dev/
│   │   └── main_parameters.json        ← UPDATED
│   ├── test/
│   │   └── main_parameters.json        ← UPDATED
│   └── prod/
│       └── main_parameters.json        ← UPDATED
│
└── pipelines/
    ├── Jenkinsfile_main_windows        ← UPDATED
    ├── Jenkinsfile_selective_update    ← Use for later updates
    └── APP_ROLES_DEPLOYMENT_GUIDE.md
```

---

## Deployment Workflow

### **Phase 1: Development Environment**

```
1. One-click: Jenkinsfile_main_windows (dev, CREATE)
   ↓ Deploy all infrastructure + app roles
2. Verify: All stacks created successfully
3. Manual: Update app team that roles ready
4. Later: Use selective_update for changes
```

### **Phase 2: Test Environment**

```
1. One-click: Jenkinsfile_main_windows (test, CREATE)
   ↓ Copy dev to test
2. Updates: Use selective_update for test-specific changes
```

### **Phase 3: Production**

```
1. One-click: Jenkinsfile_main_windows (prod, CREATE)
   ↓ Requires approval before deploy
2. Monitor: All stacks deployed
3. Updates: Use selective_update with conservative change management
```

---

## Monitoring & Verification

### **After Deployment**

```bash
# 1. Check all nested stacks created
aws cloudformation describe-stacks \
  --stack-name ascend-main-stack-dev \
  --query 'Stacks[0].StackStatus' \
  --output table

# 2. List all nested stacks
aws cloudformation list-stacks \
  --stack-status-filter CREATE_COMPLETE \
  --query 'StackSummaries[?contains(StackName, `ascend`)].StackName' \
  --output table

# 3. Verify app roles created
aws iam list-roles \
  --query 'Roles[?contains(RoleName, `cf-`)].RoleName' \
  --output table

# 4. Check role exports
aws cloudformation list-exports \
  --query 'Exports[?contains(Name, `cf-`)].{Name:Name,Value:Value}' \
  --output table
```

---

## Troubleshooting

### **Main Stack Fails**

Check nested stack events:

```bash
# Get main stack details
aws cloudformation describe-stack-resources \
  --stack-name ascend-main-stack-dev \
  --query 'StackResources[?ResourceStatus==`CREATE_FAILED`]'

# Check specific nested stack
aws cloudformation describe-stack-events \
  --stack-name cf-cumulus-roles-dev \
  --query 'StackEvents[0:5]'
```

### **Template Validation Errors**

Check parameter values in main_parameters.json match actual template names

### **S3 Upload Fails**

Verify Jenkins IAM role has:
- `s3:PutObject`
- `s3:GetObject`
- `s3:ListBucket`

---

## Summary: What You Get

✅ **One-Click Deployment**
- Single Jenkins job deploys all infrastructure + app roles
- All nested stacks configured with dependencies
- Parallel deployment where possible

✅ **Later Updates**
- Selective_update pipeline for individual stack changes
- No need to redeploy everything
- ChangeSet preview before applying

✅ **Scalable**
- Add more app role templates easily
- Update main_template.yaml to add them as nested stacks
- Same deployment pipeline for all

✅ **Production-Ready**
- ApprovalGates for prod deployments
- Dry-run capability with ChangeSet preview
- Detailed audit trail in Jenkins

---

**Next Steps:**

1. Update bucket names in `/configs/**/main_parameters.json`
2. Run: **Jenkinsfile_main_windows** with dev environment
3. Verify all stacks deployed: `aws cloudformation describe-stacks`
4. Use **Jenkinsfile_selective_update** for future role updates
