#!/bin/bash

############################################
# Author: Shubhankar Biswas
# Version: v0.0.2
# Date: 2025-03-20
# Description: Create and Delete VPC in AWS
############################################

# Verify if AWS CLI is installed
if ! [ -x "$(command -v aws)" ]; then
  echo 'Error: AWS CLI is not installed. Please install it first.' >&2
  exit 1
fi

# Verify if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
  echo 'Error: AWS CLI is not configured. Please configure it first using `aws configure`.' >&2
  exit 1
fi

# Ask for the default AWS region
read -p "Enter the AWS region to perform operations (e.g., us-east-1): " AWS_DEFAULT_REGION
export AWS_DEFAULT_REGION

# Function to delete all subnets in a VPC
delete_subnets() {
  vpc_id=$1
  subnet_ids=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query "Subnets[*].SubnetId" --output text)

  for subnet_id in $subnet_ids; do
    echo "Deleting subnet: $subnet_id"
    aws ec2 delete-subnet --subnet-id $subnet_id
  done
}

# Function to detach and delete internet gateway
delete_internet_gateway() {
  vpc_id=$1
  igw_id=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc_id" --query "InternetGateways[*].InternetGatewayId" --output text)

  if [ -n "$igw_id" ]; then
    echo "Detaching and deleting internet gateway: $igw_id"
    aws ec2 detach-internet-gateway --internet-gateway-id $igw_id --vpc-id $vpc_id
    aws ec2 delete-internet-gateway --internet-gateway-id $igw_id
  else
    echo "No internet gateway found attached to VPC: $vpc_id"
  fi
}

# Function to delete custom route tables
delete_route_tables() {
  vpc_id=$1
  route_tables=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc_id" --query "RouteTables[*].RouteTableId" --output text)

  for route_table in $route_tables; do
    association_id=$(aws ec2 describe-route-tables --route-table-id $route_table --query "RouteTables[0].Associations[0].AssociationId" --output text)

    if [ "$association_id" != "None" ]; then
      aws ec2 disassociate-route-table --association-id $association_id
      sleep 5
    fi

    echo "Deleting route table: $route_table"
    aws ec2 delete-route-table --route-table-id $route_table || echo "Failed to delete route table: $route_table. Check dependencies."
  done
}

# Function to delete security groups
delete_security_groups() {
  vpc_id=$1
  security_groups=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc_id" --query "SecurityGroups[*].[GroupId,GroupName]" --output text)

  while read -r sg_id sg_name; do
    if [[ "$sg_name" == "default" ]]; then
      echo "Skipping default security group: $sg_id"
      continue
    fi

    echo "Deleting security group: $sg_id"
    aws ec2 delete-security-group --group-id $sg_id || echo "Failed to delete security group: $sg_id"
  done <<< "$security_groups"
}

# Function to delete NAT gateways
delete_nat_gateways() {
  vpc_id=$1
  nat_gateways=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$vpc_id" --query "NatGateways[*].NatGatewayId" --output text)

  for nat_gateway in $nat_gateways; do
    echo "Deleting NAT gateway: $nat_gateway"
    aws ec2 delete-nat-gateway --nat-gateway-id $nat_gateway
  done
}

# Function to delete VPC
delete_vpc() {
  vpc_id=$1

  # Delete NAT gateways first (to avoid dependencies)
  delete_nat_gateways $vpc_id

  # Delete subnets
  delete_subnets $vpc_id

  # Detach and delete internet gateway
  delete_internet_gateway $vpc_id

  # Delete custom route tables
  delete_route_tables $vpc_id

  # Delete security groups
  delete_security_groups $vpc_id

  # Finally, delete the VPC
  echo "Deleting VPC: $vpc_id"
  aws ec2 delete-vpc --vpc-id $vpc_id

  # Check if the VPC deletion was successful
  if [ $? -eq 0 ]; then
    echo "VPC with ID $vpc_id deleted successfully"
  else
    echo "Error: VPC deletion failed."
  fi
}

# Main menu
while true; do
  echo "Please select an option:"
  echo "1. Create VPC"
  echo "2. Delete VPC"
  echo "3. List VPCs"
  echo "4. Exit"
  read -p "Enter your choice (1-4): " choice

  case $choice in
    1)
      # Create VPC
      read -p "Enter the VPC CIDR block (e.g., 10.0.0.0/16): " vpc_cidr_block
      read -p "Enter the VPC name: " vpc_name
      read -p "Enter the subnet CIDR block (e.g., 10.0.1.0/24): " subnet_cidr_block
      read -p "Enter the subnet name: " subnet_name

      # Create VPC
      vpc_output=$(aws ec2 create-vpc --cidr-block $vpc_cidr_block --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$vpc_name}]")
      vpc_id=$(echo $vpc_output | grep -o '"VpcId": "[^"]*' | awk -F '": "' '{print $2}')

      if [ -z "$vpc_id" ]; then
        echo "Error: VPC creation failed."
      else
        echo "VPC created successfully with ID: $vpc_id"

        # Create a public subnet
        subnet_output=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block $subnet_cidr_block --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$subnet_name}]")
        subnet_id=$(echo $subnet_output | grep -o '"SubnetId": "[^"]*' | awk -F '": "' '{print $2}')

        if [ -z "$subnet_id" ]; then
          echo "Error: Subnet creation failed."
        else
          echo "Subnet created successfully with ID: $subnet_id"
        fi
      fi
      ;;

    2)
      # Delete VPC
      read -p "Enter the VPC ID to delete: " vpc_id
      delete_vpc $vpc_id
      ;;

    3)
      # List all VPCs
      echo "Listing all VPCs..."
      aws ec2 describe-vpcs --output table
      ;;

    4)
      # Exit
      echo "Exiting. Goodbye!"
      exit 0
      ;;

    *)
      echo "Invalid choice. Please select a valid option (1-4)."
      ;;
  esac
done
