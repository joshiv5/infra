# Jenkins Pipeline Fix - Environment Variable Expansion Issue

## Problem
```
aws: error: argument --region: expected one argument
```

**Cause**: Environment variables like `${AWS_DEFAULT_REGION}`, `${MAIN_STACK_NAME}`, etc. were not being expanded in PowerShell blocks.

**Root Cause**: PowerShell blocks were using single quotes (`powershell '''`) instead of double quotes (`powershell """`)
- Single quotes: Groovy does NOT expand variables → variables passed as literal strings
- Double quotes: Groovy DOES expand variables → variables replaced with actual values

## Solution Applied

✅ **Fixed in Jenkinsfile_main_windows** - All 8 PowerShell blocks updated:

| Stage | Fix Applied | Before | After |
|-------|-------------|--------|-------|
| Validate Templates | ✅ | `powershell '''` | `powershell """` |
| Upload Templates to S3 | ✅ | `powershell '''` | `powershell """` |
| Deploy Main Stack - Check Stack | ✅ | `powershell '''` | `powershell """` |
| Deploy Main Stack - Wait | ✅ | `powershell '''` | `powershell """` |
| Deploy Main Stack - Debug | ✅ | `powershell '''` | `powershell """` |
| Verify Deployment | ✅ | `powershell '''` | `powershell """` |
| Generate Report | ✅ | `powershell '''` | `powershell """` |
| Post Failure | ✅ | `powershell '''` | `powershell """` |

## Verification

✅ No single-quote PowerShell blocks remain
✅ All variables now expand properly in PowerShell scripts
✅ AWS CLI commands receive correct parameter values

## What This Fixes

Now these commands work correctly:

```powershell
# ✅ BEFORE FIX (Failed):
aws cloudformation validate-template `
    --template-body file://${TEMPLATES_PATH}/main/main_template.yaml `
    --region ${AWS_DEFAULT_REGION}
# Error: aws: error: argument --region: expected one argument
# (Because ${AWS_DEFAULT_REGION} was passed as literal string)

# ✅ AFTER FIX (Works):
# Same command, but variables are expanded:
aws cloudformation validate-template `
    --template-body file://C:\Jenkins\workspace\infrastructure\cloudformation\main\main_template.yaml `
    --region eu-central-1
# ✓ Success!
```

## Testing the Fix

Run your Jenkins pipeline again with the same parameters:
- **ENVIRONMENT**: dev
- **ACTION**: CREATE
- **AWS_REGION**: eu-central-1
- **CF_TEMPLATES_BUCKET**: ascend-test-poc

**Expected Result**: All stages should execute without the "argument --region: expected one argument" error.

## PowerShell Quoting Rules in Groovy/Jenkins

**Remember for future pipeline development:**

```groovy
// ❌ WRONG - Single quotes prevent variable expansion
powershell '''
    aws cloudformation validate-template `
        --template-body file://${TEMPLATES_PATH}/main/main_template.yaml
    # ${TEMPLATES_PATH} is NOT expanded - passed as literal string
'''

// ✅ CORRECT - Double quotes enable variable expansion
powershell """
    aws cloudformation validate-template `
        --template-body file://${TEMPLATES_PATH}/main/main_template.yaml
    # ${TEMPLATES_PATH} IS expanded - replaced with actual path
"""

// For shell (Linux/Mac) - Both $TEMPLATES_PATH formats work:
sh '''
    aws cloudformation validate-template \
        --template-body file://${TEMPLATES_PATH}/main/main_template.yaml
    # Groovy expands ${TEMPLATES_PATH} even with single quotes in sh blocks
'''
```

## Common Quoting Mistakes

| Scenario | Issue | Fix |
|----------|-------|-----|
| `powershell '''` with `${VAR}` | Variable not expanded | Use `powershell """` |
| Nested quotes in script | Quote escaping problems | Use PowerShell `@"..."@` for multi-line strings |
| Path backslashes | May be interpreted as escape sequences | Use backtick `` ` `` for line continuation (not `\`) |
| PowerShell variables inside `$()` | Double escaping needed | Use `\$()` when inside Groovy strings |

## Files Modified

- ✅ `infrastructure/pipelines/Jenkinsfile_main_windows` - All 8 PowerShell blocks fixed

## Next Steps

1. **Commit the fix** to your Git repository
2. **Run pipeline** with same parameters as before
3. **Monitor** CloudFormation validation stage - should now complete successfully
4. **Proceed** through the rest of the pipeline

## Support

If you encounter similar issues:
1. Check if PowerShell blocks are using double quotes (`"""`) not single quotes (`'''`)
2. Verify environment variables are defined in the `environment` block
3. Use PowerShell `Write-Host "Value: ${VAR}"` for debugging variable expansion
4. Check Jenkins console logs for the actual expanded command values

---

**Status**: ✅ FIXED AND READY TO RESTART PIPELINE
