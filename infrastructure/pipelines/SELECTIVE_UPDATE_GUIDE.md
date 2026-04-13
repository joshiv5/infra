# Selective Stack Update Pipeline - Quick Reference

## Overview
The **Selective Stack Update Pipeline** allows you to update only specific stacks (Core, Base, or App) without deploying the entire infrastructure. Perfect for updating policies and resources in individual stacks.

## File
- **Jenkins Pipeline**: `Jenkinsfile_selective_update`
- **Trigger**: Create a new Jenkins job pointing to this Jenkinsfile

## When to Use

| Scenario | Pipeline | Description |
|----------|----------|-------------|
| Update only App policies | Selective Update | New features/policies without touching Base/Core |
| Update only Base resources | Selective Update | Modify S3/KMS settings independently |
| Update only Core IAM roles | Selective Update | Update role permissions without affecting stacks |
| Full deployment (ordered) | Jenkinsfile_main | Deploy Core → Base → App in sequence |
| Deploy individual stack | Jenkinsfile_core, Jenkinsfile_base, Jenkinsfile_app | Direct stack-specific pipeline |

## Parameters

| Parameter | Type | Options | Default | Notes |
|-----------|------|---------|---------|-------|
| **ENVIRONMENT** | Choice | dev, test, prod | - | Required: Select target environment |
| **UPDATE_CORE** | Boolean | true/false | false | Check to update Core IAM Roles stack |
| **UPDATE_BASE** | Boolean | true/false | false | Check to update Base (S3+KMS) stack |
| **UPDATE_APP** | Boolean | true/false | false | Check to update App Policies stack |
| **AWS_REGION** | String | e.g., us-east-1 | us-east-1 | AWS region for deployment |
| **CF_TEMPLATES_BUCKET** | String | S3 bucket name | your-cf-templates-bucket | Bucket containing templates |
| **CHANGE_DESCRIPTION** | String | Any text | "Policy/Resource Updates" | Audit trail description |
| **DRY_RUN** | Boolean | true/false | **true** | Preview changes (ChangeSets) without applying |

## Usage Examples

### Example 1: Dry Run - Preview App Policy Changes
```
ENVIRONMENT: dev
UPDATE_APP: ✓ (checked)
UPDATE_CORE: (unchecked)
UPDATE_BASE: (unchecked)
DRY_RUN: ✓ (checked)
CHANGE_DESCRIPTION: "Add S3 logging permissions"
```
**Result**: App stack ChangeSet is created and displayed. No changes applied.

### Example 2: Update Only Base Stack
```
ENVIRONMENT: test
UPDATE_BASE: ✓ (checked)
UPDATE_APP: (unchecked)
UPDATE_CORE: (unchecked)
DRY_RUN: (unchecked)
CHANGE_DESCRIPTION: "Increase KMS key retention policy"
```
**Result**: Base stack is updated with new KMS settings.

### Example 3: Update Multiple Independent Stacks
```
ENVIRONMENT: dev
UPDATE_CORE: ✓ (checked)
UPDATE_APP: ✓ (checked)
UPDATE_BASE: (unchecked)
DRY_RUN: ✓ (checked)
CHANGE_DESCRIPTION: "Q1 security updates"
```
**Result**: Shows ChangeSets for both Core and App stacks (executed in order).

### Example 4: Production Update with Safety Gates
```
ENVIRONMENT: prod
UPDATE_APP: ✓ (checked)
UPDATE_BASE: (unchecked)
UPDATE_CORE: (unchecked)
DRY_RUN: (unchecked)
CHANGE_DESCRIPTION: "Release sprint 24 policies"
```
**Result**: 
1. Pre-flight check requires approval (manual intervention)
2. ChangeSet review requires approval (manual intervention)
3. App stack is updated

## Pipeline Flow

```
Pre-Flight Check
    ↓ (validates selection & production safety)
Checkout
    ↓
Validate Templates
    ↓ (validates each selected stack's template)
Upload Templates to S3
    ↓ (uploads only selected templates)
Generate ChangeSets
    ↓ (shows what will change)
Review & Approval
    ↓ (manual approval if DRY_RUN=true OR prod)
Apply Updates
    ↓ (updates only if DRY_RUN=false)
Verification
    ↓ (checks stack status)
Post-Pipeline Summary
```

## Key Features

✅ **Selective Updates**: Update only the stacks you need
✅ **Dry Run Mode**: Preview changes with ChangeSets before applying
✅ **Safety Gates**: Production environments require manual approval
✅ **Change Documentation**: Audit trail with change descriptions
✅ **Template Validation**: Validates CloudFormation templates before deployment
✅ **Error Handling**: Fails fast if no stacks are selected
✅ **Change Visibility**: Shows exactly what will change via ChangeSets

## Important Notes

⚠️ **At least ONE stack must be selected** for the pipeline to run.

⚠️ **DRY_RUN is enabled by default** - Review the preview and re-run with `DRY_RUN=false` to actually apply changes.

⚠️ **Production environments require TWO approvals**:
   1. Pre-flight safety gate confirmation
   2. ChangeSet review approval

⚠️ **Order of updates**: If multiple stacks are selected, updates execute in this order:
   1. Core stack
   2. Base stack
   3. App stack

## Troubleshooting

**Q: Pipeline says "At least one stack must be selected"**
- A: Check at least one UPDATE_* checkbox before running

**Q: Changes are not being applied**
- A: Check if DRY_RUN is enabled (default is true). Set it to false to apply changes.

**Q: ChangeSet shows no changes**
- A: Templates may be identical to current stack. This is expected.

**Q: Pipeline fails during template validation**
- A: Check CloudFormation template syntax in `infrastructure/cloudformation/{stack-type}/`

**Q: Permission denied errors**
- A: Ensure Jenkins agent has AWS credentials and IAM permissions for CloudFormation

## Related Pipelines

| Pipeline | Purpose |
|----------|---------|
| **Jenkinsfile_main** | Main orchestrator - deploys full stack hierarchy |
| **Jenkinsfile_core** | Core stack only |
| **Jenkinsfile_base** | Base stack only |
| **Jenkinsfile_app** | App stack only |
| **Jenkinsfile_selective_update** | **UPDATE ONLY** - selected stacks ← YOU ARE HERE |

## Migration from Old Pipelines

If you're currently using individual stack pipelines for updates:

**Before** (3 separate pipeline runs):
```
Run Jenkinsfile_core with ACTION=UPDATE
Run Jenkinsfile_base with ACTION=UPDATE
Run Jenkinsfile_app with ACTION=UPDATE
```

**After** (1 selective update pipeline run):
```
Run Jenkinsfile_selective_update with:
- UPDATE_CORE ✓
- UPDATE_BASE ✓
- UPDATE_APP ✓
```

Benefits: Atomic updates, single approval workflow, better auditability.
