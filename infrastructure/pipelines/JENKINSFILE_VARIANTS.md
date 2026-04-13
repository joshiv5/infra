# Jenkinsfile Variants Guide

This directory contains multiple Jenkinsfile variants optimized for different deployment scenarios and operating systems.

## Jenkinsfile Overview

### Main Orchestrator Pipelines (Recommended)

#### **Jenkinsfile_main_windows** ⭐ **START HERE FOR WINDOWS**
- **Platform**: Windows Jenkins Agents
- **Shell**: PowerShell (Windows native)
- **Features**: 
  - Full nested stack orchestration (Core → Base → App)
  - Single point of deployment
  - Built-in error handling and rollback
  - Production approval gates
  - Comprehensive deployment reporting
- **Use When**: Jenkins is running on Windows servers or desktops
- **Script Path in Jenkins**: `infrastructure/pipelines/Jenkinsfile_main_windows`

```groovy
// Example: Deployment uses PowerShell for Windows compatibility
powershell '''
    aws cloudformation deploy `
        --template-file template.yaml `
        --stack-name my-stack `
        --region ${AWS_DEFAULT_REGION}
'''
```

#### **Jenkinsfile_main_linux** ⭐ **START HERE FOR LINUX/MAC**
- **Platform**: Linux/Mac Jenkins Agents
- **Shell**: Bash/Shell (Unix native)
- **Features**: Same as Windows version but using Bash shell syntax
- **Use When**: Jenkins is running on Linux or macOS systems
- **Script Path in Jenkins**: `infrastructure/pipelines/Jenkinsfile_main_linux`

#### **Jenkinsfile_main**
- **Status**: Legacy - maps to current environment
- **Recommendation**: Use version-specific files above (`_windows` or `_linux`)
- **Note**: Kept for backward compatibility

### Component-Level Pipelines (Advanced)

#### **Jenkinsfile_core**
- **Scope**: Core infrastructure only (IAM roles)
- **Use When**: Deploying or updating only the base IAM roles
- **Dependencies**: None (standalone deploy)

#### **Jenkinsfile_base**
- **Scope**: Base infrastructure only (S3 + KMS)
- **Use When**: Updating storage and encryption independently
- **Dependencies**: Requires Core stack outputs
- **Skip**: Use main orchestrator unless you need granular control

#### **Jenkinsfile_app**
- **Scope**: Application policies and roles
- **Use When**: Updating only application-level permissions
- **Dependencies**: Requires Core and Base stack outputs
- **Skip**: Use main orchestrator unless you need granular control

## Quick Start by Platform

### 🪟 Windows Environment
```
1. Create Jenkins Pipeline job
2. Configure Pipeline → Script Path: infrastructure/pipelines/Jenkinsfile_main_windows
3. Build with parameters:
   - ENVIRONMENT: dev
   - ACTION: CREATE
   - AWS_REGION: eu-central-1
4. Monitor in Blue Ocean console
```

### 🐧 Linux/Mac Environment
```
1. Create Jenkins Pipeline job
2. Configure Pipeline → Script Path: infrastructure/pipelines/Jenkinsfile_main_linux
3. Build with parameters:
   - ENVIRONMENT: dev
   - ACTION: CREATE
   - AWS_REGION: eu-central-1
4. Monitor in Blue Ocean console
```

## Key Differences Between Jenkinsfile_main_windows and Jenkinsfile_main_linux

| Feature | Windows | Linux/Mac |
|---------|---------|----------|
| **Shell Engine** | PowerShell | Bash |
| **Command Prefix** | `powershell ```...```""` | `sh """..."""` |
| **Line Continuation** | Backtick `` ` `` | Backslash `\` |
| **Path Style** | `\` or `/` (both work) | `/` only |
| **Output Redirection** | `\| Out-Null` | `> /dev/null` |
| **Variable Syntax** | `${VAR}` in string | `$${VAR}` or `${VAR}` |
| **S3 Copy** | `aws s3 cp` with backticks | `aws s3 cp` with backslashes |
| **Stack Operations** | `-and`, `-or`, `-not` | Double brackets `[[`, `||`, `!` |

### Example Command Syntax Comparison

#### Upload Templates to S3

**Windows PowerShell:**
```groovy
powershell '''
    aws s3 cp "${TEMPLATES_PATH}/core/core_iam_roles.yaml" `
        "s3://${CF_TEMPLATES_BUCKET}/infrastructure/cloudformation/core/core_iam_roles.yaml" `
        --region ${AWS_DEFAULT_REGION}
