#!/bin/bash

# Stack Deployment Utility Script
# Handles CloudFormation stack creation, update, and deletion

set -e

# Parameters
STACK_NAME=$1
TEMPLATE_PATH=$2
PARAM_FILE=$3
ACTION=$4
AWS_REGION=${5:-us-east-1}

# Validation
if [ -z "$STACK_NAME" ] || [ -z "$TEMPLATE_PATH" ] || [ -z "$PARAM_FILE" ] || [ -z "$ACTION" ]; then
    echo "Usage: $0 <stack-name> <template-path> <param-file> <action> [region]"
    echo "Action: CREATE | UPDATE | DELETE"
    exit 1
fi

echo "=========================================="
echo "Stack Deployment Utility"
echo "=========================================="
echo "Stack Name: $STACK_NAME"
echo "Template: $TEMPLATE_PATH"
echo "Parameters: $PARAM_FILE"
echo "Action: $ACTION"
echo "Region: $AWS_REGION"
echo "=========================================="

# Function to check if stack exists
stack_exists() {
    aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        &>/dev/null
    return $?
}

# Function to wait for stack operation
wait_for_stack() {
    local operation=$1
    echo "Waiting for ${operation} operation to complete..."
    
    aws cloudformation wait "stack-${operation}-complete" \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --max-attempts 120
    
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo "✓ Stack ${operation} completed successfully"
    else
        echo "✗ Stack ${operation} failed or timed out"
        
        # Get stack events for debugging
        echo "Recent stack events:"
        aws cloudformation describe-stack-events \
            --stack-name "$STACK_NAME" \
            --region "$AWS_REGION" \
            --query 'StackEvents[0:10].[Timestamp,ResourceStatus,ResourceStatusReason]' \
            --output table || true
        
        return $exit_code
    fi
}

# Main operation logic
case $ACTION in
    CREATE)
        echo "Creating stack: $STACK_NAME"
        
        if stack_exists; then
            echo "⚠ Stack already exists. Skipping creation."
            exit 0
        fi
        
        aws cloudformation create-stack \
            --stack-name "$STACK_NAME" \
            --template-body "file://$TEMPLATE_PATH" \
            --parameters "file://$PARAM_FILE" \
            --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
            --region "$AWS_REGION" \
            --tags "Environment=Infrastructure" "ManagedBy=Jenkins"
        
        wait_for_stack "create"
        ;;
        
    UPDATE)
        echo "Updating stack: $STACK_NAME"
        
        if ! stack_exists; then
            echo "⚠ Stack does not exist. Creating instead..."
            ACTION="CREATE"
            
            aws cloudformation create-stack \
                --stack-name "$STACK_NAME" \
                --template-body "file://$TEMPLATE_PATH" \
                --parameters "file://$PARAM_FILE" \
                --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
                --region "$AWS_REGION" \
                --tags "Environment=Infrastructure" "ManagedBy=Jenkins"
            
            wait_for_stack "create"
        else
            # Attempt update
            UPDATE_OUTPUT=$(aws cloudformation update-stack \
                --stack-name "$STACK_NAME" \
                --template-body "file://$TEMPLATE_PATH" \
                --parameters "file://$PARAM_FILE" \
                --capabilities CAPABILITY_NAMED_IAM \
                --region "$AWS_REGION" \
                2>&1 || true)
            
            if echo "$UPDATE_OUTPUT" | grep -q "No updates are to be performed"; then
                echo "ℹ No updates needed for stack: $STACK_NAME"
            else
                wait_for_stack "update"
            fi
        fi
        ;;
        
    DELETE)
        echo "Deleting stack: $STACK_NAME"
        
        if ! stack_exists; then
            echo "⚠ Stack does not exist. Nothing to delete."
            exit 0
        fi
        
        # Confirm deletion
        read -p "Are you sure you want to delete $STACK_NAME? (yes/no): " -r REPLY
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            echo "Deletion cancelled."
            exit 0
        fi
        
        aws cloudformation delete-stack \
            --stack-name "$STACK_NAME" \
            --region "$AWS_REGION"
        
        wait_for_stack "delete"
        ;;
        
    *)
        echo "ERROR: Invalid action: $ACTION"
        echo "Valid actions: CREATE | UPDATE | DELETE"
        exit 1
        ;;
esac

echo "✓ Stack operation completed: $ACTION"
