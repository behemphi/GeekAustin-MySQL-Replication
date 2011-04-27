#!/bin/bash
# *****************************************************************************
# Name:     make_mysql_root_users.sh
# Purpose:  Create database users with root-like privileges from the 
#           MYSQL_ROOT_USERS and MYSQL_ROOT_PASSWORDS arrays contained in the calling s
#           script
# TODOs:     
# Notes:    
# Change Log
# Date           Name           Description
# *****************************************************************************
# 04/07/2011     BEH            File Creation
# *****************************************************************************
function make_mysql_users
{
    ACTION="+++++ Create mysql root level users ++++++"
    echo "$ACTION"
        
    CNT=${#MYSQL_ROOT_USERS[@]}

    for (( I=0; I<=$CNT-1; I++ ))
    do  
        USER=${MYSQL_ROOT_USERS[$I]} 
        PASSWORD=${MYSQL_ROOT_PASSWORDS[$I]}
        ACTION="    +++++ Create mysql root level user $USER +++++"
        echo $ACTION
        
        # Create mysql acocount
        # network access
        $MYSQL_HOME/bin/mysql -v -e "grant all on *.* to '$USER'@'10.%' identified by password '$PASSWORD' with grant option"
        # local access
        $MYSQL_HOME/bin/mysql -v -e "grant all on *.* to '$USER'@'localhost' identified by password '$PASSWORD' with grant option"
    done
}
