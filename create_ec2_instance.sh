#!/bin/bash

# Exit on any error
set -e

# Function to print error message and exit
error_exit() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR: $1"
    exit 1
}

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null
then
    echo "$(date '+%Y-%m-%d %H:%M:%S') AWS CLI not found. Installing..."
    sudo apt update && sudo apt install awscli -y || error_exit "AWS CLI installation failed."
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') AWS CLI is already installed."
fi

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    error_exit "AWS CLI is not configured. Run 'aws configure' before executing this script."
fi

# User input with defaults
read -p "Enter AMI ID (default: ami-0abcdef1234567890): " AMI_ID
AMI_ID=${AMI_ID:-ami-0abcdef1234567890}

read -p "Enter instance type (default: t2.micro): " INSTANCE_TYPE
INSTANCE_TYPE=${INSTANCE_TYPE:-t2.micro}

read -p "Enter key pair name (default: my-key): " KEY_NAME
KEY_NAME=${KEY_NAME:-my-key}

read -p "Enter security group name (default: my-security-group): " SECURITY_GROUP
SECURITY_GROUP=${SECURITY_GROUP:-my-security-group}

read -p "Enter VPC name (default: my-vpc): " VPC_NAME
VPC_NAME=${VPC_NAME:-my-vpc}

read -p "Enter subnet CIDR (default: 10.0.1.0/24): " SUBNET_CIDR
SUBNET_CIDR=${SUBNET_CIDR:-10.0.1.0/24}

# Check if VPC exists, otherwise create it
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$VPC_NAME" --query "Vpcs[0].VpcId" --output text 2>/dev/null)

if [ "$VPC_ID" == "None" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') VPC not found. Creating..."
    VPC_ID=$(aws ec2 create-vpc --cidr-block "10.0.0.0/16" --query "Vpc.VpcId" --output text)
    aws ec2 create-tags --resources "$VPC_ID" --tags Key=Name,Value="$VPC_NAME"
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') Using VPC: $VPC_ID"

# Check if subnet exists, otherwise create it
SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=cidr-block,Values=$SUBNET_CIDR" --query "Subnets[0].SubnetId" --output text 2>/dev/null)

if [ "$SUBNET_ID" == "None" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') Subnet not found. Creating..."
    SUBNET_ID=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$SUBNET_CIDR" --query "Subnet.SubnetId" --output text)
    aws ec2 create-tags --resources "$SUBNET_ID" --tags Key=Name,Value="my-subnet"
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') Using Subnet: $SUBNET_ID"

# Check if key pair exists, otherwise create it
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" &> /dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') Key pair not found. Creating..."
    aws ec2 create-key-pair --key-name "$KEY_NAME" --query 'KeyMaterial' --output text > "${KEY_NAME}.pem"
    chmod 400 "${KEY_NAME}.pem"
fi

# Check if security group exists, otherwise create it
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$SECURITY_GROUP" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

if [ "$SECURITY_GROUP_ID" == "None" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') Security group not found. Creating..."
    SECURITY_GROUP_ID=$(aws ec2 create-security-group --group-name "$SECURITY_GROUP" --description "Auto-created security group" --vpc-id "$VPC_ID" --query "GroupId" --output text)
    aws ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') Using Security Group: $SECURITY_GROUP_ID"

# Check if an instance with the same AMI is already running
EXISTING_INSTANCE=$(aws ec2 describe-instances \
    --filters "Name=image-id,Values=$AMI_ID" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].InstanceId" --output text)

if [ -n "$EXISTING_INSTANCE" ]; then
    error_exit "An instance with the same AMI ($AMI_ID) is already running: $EXISTING_INSTANCE"
fi

# Create EC2 instance with VPC & Subnet
echo "$(date '+%Y-%m-%d %H:%M:%S') Creating EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SECURITY_GROUP_ID" \
    --subnet-id "$SUBNET_ID" \
    --query 'Instances[0].InstanceId' \
    --output text) || error_exit "Failed to create EC2 instance."

echo "$(date '+%Y-%m-%d %H:%M:%S') EC2 Instance ID: $INSTANCE_ID"

# Wait for instance to be in "running" state
echo "$(date '+%Y-%m-%d %H:%M:%S') Waiting for instance to start..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" || error_exit "Instance failed to reach running state."

echo "$(date '+%Y-%m-%d %H:%M:%S') Instance $INSTANCE_ID is running. Successfully created!"
exit 0
