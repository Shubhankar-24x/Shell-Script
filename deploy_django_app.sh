#!/bin/bash

<< comment
Deploy a Django app and 
handle the code for errors
comment

# Code Clone

code_clone(){
    echo "Cloning the Django app"
    git clone https://github.com/Shubhankar-24x/django-notes-app.git

}

# Installing Requirements

install_requirements(){
    echo "Installing Dependencies"
    sudo apt-get install docker.io nginx -y docker-compose
}

# Required Restarts

required_restarts(){
    echo "Restarting Services"
    # Giving permission to docker
    sudo chown $USER /var/run/docker.sock

    sudo systemctl enable docker
    sudo systemctl restart docker

    sudo systemctl enable nginx
    sudo systemctl start nginx
}

# Deploying Django App

deploy_django_app(){
    echo "Deploying Django App"
    docker build -t django-notes-app .
    # docker run -d -p 8000:8000 django-notes-app:latest
    docker-compose up -d    # Run with Docker Compose
}

echo " ********** Deployment Started **********"
# Calling the functions with handling the errors

if ! code_clone;then
    echo "The code directory already exists"
    cd django-notes-app
fi

if ! install_requirements;then
    echo "The requirements could not be installed"
    exit 1
fi

if ! required_restarts;then
    echo " System Fault Identified"
    exit 1
fi

if ! deploy_django_app;then
    echo " Deployment Failed"
    # sendmail
    exit 1
fi

echo " ********** Deployment Completed **********"