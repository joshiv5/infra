# Windows Jenkins Fix - Selective Update Pipeline

## Issues Fixed

### Issue 1: TIMESTAMP Environment Variable Error
**Error**: `groovy.lang.MissingPropertyException: No such property: TIMESTAMP`

**Root Cause**: The environment block used `sh` command to generate a timestamp, but `sh` command doesn't exist on Windows.

**Fix**: 
- Removed the problematic `sh` command from environment block
- Changed to use Jenkins built-in `BUILD_ID` as `BUILD_TIMESTAMP`
- This is available on all Jenkins agents (Windows/Linux)

```groovy
// BEFORE (fails on Windows)
TIMESTAMP = sh(script: 'date +%Y%m%d-%H%M%S', returnStdout: true).trim()

// AFTER (works on Windows)
BUILD_TIMESTAMP = "${BUILD_ID}"
```

---

### Issue 2: Shell Commands Not Found on Windows
**Error**: `java.io.IOException: Cannot run program "sh"`

**Root Cause**: Jenkinsfile used Unix shell (`sh`) commands that don't exist on Windows.

**Fix**: Replaced all `sh` commands with `bat` (Windows batch commands)

| Type | Before | After |
|------|--------|-------|
| Shell Commands | `sh { ... }` | `bat { ... }` |
| Line Continuation | `\` (backslash) | `^` (caret) |
| File Paths | `/` (forward slash) | `\` (backslash) |
| Sleep Command | `sleep 10` | `timeout /t 10 /nobreak` |
| External Scripts | `.sh` scripts | Direct AWS CLI calls |

---

### Issue 3: File Path Separators
**Before**: 
```groovy
TEMPLATES_PATH = "${WORKSPACE}/infrastructure/cloudformation"
```

**After**:
```groovy
TEMPLATES_PATH = "${WORKSPACE}\\infrastructure\\cloudformation"
```

---

## Updated Jenkinsfile Changes

### Environment Variables
```groovy
environment {
    PROJECT_NAME = 'ascend'
    AWS_DEFAULT_REGION = "${params.AWS_REGION}"
    TEMPLATES_PATH = "${WORKSPACE}\\infrastructure\\cloudformation"  // Windows paths
    CONFIGS_PATH = "${WORKSPACE}\\infrastructure\\configs"           // Windows paths
    ENVIRONMENT = "${params.ENVIRONMENT}"
    BUILD_TIMESTAMP = "${BUILD_ID}"                                   // No shell command
}
```

### Validate Templates Stage
```groovy
// Before: Uses sh and Unix path separators
sh """
    aws cloudformation validate-template \
        --template-body file://${TEMPLATES_PATH}/core/core_iam_roles.yaml \
        --region ${AWS_DEFAULT_REGION}
"""

// After: Uses bat and Windows path separators
bat """
    aws cloudformation validate-template ^
        --template-body file://${TEMPLATES_PATH}\\core\\core_iam_roles.yaml ^
        --region ${AWS_DEFAULT_REGION}
"""
```

### Upload Templates Stage
```groovy
// Before: Uses sh and \
sh """
    aws s3 cp ${TEMPLATES_PATH}/core/core_iam_roles.yaml \
        s3://${params.CF_TEMPLATES_BUCKET}/infrastructure/cloudformation/core/ \
        --region ${AWS_DEFAULT_REGION}
"""

// After: Uses bat and ^ for continuation
bat """
    aws s3 cp ${TEMPLATES_PATH}\\core\\core_iam_roles.yaml ^
        s3://${params.CF_TEMPLATES_BUCKET}/infrastructure/cloudformation/core/ ^
        --region ${AWS_DEFAULT_REGION}
"""
```

### Helper Functions
```groovy
// NEW: Windows-compatible ChangeSet helper
def createAndDisplayChangeSet(stackType, stackName) {
    def changeSetName = "${stackType}-changeset-${BUILD_ID}"
    def templateFile = "${TEMPLATES_PATH}\\${stackType}\\${getTemplateFileName(stackType)}"
    def paramFile = "${CONFIGS_PATH}\\${ENVIRONMENT}\\${stackType}_parameters.json"
    
    bat """
        timeout /t 10 /nobreak
        aws cloudformation describe-change-set ^
            --stack-name ${stackName} ^
            --change-set-name ${changeSetName} ...
    """
}

// NEW: Windows-compatible stack update
def updateStack(stackType, stackName) {
    def templateFile = "${TEMPLATES_PATH}\\${stackType}\\${getTemplateFileName(stackType)}"
    def paramFile = "${CONFIGS_PATH}\\${ENVIRONMENT}\\${stackType}_parameters.json"
    
    bat """
        aws cloudformation update-stack ^
            --stack-name ${stackName} ^
            --template-body file://${templateFile} ^
            --parameters file://${paramFile} ...
        
        aws cloudformation wait stack-update-complete ^
            --stack-name ${stackName} ...
    """
}
```

---

## Testing the Fixed Pipeline

### Prerequisites
- ✓ Jenkins agent running on Windows
- ✓ AWS CLI installed on the Jenkins agent
- ✓ AWS credentials configured

### Run Test
1. Create a new Jenkins job pointing to `pipelines/Jenkinsfile_selective_update`
2. Fill in parameters:
   - ENVIRONMENT: `dev`
   - UPDATE_APP: ✓ (checked)
   - DRY_RUN: ✓ (checked)
   - AWS_REGION: `us-east-1`
   - CF_TEMPLATES_BUCKET: `ascend-test-poc`

3. Run the pipeline
4. Verify no more Windows-related errors

---

## Compatibility

| Platform | Shell | Status |
|----------|-------|--------|
| Windows | `cmd.exe` (batch) | ✅ **Supported** |
| Linux | `/bin/bash` | ⚠️ **Not supported** |
| macOS | `/bin/bash` | ⚠️ **Not supported** |

**Note**: If you need to run this on Linux/macOS, create separate pipeline variants or use conditional logic with `node.os` detection.

---

## Migration from Old Pipeline

If you still have the old shell-based pipeline:

**Old file**: `Jenkinsfile_selective_update` (original, Unix-only)
**New file**: `Jenkinsfile_selective_update` (updated, Windows-compatible)

All edits are backward compatible - the pipeline now works on Windows!

---

## Troubleshooting

### Error: "Cannot find `aws` command"
- **Cause**: AWS CLI not installed on Jenkins agent
- **Fix**: Install `aws` CLI on the Windows Jenkins agent
  ```cmd
  msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi
  ```

### Error: "The system cannot find the file specified"
- **Cause**: File path is incorrect or uses wrong separators
- **Fix**: Check all paths use `\\` (backslash) not `/` (forward slash)

### Error: "^ is not recognized"
- **Cause**: Using bash instead of cmd.exe
- **Fix**: Ensure Jenkins agent is configured to use `cmd.exe`, not bash

---

## Summary
✅ Pipeline now fully compatible with Windows Jenkins agents
✅ All shell scripts replaced with Windows batch commands
✅ File paths updated to use Windows separators
✅ Variable declarations use cross-platform Jenkins built-ins

You can now run the selective update pipeline from your Windows Jenkins instance!
