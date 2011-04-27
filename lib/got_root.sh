#!/bin/bash
# *****************************************************************************
# Name:     got_root.sh
# Purpose:  Define a function to test if a user is root
# TODOs:     
# Notes:    The function "usage" must be called in the parent script
# Change Log
# Date           Name           Description
# *****************************************************************************
# 02/09/2011     BEH            File Creation
# *****************************************************************************
function got_root
{
    CUR_USER=$(whoami)
    if [[ "$CUR_USER" != "root" ]]
    then
        usage
        exit 1
    fi    
}
