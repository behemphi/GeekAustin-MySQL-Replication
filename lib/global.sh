#!/bin/bash
# *****************************************************************************
# Name:     global.sh
# Purpose:  Define common global variables
# TODOs:     
# Notes:    
# Change Log
# Date           Name           Description
# *****************************************************************************
# 02/09/2011     BEH            File Creation
# *****************************************************************************
# Determine the base name of the current script.
SCRIPT_NAME=$(basename $0)

# Determine the name of the execution host.
HOST=$(hostname)

# Determine the ip address of the host
IP=$(hostname -i)

# Determine amount of memory on the host for configuration purposes.
# Note that memory is measured in megabytes
MEMORY=$(free -m | grep Mem: | awk '{print $2}')

# Determine amount of disk space on the host for configuraiton purposes
# Note that drive space is measured in gigabytes
HARDDRIVE=$(df --block-size=G | grep /dev/sda1 | awk '{print $2}' | cut -d'G' -f 1)

# Name the file for all output of this script
LOG_FILE="$SCRIPT_NAME.log"

# If no options are supplied, display the usage and exit.
# This test cannot be done in the getopts while/case
# below because if no options are supplied, then the while
# loop is not executed.
if [[ $# -eq 0 ]]
then
   usage
   exit 1
fi