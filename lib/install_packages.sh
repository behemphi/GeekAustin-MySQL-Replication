#!/bin/bash
# *****************************************************************************
# Name:     install_packages.sh
# Purpose:  Install the list of packages specified in the parent scripts 
#           $PACKAGES array.
# TODOs:     
# Notes:    
# Change Log
# Date           Name           Description
# *****************************************************************************
# 02/09/2011     BEH            File Creation
# *****************************************************************************
# Install packages from the PACKAGES array
function install_packages
{
    ACTION="+++++ Install base packages for a generic slice +++++"
    echo "$ACTION"
    
    apt-get --assume-yes update
    
    for PKG in ${PACKAGES[@]}
    do
        echo "    +++++ Checking package: $PKG +++++"
        COUNT=$(dpkg -l | grep "$PKG " | wc -l )
        # Check to see if the package is installed if it is not, then install it.
        if [ $COUNT == "1" ]
        then
            echo "    +++++ [WARNING]:[PACKAGE INSTALL] $PKG already installed +++++"
        else
            echo "    +++++ Installing $PKG +++++"
            /usr/bin/apt-get --assume-yes install $PKG
        fi  
    done
}