'''
```

**Linux Bash:**
```groovy
sh '''
    aws s3 cp "${TEMPLATES_PATH}/core/core_iam_roles.yaml" \
        "s3://${CF_TEMPLATES_BUCKET}/infrastructure/cloudformation/core/core_iam_roles.yaml" \
        --region ${AWS_DEFAULT_REGION}
'''
```

#### Stack Existence Check

**Windows PowerShell:**
```groovy
powershell '''
    $stackExists = $false
    try {
        aws cloudformation describe-stacks `
            --stack-name ${MAIN_STACK_NAME} `
            --region ${AWS_DEFAULT_REGION} 2>$null | Out-Null
        $stackExists = $true
    } catch {
        $stackExists = $false
    }
    
    if ($stackExists -and "${ACTION}" -eq "UPDATE") {
        # Update stack...
    }
'''
```

**Linux Bash:**
```groovy
sh '''
    if aws cloudformation describe-stacks \
        --stack-name ${MAIN_STACK_NAME} \
        --region ${AWS_DEFAULT_REGION} 2>/dev/null; then
        # Stack exists - update logic
        aws cloudformation update-stack ...
    else
        # Stack doesn't exist - create logic
        aws cloudformation create-stack ...
    fi
'''
```

## Troubleshooting

### Windows Jenkinsfile Issues

#### Error: "Cannot run program 'sh'"
- **Cause**: Jenkinsfile is trying to use Unix shell on Windows
- **Solution**: Switch to `Jenkinsfile_main_windows` in Jenkins configuration
- **Verification**:
  ```powershell
  # On Jenkins agent, verify PowerShell works
  powershell -Command "Get-Host"
  ```

#### Error: "The term 'aws' is not recognized"
- **Cause**: AWS CLI not installed or not in PATH
- **Solution**: Install AWS CLI v2 for Windows and add to PATH
- **Verification**:
  ```powershell
  # Verify AWS CLI
  aws --version
  ```

#### Error: "ExecutionPolicy"
- **Cause**: PowerShell execution policy prevents script execution
- **Solution**: Set execution policy (as Administrator):
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
  ```

### Linux/Mac Jenkinsfile Issues

#### Error: "Cannot run program 'aws'"
- **Cause**: AWS CLI not installed on agent
- **Solution**: Install AWS CLI v2
  ```bash
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install
  ```

## Migration Guide

### From Individual Pipelines to Main Orchestrator

If you were using `Jenkinsfile_core`, `Jenkinsfile_base`, and `Jenkinsfile_app` separately:

1. **Migrate to main orchestrator** for simpler management:
   - Use `Jenkinsfile_main_windows` (Windows) or `Jenkinsfile_main_linux` (Linux/Mac)
   - Single job replaces 3 separate jobs
   - Automatic dependency sequencing
   - Built-in validation gates

2. **Steps**:
   - Create new pipeline job
   - Point to appropriate main Jenkinsfile
   - Configure parameters once
   - Delete old component jobs (optional, keep as backups)

### From Jenkinsfile_main to Version-Specific File

If your Jenkins is running on Windows:

1. Backup your current job configuration
2. Update **Script Path** from `infrastructure/pipelines/Jenkinsfile_main` to `infrastructure/pipelines/Jenkinsfile_main_windows`
3. Test with DEV environment
4. Verify in AWS console

## Best Practices

### ✅ Use Main Orchestrator Pipelines
- Simplifies deployment process
- Single point of control
- Automatic dependency handling
- Better error reporting

### ✅ Use Platform-Specific Jenkinsfile
- Windows agents → `Jenkinsfile_main_windows`
- Linux/Mac agents → `Jenkinsfile_main_linux`

### ✅ Production Deployments
- Always use DEV/TEST first
- Enable production approval gates (built-in)
- Review deployment report after each phase
- Keep backups of working configurations

### ❌ Avoid
- Manually editing Jenkinsfile_main for platform differences
- Running Linux Jenkinsfile on Windows or vice versa
- Skipping template validation
- Deploying directly to PROD without testing

## Support

For issues or questions:
1. Check [JENKINS_QUICK_START.md](JENKINS_QUICK_START.md) for setup guide
2. Review [../../TROUBLESHOOTING.md](../../TROUBLESHOOTING.md) for common issues
3. Check Jenkins Console Output for detailed error messages
4. Verify AWS CLI and credentials: `aws sts get-caller-identity`

## Additional Resources

- [Jenkins Pipeline Documentation](https://jenkins.io/doc/book/pipeline/)
- [AWS CloudFormation User Guide](https://docs.aws.amazon.com/cloudformation/latest/userguide/)
- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)
- [Bash Manual](https://www.gnu.org/software/bash/manual/)
