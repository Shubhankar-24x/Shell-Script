#!/bin/bash

<< disclaimer
This is just a disclaimer
disclaimer

# If-Else Conditions
read -p " Enter a name: " name
read -p " are you geneuine? Put yes%: " answer
if [[$name=="Kai"]];
then
    echo "Your name is $name"
elif [[$answer -ge 100]];
then
    echo " Your are Genuine!!!!!"
else
    echo "Your name is not $name"
fi

# Loops
# 1st example
for ((i=1;i<=5;i++));                                                             
do
    mkdir demo_file 
    mkdir "demo_file_$i"  # To create a folder named demo_file_1,demo_file_2,demo_file_3,demo_file_4,demo_file_5

done       

# 2nd example
<< comment
1 is argument 1 which is folder name
2 is start range
3 is end range
comment

for ((num=$2 ; num<=$3 ; num++)) #helps to create multiple folders through arguments
do
    mkdir "$1$num"
done

# While Loop

# 1st example
num =0
while [[$num -le 5]];
do
    echo"$num"
    num=$((num+1))
done

# 2nd example 
num =0
while [[ $((num%2))==0 && $num -le 10]]
do 
    echo "$num"
    num=$((num+1))
done
