#!/bin/bash
# *****************************************************************************
# Name:     make_users.sh
# Purpose:  Create shell users from the USERS and PASSWORDS array contained in 
#           the calling script. 
# TODOs:     
# Notes:    
# Change Log
# Date           Name           Description
# *****************************************************************************
# 03/08/2011     BEH            File Creation
# *****************************************************************************
function make_users
{
    ACTION="+++++ Create bash users ++++++"
    echo "$ACTION"
                
    CNT=${#USERS[@]}

    for (( I=0; I<=$CNT-1; I++ ))
    do  
        USER=${USERS[$I]} 
        PASSWORD=${PASSWORDS[$I]}
        ACTION="    +++++ Create user $USER +++++"
        echo $ACTION            
        /usr/sbin/useradd --home=/home/$USER --password=$PASSWORD --shell=/bin/bash --user-group --create-home $USER
    done
}
