#!/bin/bash

# Clean Workspace Utility Script
# Performs post-deployment cleanup and generates reports

set -e

# Parameters
PROJECT_NAME=$1
ENVIRONMENT=$2
AWS_REGION=${3:-us-east-1}
REPORT_DIR=${4:-.}

if [ -z "$PROJECT_NAME" ] || [ -z "$ENVIRONMENT" ]; then
    echo "Usage: $0 <project-name> <environment> [region] [report-dir]"
    exit 1
fi

echo "=========================================="
echo "Cleanup and Reporting"
echo "=========================================="

# Create report file
REPORT_FILE="$REPORT_DIR/deployment_report_${ENVIRONMENT}_$(date +%Y%m%d_%H%M%S).txt"

{
    echo "Infrastructure Deployment Report"
    echo "=================================="
    echo "Project: $PROJECT_NAME"
    echo "Environment: $ENVIRONMENT"
    echo "Region: $AWS_REGION"
    echo "Generated: $(date)"
    echo ""
    
    echo "Stack Information"
    echo "================="
    
    STACKS=(
        "${PROJECT_NAME}-core-stack-${ENVIRONMENT}"
        "${PROJECT_NAME}-base-stack-${ENVIRONMENT}"
        "${PROJECT_NAME}-app-stack-${ENVIRONMENT}"
        "${PROJECT_NAME}-main-stack-${ENVIRONMENT}"
    )
    
    for STACK_NAME in "${STACKS[@]}"; do
        echo ""
        echo "Stack: $STACK_NAME"
        
        aws cloudformation describe-stacks \
            --stack-name "$STACK_NAME" \
            --region "$AWS_REGION" \
            --query 'Stacks[0].[StackName,StackStatus,CreationTime,LastUpdatedTime]' \
            --output table 2>/dev/null || echo "Stack not found"
        
        echo ""
        echo "Resources:"
        aws cloudformation list-stack-resources \
            --stack-name "$STACK_NAME" \
            --region "$AWS_REGION" \
            --query 'StackResourceSummaries[*].[LogicalResourceId,ResourceType,ResourceStatus]' \
            --output table 2>/dev/null || echo "No resources found"
        
        echo ""
        echo "Outputs:"
        aws cloudformation describe-stacks \
            --stack-name "$STACK_NAME" \
            --region "$AWS_REGION" \
            --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
            --output table 2>/dev/null || echo "No outputs found"
    done
    
    echo ""
    echo "Resources Summary"
    echo "================="
    
    echo ""
    echo "S3 Buckets:"
    aws s3 ls --region "$AWS_REGION" | grep "${PROJECT_NAME}-${ENVIRONMENT}" || echo "No buckets found"
    
    echo ""
    echo "KMS Keys:"
    aws kms list-keys --region "$AWS_REGION" \
        --query "Keys[*].KeyId" --output text | while read -r key; do
        ALIAS=$(aws kms describe-key --key-id "$key" --region "$AWS_REGION" \
            --query "KeyMetadata.Description" --output text 2>/dev/null || echo "")
        if [[ "$ALIAS" == *"${ENVIRONMENT}"* ]]; then
            echo "  - $key: $ALIAS"
        fi
    done || echo "No KMS keys found"
    
    echo ""
    echo "IAM Roles:"
    aws iam list-roles \
        --query "Roles[?contains(RoleName, '${PROJECT_NAME}') && contains(RoleName, '${ENVIRONMENT}')].[RoleName,Arn]" \
        --output table || echo "No roles found"
    
} | tee "$REPORT_FILE"

echo ""
echo "✓ Report generated: $REPORT_FILE"
