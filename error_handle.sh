#!/bin/bash

create_directory(){
    mkdir demo
}

# Handling the error
if ! create_directory; then
    echo "The directory could not be created as it already exists"
    exit 1
fi

echo "The directory was created successfully"
