#!/bin/bash

# Rollback Utility Script
# Rolls back failed stack deployments

set -e

# Parameters
STACK_NAME=$1
AWS_REGION=${2:-us-east-1}

if [ -z "$STACK_NAME" ]; then
    echo "Usage: $0 <stack-name> [region]"
    exit 1
fi

echo "=========================================="
echo "Stack Rollback Utility"
echo "=========================================="
echo "Stack Name: $STACK_NAME"
echo "Region: $AWS_REGION"
echo "=========================================="

# Get stack status
STATUS=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" \
    --query 'Stacks[0].StackStatus' \
    --output text 2>/dev/null || echo "DOES_NOT_EXIST")

echo "Current Status: $STATUS"

case $STATUS in
    UPDATE_ROLLBACK_COMPLETE)
        echo "Stack is already in rolled back state."
        exit 0
        ;;
        
    UPDATE_FAILED)
        echo "Continuing update rollback..."
        
        aws cloudformation continue-update-rollback \
            --stack-name "$STACK_NAME" \
            --region "$AWS_REGION"
        
        echo "Waiting for rollback to complete..."
        aws cloudformation wait stack-update-complete \
            --stack-name "$STACK_NAME" \
            --region "$AWS_REGION"
        
        echo "✓ Rollback completed"
        ;;
        
    ROLLBACK_IN_PROGRESS)
        echo "Rollback already in progress. Waiting..."
        
        aws cloudformation wait stack-create-complete \
            --stack-name "$STACK_NAME" \
            --region "$AWS_REGION"
        
        echo "✓ Rollback completed"
        ;;
        
    *)
        echo "⚠ Stack cannot be rolled back from state: $STATUS"
        exit 1
        ;;
esac

# Display final status
echo ""
echo "Final stack status:"
aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" \
    --query 'Stacks[0].[StackName,StackStatus,CreationTime]' \
    --output table
