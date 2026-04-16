# New Feature: Selective Stack Update Pipeline

## Summary
A new **Selective Stack Update Pipeline** has been added to enable independent updates of specific infrastructure stacks (Core, Base, or App) without deploying the entire stack hierarchy. The pipeline supports granular updates of individual application stacks: Cumulus, DataAPI, LeanRetina, and Retina.

## What's New

### 📄 Files Added
1. **[pipelines/Jenkinsfile_selective_update](pipelines/Jenkinsfile_selective_update)**
   - New Jenkins pipeline for selective stack updates
   - 500+ lines of well-documented Groovy code
   - Includes automated ChangeSet generation and review

2. **[pipelines/SELECTIVE_UPDATE_GUIDE.md](pipelines/SELECTIVE_UPDATE_GUIDE.md)**
   - Comprehensive guide on using the new pipeline
   - Usage examples and scenarios
   - Troubleshooting tips

### 📋 Documentation Updated
3. **[INDEX.md](INDEX.md)**
   - Added reference to the new selective update guide
   - Added task to "update only specific stacks"

## Key Features

✅ **Selective Updates**
- Choose which stacks to update: Core, Base, and/or App
- App updates automatically handle: app_policies plus all four app type roles (Cumulus, DataAPI, LeanRetina, Retina)
- Update only what you need without touching other stacks

✅ **Dry Run Mode** (Enabled by Default)
- Preview changes via CloudFormation ChangeSets
- Review what will change before applying
- Perfect for development and testing

✅ **Production Safety**
- Automatic approval gates for production environments
- Two-level approval workflow
- Change descriptions for audit trails

✅ **Template Validation**
- Validates CloudFormation syntax before deployment
- Uploads templates to S3
- Shows detailed ChangeSet before applying

✅ **Comprehensive Logging**
- Detailed pipeline output
- Stack status verification
- Timestamps and build summaries

## Usage Scenarios

### Scenario 1: Update All App Stacks
**Situation**: You've updated app-specific IAM policies (app_policies.yaml) and individual app role definitions (Cumulus, DataAPI, LeanRetina, Retina) and don't want to redeploy Base or Core.

```
SELECT:
- ENVIRONMENT: dev
- UPDATE_APP: ✓ (updates app_policies + all app roles)
- UPDATE_BASE: 
- UPDATE_CORE: 
- DRY_RUN: ✓ (preview first)
```

### Scenario 2: Update Base Stack KMS Retention Policy
**Situation**: You need to modify KMS key retention settings in the Base stack.

```
SELECT:
- ENVIRONMENT: test
- UPDATE_BASE: ✓
- UPDATE_APP: 
- UPDATE_CORE: 
- DRY_RUN:  (apply directly after review)
```

### Scenario 3: Multiple Stack Updates with Audit Trail
**Situation**: Security update affecting Core and all App policies (app_policies and individual app roles for Cumulus, DataAPI, LeanRetina, Retina), needs documentation.

```
SELECT:
- ENVIRONMENT: prod
- UPDATE_CORE: ✓
- UPDATE_APP: ✓ (updates app_policies + all app roles)
- UPDATE_BASE: 
- DRY_RUN: ✓ (review first)
- CHANGE_DESCRIPTION: "Q1 2026 Security Hardening - Added MFA requirement to all apps"
```

## How It Works

## Pipeline Stages

1. **Pre-Flight Check** - Validates that at least one stack is selected
2. **Checkout** - Clones the repository
3. **Validate Templates** - Validates CloudFormation templates for selected stacks
4. **Upload Templates** - Uploads templates to S3 bucket
5. **Generate ChangeSets** - Creates CloudFormation ChangeSets showing what will change
6. **Review & Approval** - Manual approval if DRY_RUN=true or ENVIRONMENT=prod
7. **Apply Updates** - Executes the updates (skipped if DRY_RUN=true)
8. **Verification** - Confirms all stacks updated successfully

## New Parameters

