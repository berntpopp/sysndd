#!/bin/bash
# script to download configuration files for the SysNDD Docker containers and
# compose the installation using docker-compose
# Written by: Bernt Popp
# Last updated on: 2022-05-10
## example usage: `bash deployment.sh config_archive_link`
# -------------------------------------------------------

# Set vars
config_archive_link=$1			# first command line argument: downloadable web adress with the config archive

display_usage() { 
    echo "A shell script to download configuration files for the SysNDD Docker containers and compose the installation using docker-compose."
    echo -e "\nusage:\nsh bash deployment.sh config_archive_link"
}

run_script() {

    # check if docker is running and
    # if the GitHub folder exists
    # if so change into that dir and compose down
    # change folder back and remove sysndd fodler
    if docker info > /dev/null 2>&1 && ls "sysndd/" > /dev/null 2>&1; then
        cd sysndd/
        docker-compose down
        cd ..
        rm -rf sysndd/
    fi

    # download link
    wget --no-check-certificate "$config_archive_link" -O config.tar.gz

    # extract archive and delete it afterwards
    tar -xvzf config.tar.gz
    rm config.tar.gz

    # download the current repo from GitHub
    git clone https://github.com/berntpopp/sysndd.git

    # copy config files to GitHub folder structure
    cp ./config/copy_files.sh ./
    bash ./copy_files.sh
    rm copy_files.sh

    # cd to sysndd GitHub folder and start the docker compose script
    cd sysndd/
    bash ./docker-compose.sh

}

# if no arguments supplied, display usage 
    if [  $# -eq 0 ] 
    then
        display_usage
        exit 1
    else
        run_script
    fi