#!/bin/bash

<< readme

This is a Script for backup with 5 day rotation

Usage: 
./backup.sh <path to your source> <path to backup folder>
readme

function display_usage{

    echo " Usage: ./backup.sh <path to your source> <path to backup folder>"
}


if [$# -eq 0];then
    display_usage
fi

# Variables Defining

source_dir=$1
backup_dir=$2
timestamp =$(date '+%Y-%m-%d-%H-%M-%S')

function create_backup{

    zip -r "${backup_dir}/backup_${timestamp}.zip" "${source_dir}" > /dev/null  # Redirect the output to /dev/null

    if [ $? -eq 0 ];then
    echo " backup generated successfully for ${timestamp}"
    fi
}

# Function perform Rotation
function perform_rotation{
    backups =($(ls -t "${backup_dir}/backup_"*.zip )) 2>/dev/null # Redirect the standard error to /dev/null
   # echo "${backups[@]}" # List all backups with @

    if [ "${#backups[@]}" -gt 5 ];then
        echo " Performing Rotation for 5 days"

        backups_to_remove =("${backups[@]:5}") # Remove the first 5 backups
        #echo "${backups_to_remove[@]}" # List the 5 oldest backups to be removed

        for backup in "${backups_to_remove[@]}";
        do
            echo " Removing ${backup}"
            rm -f "${backup}"
        done
    fi
}     
  

#Calling the function
create_backup
perform_rotation