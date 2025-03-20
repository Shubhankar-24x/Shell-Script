#!/bin/bash
echo "This is first Shell Script "

<< comment
hello this is multi line comment
comment
# Variables
name="Himanshu"

echo "My name is $name"

echo "My name is ${name}"

# Reading User Input
echo "Enter your name:"
read username
echo "You entered $username"

read -p "Enter username: " username
echo "You entered $username"

#Add User
sudo useradd -m $username
echo "User $username added successfully"

#Remove User
sudo userdel $username
echo "User $username removed successfully"

#Check User
id $username
echo "User $username exists"    

# Arguments

echo " The characters in $0 are:$1 "
