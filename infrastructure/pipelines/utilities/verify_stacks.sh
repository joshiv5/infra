#!/bin/bash

# Stack Verification Utility Script
# Verifies that all deployed stacks are in healthy state

set -e

# Parameters
PROJECT_NAME=$1
ENVIRONMENT=$2
AWS_REGION=${3:-us-east-1}

if [ -z "$PROJECT_NAME" ] || [ -z "$ENVIRONMENT" ]; then
    echo "Usage: $0 <project-name> <environment> [region]"
    exit 1
fi

echo "=========================================="
echo "Stack Verification"
echo "=========================================="
echo "Project: $PROJECT_NAME"
echo "Environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"
echo "=========================================="

# Array of stacks to verify
STACKS=(
    "${PROJECT_NAME}-core-stack-${ENVIRONMENT}"
    "${PROJECT_NAME}-base-stack-${ENVIRONMENT}"
    "${PROJECT_NAME}-app-stack-${ENVIRONMENT}"
    "${PROJECT_NAME}-main-stack-${ENVIRONMENT}"
)

echo ""
echo "Checking stack statuses..."
echo ""

FAILED=0

for STACK_NAME in "${STACKS[@]}"; do
    echo "Checking: $STACK_NAME"
    
    # Get stack status
    STATUS=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null || echo "DOES_NOT_EXIST")
    
    case $STATUS in
        CREATE_COMPLETE|UPDATE_COMPLETE|IMPORT_COMPLETE)
            echo "  ✓ Status: $STATUS"
            
            # Get outputs
            OUTPUTS=$(aws cloudformation describe-stacks \
                --stack-name "$STACK_NAME" \
                --region "$AWS_REGION" \
                --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
                --output table 2>/dev/null || echo "No outputs")
            
            echo "  Outputs:"
            echo "$OUTPUTS" | head -10
            ;;
            
        CREATE_IN_PROGRESS|UPDATE_IN_PROGRESS)
            echo "  ⏳ Status: $STATUS (Still in progress)"
            ;;
            
        ROLLBACK_COMPLETE|UPDATE_ROLLBACK_COMPLETE)
            echo "  ✗ Status: $STATUS (Failed/Rolled back)"
            
            # Get failure events
            echo "  Recent events:"
            aws cloudformation describe-stack-events \
                --stack-name "$STACK_NAME" \
                --region "$AWS_REGION" \
                --query 'StackEvents[0:5].[Timestamp,ResourceStatus,ResourceStatusReason]' \
                --output table 2>/dev/null || true
            
            FAILED=$((FAILED + 1))
            ;;
            
        DOES_NOT_EXIST)
            echo "  ⚠ Status: Stack does not exist"
            ;;
            
        *)
            echo "  ✗ Status: $STATUS (Unexpected state)"
            FAILED=$((FAILED + 1))
            ;;
    esac
    
    echo ""
done

echo "=========================================="
echo "Verification Summary"
echo "=========================================="

if [ $FAILED -eq 0 ]; then
    echo "✓ All stacks verified successfully"
    exit 0
else
    echo "✗ $FAILED stack(s) failed verification"
    exit 1
fi