| Parameter | Type | Purpose |
|-----------|------|---------|
| **UPDATE_CORE** | Boolean | Update Core IAM Roles Stack |
| **UPDATE_BASE** | Boolean | Update Base S3 + KMS Stack |
| **UPDATE_APP** | Boolean | Update App Policies Stack |
| **DRY_RUN** | Boolean | Preview changes without applying (default: true) |
| **CHANGE_DESCRIPTION** | String | Document what changed and why |

## Comparison: Deployment Methods

### Full Infrastructure Deployment (Existing)
```
Use: Jenkinsfile_main
When: Initial setup or complete redeploy
Updates: Core → Base → App (in sequence, all stacks)
```

### Individual Stack Deployment (Existing)
```
Use: Jenkinsfile_core / Jenkinsfile_base / Jenkinsfile_app
When: Specific stack changes during development
Updates: Single stack only
```

### Selective Stack Update (NEW) ⭐
```
Use: Jenkinsfile_selective_update
When: Multiple stacks need updates with shared approval
Updates: Only selected stacks (any combination)
Features: Dry-run, ChangeSet preview, audit trail
```

## Benefits

### For Development Teams
- **Faster Iterations**: Update only what you changed
- **Lower Risk**: Isolated changes with preview mode
- **Clear Visibility**: See exact changes before applying

### For Operations
- **Atomic Updates**: Update multiple stacks in single pipeline run
- **Better Auditability**: Change descriptions and approval workflow
- **Production Safety**: Automatic gates and manual approvals

### For Organizations
- **Reduced Errors**: Dry-run catches issues before production
- **Compliance**: Full audit trail of changes
- **Cost Control**: Only deploy what's necessary

## Migration Path

### From Individual Pipeline Updates
**Before**: Run 3 separate pipelines for 3 stacks
```
Jenkins → Jenkinsfile_core          (UPDATE)
Jenkins → Jenkinsfile_base          (UPDATE)
Jenkins → Jenkinsfile_app           (UPDATE)
```

**After**: Run 1 selective update pipeline
```
Jenkins → Jenkinsfile_selective_update (UPDATE_CORE+UPDATE_BASE+UPDATE_APP)
```

## Next Steps

1. **Create Jenkins Job**
   - Add new Jenkins job pointing to `pipelines/Jenkinsfile_selective_update`
   - Configure with your Jenkins setup

2. **Test in Dev Environment**
   - Try dry-run mode first: `DRY_RUN=true`
   - Review ChangeSet output
   - Execute with `DRY_RUN=false`

3. **Adopt in Workflow**
   - Use for routine policy updates
   - Use dry-run before any production changes
   - Document changes for audit trail

4. **Reference Documentation**
   - Bookmark [SELECTIVE_UPDATE_GUIDE.md](pipelines/SELECTIVE_UPDATE_GUIDE.md)
   - Share with team

## Troubleshooting

### "At least one stack must be selected"
- ✓ Check at least one UPDATE_* checkbox

### Changes not applying
- ✓ Set `DRY_RUN=false` (default is true for safety)

### ChangeSet shows no changes
- ✓ Templates are identical to current stack (expected)

### Permission errors
- ✓ Verify Jenkins AWS credentials and IAM permissions

## File Locations

```
pipelines/
  ├── Jenkinsfile_selective_update        ← NEW: Use this for selective updates
  ├── Jenkinsfile_main                    (Full deployment)
  ├── Jenkinsfile_core                    (Core stack only)
  ├── Jenkinsfile_base                    (Base stack only)
  ├── Jenkinsfile_app                     (App stack only)
  └── SELECTIVE_UPDATE_GUIDE.md          ← NEW: Read this for usage details
```

## Questions & Support

For questions about the selective update pipeline:
1. Check [SELECTIVE_UPDATE_GUIDE.md](pipelines/SELECTIVE_UPDATE_GUIDE.md) first
2. Review examples in this document
3. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues

---

**Created**: March 31, 2026
**Status**: Ready for use
**Tested**: End-to-end from Jenkins
