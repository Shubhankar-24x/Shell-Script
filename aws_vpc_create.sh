#!/bin/bash

############################################
# Author: Shubhankar Biswas
# Version: v0.0.1
# Date: 2025-03-20
# Description: Create and Delete VPC in AWS
############################################

# Verify if the user has AWS CLI installed (Linux, Windows, or Mac)
if ! [ -x "$(command -v aws)" ]; then
  echo 'Error: AWS CLI is not installed. Please install it first.' >&2
  exit 1
fi

# Verify if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
  echo 'Error: AWS CLI is not configured. Please configure it first using `aws configure`.' >&2
  exit 1
fi

# Function to disassociate and delete route tables
delete_route_tables() {
  vpc_id=$1
  route_tables=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc_id" --query "RouteTables[*].RouteTableId" --output text)

  for route_table in $route_tables; do
    # Disassociate the route table from subnets (if any association exists)
    aws ec2 disassociate-route-table --association-id $(aws ec2 describe-route-tables --route-table-id $route_table --query "RouteTables[0].Associations[0].AssociationId" --output text)

    # Wait for the disassociation to be processed
    sleep 5

    # Now delete the route table
    echo "Deleting route table: $route_table"
    aws ec2 delete-route-table --route-table-id $route_table
  done
}

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

# Function to delete security groups
delete_security_groups() {
  vpc_id=$1
  security_groups=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc_id" --query "SecurityGroups[*].GroupId" --output text)

  for sg_id in $security_groups; do
    # Skip the default security group (it cannot be deleted)
    if [ "$sg_id" != "sg-00000000" ]; then
      echo "Deleting security group: $sg_id"
      aws ec2 delete-security-group --group-id $sg_id
    else
      echo "Cannot delete the default security group: $sg_id"
    fi
  done
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

  # Delete subnets
  delete_subnets $vpc_id

  # Detach and delete internet gateway
  delete_internet_gateway $vpc_id

  # Delete custom route tables
  delete_route_tables $vpc_id

  # Delete security groups
  delete_security_groups $vpc_id

  # Delete NAT gateways
  delete_nat_gateways $vpc_id

  # Now delete the VPC
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
  # Show user the options to create, delete, or list the VPC
  echo "Please select the option to create, delete, or list the VPC:"
  echo "1. Create VPC"
  echo "2. Delete VPC"
  echo "3. List VPC"
  echo "4. Exit"
  read -p "Enter your choice (1-4): " choice

  case $choice in
    1)
      # Option to create a VPC
      read -p "Enter the VPC CIDR block (e.g., 10.0.0.0/16): " vpc_cidr_block
      read -p "Enter the VPC name: " vpc_name
      read -p "Enter the region (e.g., us-east-1): " region
      read -p "Enter the subnet CIDR block (e.g., 10.0.1.0/24): " subnet_cidr_block
      read -p "Enter the subnet name: " subnet_name

      # Create the VPC
      vpc_output=$(aws ec2 create-vpc --cidr-block $vpc_cidr_block --region $region --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$vpc_name}]")
      
      # Extract VPC ID using grep and awk (no jq)
      vpc_id=$(echo $vpc_output | grep -o '"VpcId": "[^"]*' | awk -F '": "' '{print $2}')

      # Check if VPC creation was successful
      if [ -z "$vpc_id" ]; then
        echo "Error: VPC creation failed. Output: $vpc_output"
      else
        echo "VPC created successfully with ID: $vpc_id"

        # Create a public subnet
        subnet_output=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block $subnet_cidr_block --availability-zone $region --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$subnet_name}]")
        
        # Extract Subnet ID using grep and awk
        subnet_id=$(echo $subnet_output | grep -o '"SubnetId": "[^"]*' | awk -F '": "' '{print $2}')

        # Check if subnet creation was successful
        if [ -z "$subnet_id" ]; then
          echo "Error: Subnet creation failed. Output: $subnet_output"
        else
          echo "Public Subnet created successfully with ID: $subnet_id"
        fi
      fi
      ;;

    2)
      # Option to delete a VPC
      read -p "Enter the VPC ID to delete: " vpc_id

      # Call the delete VPC function
      delete_vpc $vpc_id
      ;;

    3)
      # Option to list all VPCs
      echo "Listing all VPCs..."
      aws ec2 describe-vpcs --output table
      ;;

    4)
      # Exit the script
      echo "Exiting the script. Goodbye!"
      exit 0
      ;;

    *)
      echo "Invalid choice. Please select a valid option (1-4)."
      ;;
  esac
done
