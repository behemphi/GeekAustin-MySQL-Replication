#!/bin/bash
# *****************************************************************************
# Name:      install_mysql.sh
# Purpose:   This script installs and configures the mysql database server in 
#            MOCA fashion (see http://mysql-dba-journey.blogspot.com/2010/01/installing-mysql-51-on-linux-using-moca.html) 
#            and configures the server for the size of the VM that it is on, 
#            creates database users, and installs the innotop monitor
# TODOs:     Accept a parameter that indicates this will be a replication slave
#            and further parameters for configuration.
# Notes:     This script must be run as root
# Change Log
# Date           Name           Description
# *****************************************************************************
# 01/25/2011     BEH            File Creation
# 04/22/2011     BEH            Remove package install in favor of a MOCA 
#                               install from tarball.
# *****************************************************************************
# Define the script's usage from the command line.
function usage
{
echo "
This script installs the mysql server on the current host, sets certain 
configuraiton parameters based on the size of the host, creates users for the 
database, secures the database and installs the innotop monitor.

This script expects to be root.

Usage:  $SCRIPT_NAME [-x]
        -x Execute this script

Example(s):
    $SCRIPT_NAME -x

"
}

# Location of the template for the /etc/mysql/my.cnf file
TEMPLATE_DIR="/tmp/template"



# *****************************************************************************
# library includes of common tasks
# *****************************************************************************
. lib/global.sh
. lib/got_root.sh
. lib/install_packages.sh
. lib/make_mysql_users.sh
. lib/make_users.sh



# *****************************************************************************
# Script specific configuration
# *****************************************************************************
# Need to set this variable so that mysql package install does not hang
# on obtaining a root password
export DEBIAN_FRONTEND=noninteractive

# List of of mysql users who should have root like access.  
MYSQL_ROOT_USERS[0]="dba"

MYSQL_ROOT_PASSWORDS[0]="*FF12726F1B67BBA61611C66A95C03241B09D2042" #geek

# List of packages to install on the new server.
# These must be valid package names from Ubuntu's apt-get 
PACKAGES[0]="libterm-readkey-perl"
PACKAGES[1]="libaio1"
PACKAGES[2]="libdbd-mysql-perl"

# *****************************************************************************                                  
# Script specific configuration                                                                                  
# *****************************************************************************                                  
# List of users to create an account for by their feedmagent address.  It is                                     
# important to use email address as the account name is the same as the name                                     
# of the email account, and the account name and password will be emailed to                                     
# the user upon account creation.                                                                                
USERS[0]="mysql"                                                                                                  
                                                                                                                 
PASSWORDS[0]='$6$oaqytT0R$iavEjvftqqWFhpyal/P9WrQwZu2XG0lbmfUkiPPbagg.ROHXGgRidFtg7kqIUnwbW.50jJaeT1f25cKZDcxxp1' #geek


# MySQL Details
MYSQL_VERSION="5.5.11"

MYSQL_BASE="/opt/mysql"

MYSQL_HOME="/opt/mysql/$MYSQL_VERSION"

MYSQL_DOWNLOAD_URL="http://dev.mysql.com/get/Downloads/MySQL-5.5/mysql-5.5.11-linux2.6-x86_64.tar.gz/from/http://mysql.mirrors.pair.com/"

# *****************************************************************************
# Define local functions
# *****************************************************************************
# Download and layout mysql
function layout_mysql_server
{
    ACTION="+++++ Download mysql, unpack and link mysql server +++++"
    echo $ACTION
    
    wget $MYSQL_DOWNLOAD_URL
    
    ACTION="+++++ Getting rid of debian 'helpfulness'"
    echo $ACTION
    
    mv /etc/mysql /etc/mysql-junk
    mkdir /opt/mysql
    cp /tmp/mysql-5.5.11-linux2.6-x86_64.tar.gz $MYSQL_BASE/
    cd $MYSQL_BASE
    tar zxvf mysql-5.5.11-linux2.6-x86_64.tar.gz

    ln -sv mysql-5.5.11-linux2.6-x86_64 $MYSQL_VERSION
    cd /tmp
}


# Create directory structure for MySQL data, logs and files
function create_mysql_directory_layout
{
    ACTION="+++++ Create directory structure for MySql +++++"
    echo $ACTION
        
    ACTION="      ++++ Create data, log and admin area layout ++++"
    echo $ACTION
    
    mkdir /db
    mkdir /db/mysql
    mkdir /db/mysql/data
    mkdir /db/mysql/admin
    mkdir /db/mysql/tmp
    mkdir /db/mysql/binary_logs
    mkdir /db/mysql/innodb
    mkdir /db/mysql/relay_logs
    chmod 755 /db
    chown -R mysql:mysql /db/mysql 

}

# Start the Mysql Server
function make_mysql_grant_tables
{
    ACTION="+++++ Installing the default databases for mysql +++++"
    echo $ACTION
    
    $MYSQL_HOME/scripts/mysql_install_db --datadir=/db/mysql/data --basedir=$MYSQL_HOME
    chmod -R 775 /db/mysql
    chown -R mysql:mysql /db/mysql
}

# Install the innotop monitor
function install_innotop
{
    ACTION="+++++ Installing Innotop monitor +++++"
    echo $ACTION 
    
    cd /tmp
    wget http://innotop.googlecode.com/files/innotop-1.8.0.tar.gz
    tar -xzf innotop-1.8.0.tar.gz
    cd innotop-1.8.0
    perl Makefile.PL
    make
    make install
    rm /tmp/innotop-1.8.0.tar.gz
    rm -rf /tmp/innotop-1.8.0
    cd /tmp
}

# Install the maatkit tool set
function install_maatkit
{
    ACTION="+++++ Installing maatkit toolkit +++++"
    echo $ACTION 
    
    cd /tmp
    wget http://maatkit.googlecode.com/files/maatkit-7410.tar.gz
    tar zxvf maatkit-7410.tar.gz
    cd maatkit-7410
    perl Makefile.PL
    make
    make install
    rm /tmp/maatkit-7410.tar.gz
    rm -rf /tmp/maatkit-7410
    
}

# Print next steps
function print_next_steps
{
echo "
Mysql is now installed and configured for this machine, but you are not done yet!

+++++
Clean Start - as root
+++++
> su -l mysql
> cd /opt/mysql/5.5.11/
> bin/mysqld_safe --defaults-file=my.cnf &

> less /db/mysql/admin/<SERVER_NAME>-error.log

If there are any warnings or errors (there likely is one for creating the innodb 
tablespce), stop the server and start it again

> mysqladmin -uroot shutdown

+++++
Secure instance - as root
+++++
> mysql mysql
% grant all on *.* to 'dba'@'localhost' identified by 'geek';
% delete from user where user = 'root';
% delete from user where user = '';
% flush privileges;
% exit
> mysql -udba -pgeek
"
}


# Write out the mysql configuration file for initial install
function configure_mysql
{
    # Standard Configurations
    # Some of these will be absolute such as file paths, others will be computed
    # based on the size of the slice MySQL is being installed on.
    # General
    PORT="3306"                         # Standard Port
    
    D_MAX_ALLOWED_PACKET="XXX"          # Measured in MB, import for client
                                        # and mysqld sections to match for
                                        # import/export purposes
    # Paths
    ADMIN_PATH="\/db\/mysql\/admin"        # Path to socket, slow query log 
                                        # general log, and the like,
                                        # these are not needed for a backup
    
    DATA_PATH="\/db\/mysql\/data"          # Path to data directory.
    
    TMP_PATH="\/db\/mysql\/tmp"            # location for mysql temporary files 
    
    LOG_BIN="\/db\/mysql\/binary_logs"  # location of binary logs and their index
                                        # bin logs contain the name of the slice
                                        # on which they reside to assist in 
                                        # in multiple slice administration
    
    RELAY_LOG_PATH="\/db\/mysql\/relay_logs"
                                        # location of the relay logs for a slave
                                        # used to support daisy chained 
                                        # replication
    
    INNODB_PATH="\/db\/mysql\/innodb"   # location of innodb tablespaces
                                        # and logs
                                        
    # Logging 
    D_EXPIRE_LOGS_DAYS="XXX"            # Number of Days to keep bin log before
                                        # purging.  This is a function of drive
                                        # size relative to amount of data
    
    D_SLOW_QUERY_LOG="XXX"              # Shut off for slices <= 1GB due 
                                        # drive size concerns

    D_LONG_QUERY_TIME="XXX"             # Number of seconds for a query to be
                                        # considered slow
    
    # Global Memory Settings
    # Each parameter below is for the entire MySQL server.  The sum should not
    # be 100% however as the OS will need memory as do the individual sessions
    # below.  Be absolutely sure they sum of these, the sessions and the OS 
    # will always be below 100% otherwise swapping will occur.
    D_MAX_CONNECTIONS="XXX"
    
    D_TABLE_OPEN_CACHE="XXX"
    
    D_TABLE_DEFINITION_CACHE="XXX"
    
    D_THREAD_CACHE_SIZE="XXX"
    
    D_QUERY_CACHE_SIZE="XXX"
    
    D_INNODB_BUFFER_POOL_SIZE="XXX"

    D_KEY_BUFFER_SIZE="XXX"             # Supports use of the mysql schema, so needs
                                        # to be of some size.  Beware of any
                                        # MyISAM tables or schemas using 
                                        # MyISAM if there is more than 
                                        # Feedmagnet on the server.
    
    #Session Level Memory Settings
    D_GROUP_CONCAT_MAX_LEN="XXX"
    
    D_JOIN_BUFFER_SIZE="XXX"

    # Innodb
    D_INNODB_DATA_FILE_PATH="XXX"       # File name, initial size of 
                                        # the innodb tablespace
                                        
    D_INNODB_AUTOEXTEND_INCREMENT="XXX" # Number of mb to extend the tablespace
                                        # when its size limit is reached.
                                                                                
    D_INNODB_THREAD_CONCURRENCY="XXX"   # Number of thread innodb can use 
                                        # simultaneously
                                        
    D_INNODB_LOG_FILE_SIZE="XXX"             
    
    D_MYISAM_SORT_BUFFER_SIZE="XXX"
    
    D_SORT_BUFFER_SIZE="XXX"
    
    D_READ_BUFFER_SIZE="XXX"
    
    D_READ_RND_BUFFER_SIZE="XXX"
    
    D_TMP_TABLE_SIZE="XXX"
   
    # Set the paths
    sed -i "s|<D_MYSQL_HOME>|$MYSQL_HOME|g" $TEMPLATE_DIR/my.cnf.base
    sed -i "s/<PORT>/$PORT/g" $TEMPLATE_DIR/my.cnf.base
    sed -i "s/<HOST>/$HOST/g" $TEMPLATE_DIR/my.cnf.base
    sed -i "s/<ADMIN_PATH>/$ADMIN_PATH/g" $TEMPLATE_DIR/my.cnf.base
    sed -i "s/<DATA_PATH>/$DATA_PATH/g" $TEMPLATE_DIR/my.cnf.base
    sed -i "s/<TMP_PATH>/$TMP_PATH/g" $TEMPLATE_DIR/my.cnf.base
    sed -i "s/<LOG_BIN>/$LOG_BIN/g" $TEMPLATE_DIR/my.cnf.base
    sed -i "s/<RELAY_LOG_PATH>/$RELAY_LOG_PATH/g" $TEMPLATE_DIR/my.cnf.base
    sed -i "s/<INNODB_PATH>/$INNODB_PATH/g" $TEMPLATE_DIR/my.cnf.base
 
    # Set MAX_ALLOWED_PACKET to between 32M and 128M based on the size of the
    # server
    TMP=$(($MEMORY/10))
    UNIT="M"
    if [[ $TMP -le 32 ]]
    then
        SET="32"
    elif [[ $TMP -ge 128 ]]
    then
        SET="128"
    else
        SET="$TMP"
    fi
    D_MAX_ALLOWED_PACKET="$SET$UNIT"
    sed -i "s/<D_MAX_ALLOWED_PACKET>/$D_MAX_ALLOWED_PACKET/g" $TEMPLATE_DIR/my.cnf.base 
    echo "seting D_MAX_ALLOWED_PACKET =             $D_MAX_ALLOWED_PACKET"
       
    # The number of days of logs to keep directly relates to the amount of 
    # hard drive space will be consumed.  For a busy server this can be 
    # in the 10G to 25G range for 10 days.  Thus, for smaller servers 
    # fewer days of logs will be kept.  The cost here is that if replication
    # breaks before time is up, then it must be rebuilt from the ground
    # up
    TMP=$(($HARDDRIVE/10))    
    if [[ $HARDDRIVE -le 30 ]]
    then
        SET=$TMP
    elif [[ $HARDDRIVE -le 60 ]]
    then
        SET="3"
    elif [[ $HARDDRIVE -le 120 ]]
    then
        SET="5"
    else
        SET=10
    fi
    D_EXPIRE_LOGS_DAYS="$SET"
    sed -i "s/<D_EXPIRE_LOGS_DAYS>/$D_EXPIRE_LOGS_DAYS/g" $TEMPLATE_DIR/my.cnf.base
    echo "setting D_EXPIRE_LOGS_DAYS =              $D_EXPIRE_LOGS_DAYS"

    # The slow query log should only be enabled for slices above a 
    # gigabyte.  If needed on something smaller it can be started
    # and stopped dynamically
    D_SLOW_QUERY_LOG="0"
    if [[ $MEMORY -ge 1000 ]] 
    then
        D_SLOW_QUERY_LOG="1"
    fi
    sed -i "s/<D_SLOW_QUERY_LOG>/$D_SLOW_QUERY_LOG/g" $TEMPLATE_DIR/my.cnf.base
    echo  "setting D_SLOW_QUERY_LOG =               $D_SLOW_QUERY_LOG"
    # The slow query log will written to when a query takes longer
    # than this number of seconds, thus the lower the number the 
    # larger the log.  Ideally no query runs for more than one (1) second so
    # but this could mean a very large number of queries and a
    # large amount of drive space.  Queries should not, however, regularly
    # take more than 2 seconds.
    D_LONG_QUERY_TIME=2
    if [[ $MEMORY -ge 1100 ]]
    then
        D_LONG_QUERY_TIME="1"
    fi
    sed -i "s/<D_LONG_QUERY_TIME>/$D_LONG_QUERY_TIME/g" $TEMPLATE_DIR/my.cnf.base
    echo "setting D_LONG_QUERY_TIME =               $D_LONG_QUERY_TIME"

    # The maximum number of connects should reflect the size of memory
    # because while each connection itslef has a very small usage
    # session variables can add up to many MB.  
    D_MAX_CONNECTIONS="$(($MEMORY/5))"
    sed -i "s/<D_MAX_CONNECTIONS>/$D_MAX_CONNECTIONS/g" $TEMPLATE_DIR/my.cnf.base
    echo "setting D_MAX_CONNECTIONS =               $D_MAX_CONNECTIONS"

    # This value is the number of file descriptors used by the operating system
    # to keep tables open.  For our purposes there is no reason to have more
    # than 300 tables open at any given time. 
    TMP=$(($MEMORY/3))
    if [[ $TMP -le 300 ]]
    then
        D_TABLE_OPEN_CACHE="$TMP"
    else
        D_TABLE_OPEN_CACHE="300"
    fi
    sed -i "s/<D_TABLE_OPEN_CACHE>/$D_TABLE_OPEN_CACHE/g" $TEMPLATE_DIR/my.cnf.base
    echo "setting D_TABLE_OPEN_CACHE =              $D_TABLE_OPEN_CACHE"    
    # Table definitions can be stored in a faster cache that does not use file
    # descriptors.  For our purpose we do not have a large number of tales to
    # begin with so this can be small even for large servers.
    TMP=$(($MEMORY/3))
    if [[ $TMP -le 150 ]]
    then
        D_TABLE_DEFINITION_CACHE="$TMP"
    else
        D_TABLE_DEFINITION_CACHE="150"
    fi
    sed -i "s/<D_TABLE_DEFINITION_CACHE>/$D_TABLE_DEFINITION_CACHE/g" $TEMPLATE_DIR/my.cnf.base
    echo "setting D_TABLE_DEFINITION_CACHE =        $D_TABLE_DEFINITION_CACHE"

    # Number of threads kept cached for reuse.  Threads are taken from the 
    # cache before they are created, so the speeds requests.  A thread released
    # by a client is first place here.
    TMP=$(($MEMORY/20+10))
    if [[ $TMP -le 100 ]] 
    then 
        D_THREAD_CACHE_SIZE="$TMP"
    else
        D_THREAD_CACHE_SIZE="100"
    fi
    sed -i "s/<D_THREAD_CACHE_SIZE>/$D_THREAD_CACHE_SIZE/g" $TEMPLATE_DIR/my.cnf.base
    echo "setting D_THREAD_CACHE_SIZE =             $D_THREAD_CACHE_SIZE"

    # The query cache is not terribly useful for our purposes due to the 
    # frequency of writes to the tables that are queried.  
    TMP=$(($MEMORY/20))
    UNIT="M"
    D_QUERY_CACHE_SIZE="$TMP$UNIT"
    sed -i "s/<D_QUERY_CACHE_SIZE>/$D_QUERY_CACHE_SIZE/g" $TEMPLATE_DIR/my.cnf.base
    echo "setting D_QUERY_CACHE_SIZE =              $D_QUERY_CACHE_SIZE"

    # Innodb buffer pool is the workhorse for an innodb heavy database and 
    # should take up a large percentage of memory.  Slices are assumed to 
    # range between 256M and 8G in size.  The percent available memory changes
    # as the slice gets bigger as the amount of memory need for the OS and 
    # other necessary process decreases as a percent of the total.
    UNIT="M"
    TMP="48"
    if [[ $MEMORY -le 512 ]] 
    then
        TMP=$((($MEMORY*40)/100)) 
    elif [[ $MEMORY -le 1024  ]]
    then
        TMP=$((($MEMORY*50)/100)) 
    elif [[ $MEMORY -le 4096 ]]
    then
        TMP=$((($MEMORY*60)/100))
    else
        TMP=$((($MEMORY*70)/100)) 
    fi
    D_INNODB_BUFFER_POOL_SIZE="$TMP$UNIT"
    sed -i "s/<D_INNODB_BUFFER_POOL_SIZE>/$D_INNODB_BUFFER_POOL_SIZE/g" $TEMPLATE_DIR/my.cnf.base
    echo "setting D_INNODB_BUFFER_POOL_SIZE =       $D_INNODB_BUFFER_POOL_SIZE"

    # The Key Buffer roughly correlates to the innnodb buffer pool for MyIsam
    # tables.  It is important to remember that the mysql database is, by
    # default, MyISAM and cannot be changed, and that any temporary tables
    # create on disk during a query are also MyISAM, so this value should be
    # non-zero and mildly reflect the size of the slice.
    UNIT="M"
    TMP="32"
    if [[ $MEMORY -le 512 ]]
    then
        TMP="32"
    elif [[ $MEMORY -le 1024 ]]
    then 
        TMP="48"
    elif [[ $MEMORY -le 4096 ]]
    then 
        TMP="64"
    else
        TMP="128"
    fi
    D_KEY_BUFFER_SIZE="$TMP$UNIT"
    sed -i "s/<D_KEY_BUFFER_SIZE>/$D_KEY_BUFFER_SIZE/g" $TEMPLATE_DIR/my.cnf.base
    echo "setting D_KEY_BUFFER_SIZE =               $D_KEY_BUFFER_SIZE"

    # The maximum number of bytes the group_concat() aggregation function 
    # can return.  This is a safety check as this fucntion could potentially
    # create a huge result on a blown join or mis-use.
    TMP="1024"
    if [[ $MEMORY -le 512 ]]
    then
        TMP="1024"
    elif [[ $MEMORY -le 1024 ]]
    then 
        TMP="4096"
    elif [[ $MEMORY -le 4096 ]]
    then 
        TMP="8192"
    else
        TMP="16384"
    fi  
    D_GROUP_CONCAT_MAX_LEN="$TMP"
    sed -i "s/<D_GROUP_CONCAT_MAX_LEN>/$D_GROUP_CONCAT_MAX_LEN/g" $TEMPLATE_DIR/my.cnf.base
    echo "setting D_GROUP_CONCAT_MAX_LEN =          $D_GROUP_CONCAT_MAX_LEN"

    # When a join is performed that does not involve and index, this is the 
    # MINIMUM size of the buffer alotted to the join.  Thus, this setting is 
    # very small.  MySQL will dyanically grow this buffer as necessary. 
    TMP="1024"
    UNIT="M"
    if [[ $MEMORY -le 512 ]]
    then
        TMP="1"
    elif [[ $MEMORY -le 1024 ]]
    then 
        TMP="1"
    elif [[ $MEMORY -le 4096 ]]
    then 
        TMP="2"
    else
        TMP="2"
    fi  
    D_JOIN_BUFFER_SIZE="$TMP"
    sed -i "s/<D_JOIN_BUFFER_SIZE>/$D_JOIN_BUFFER_SIZE/g" $TEMPLATE_DIR/my.cnf.base
    echo "setting D_JOIN_BUFFER_SIZE =              $D_JOIN_BUFFER_SIZE"    

    # On the initial startup of innodb, the system creates the innodb table-
    # space specified by this file.  Keep in mind that the larger the file
    # the larger the longer initial startup will be.  Tail the error log
    # while startup is occuring to see mysql working its way through this 
    # process.   
    #
    # Because we are using file-per-table the need for a huge tablespace 
    # is not relevant.  So, it may seem that this is quite small, but remember
    # no data is stored here, mostly it is structures for support of 
    # transactions. Keeping this file smaller makes the physical copy of the 
    # database or cloning of the slice much faster.
    TABLESPACE_NAME="ibdata"
    SEPARATOR="_"
    TMP="128"
    UNIT="M"
    if [[ $MEMORY -le 512 ]]
    then
        TMP="128"
    elif [[ $MEMORY -le 1024 ]]
    then 
        TMP="256"
    elif [[ $MEMORY -le 4096 ]]
    then 
        TMP="512"
    else
        TMP="1024"
    fi  
    D_INNODB_DATA_FILE_PATH="$HOST$SEPARATOR$TABLESPACE_NAME:$TMP$UNIT:autoextend"
    sed -i "s/<D_INNODB_DATA_FILE_PATH>/$D_INNODB_DATA_FILE_PATH/g" $TEMPLATE_DIR/my.cnf.base
    echo "setting D_INNODB_DATA_FILE_PATH =         $D_INNODB_DATA_FILE_PATH"

    # If the tablespace needs to grow, it should grow by an increment that
    # should happen rarely enough as to limit disk activity but small enough
    # that a pause in the end user experience is negligible. Keep in mind that
    # file-per-talbe means that the need to grown the tablespace should be
    # both rare and small.
    TMP="8"
    if [[ $MEMORY -le 512 ]]
    then
        TMP="8"
    elif [[ $MEMORY -le 1024 ]]
    then 
        TMP="8"
    elif [[ $MEMORY -le 4096 ]]
    then 
        TMP="16"
    else
        TMP="32"
    fi  
    D_INNODB_AUTOEXTEND_INCREMENT="$TMP"
    sed -i "s/<D_INNODB_AUTOEXTEND_INCREMENT>/$D_INNODB_AUTOEXTEND_INCREMENT/g" $TEMPLATE_DIR/my.cnf.base
    echo "setting D_INNODB_AUTOEXTEND_INCREMENT =   $D_INNODB_AUTOEXTEND_INCREMENT"

    # The number of threads innodb can run concurrently is generally set by 
    # this formula:
    #       2 * number of cores + number of hard drives 
    # Because, on a slice, neither of these numbers is known, conservative 
    # extrapolation from the know parameters of the physical machine
    # is used.  Note that if threads are stacking up in innodb, then this 
    # likely needs to be adjusted up, but with caution as making the number 
    # too large can cause innodb to thread thrash and seriously degrade
    # performance.
    TMP=2
    TMP="1024"
    if [[ $MEMORY -le 512 ]]
    then
        TMP="2"
    elif [[ $MEMORY -le 1024 ]]
    then 
        TMP="2"
    elif [[ $MEMORY -le 4096 ]]
    then 
        TMP="8"
    else
        TMP="16"
    fi  
    D_INNODB_THREAD_CONCURRENCY="$TMP"
    sed -i "s/<D_INNODB_THREAD_CONCURRENCY>/$D_INNODB_THREAD_CONCURRENCY/g" $TEMPLATE_DIR/my.cnf.base
    echo "setting D_INNODB_THREAD_CONCURRENCY =     $D_INNODB_THREAD_CONCURRENCY"

    # Innodb logs are generally used for crash recovery and can effect both
    # the time it takes to shut down mysql, and the time it can take to restart
    # after a crash.  The larger the log the longer the startup time.
    # Additionally, small logs cause a great deal of disk IO as they need to be 
    # rotate frequently.  It is recommended that logs be of the size:
    #       innodb_buffer_pool_size / number-logs
    # Since we use two logs, this means each will be one-half the size of the
    # buffer pool up to a maximum of 4GB.  Because of crash recovery and portability
    # considerations we will allow for a maximum log size of 512M
    IBPS=$(echo $D_INNODB_BUFFER_POOL_SIZE | cut -d'M' -f 1) 
    TMP=$(($IBPS/2))
    UNIT="M"
    if [[ $TMP -lt 5 ]]
    then
        TMP="5"
    elif [[ $TMP -gt 512 ]]
    then    
        TMP="512"
    fi
    D_INNODB_LOG_FILE_SIZE="$TMP$UNIT"
    sed -i "s/<D_INNODB_LOG_FILE_SIZE>/$D_INNODB_LOG_FILE_SIZE/g" $TEMPLATE_DIR/my.cnf.base
    echo "setting D_INNODB_LOG_FILE_SIZE =          $D_INNODB_LOG_FILE_SIZE"

    # While the myisam_sort_buffer_size has myisam in the name, it is relevant
    # for all storage engines that use DDL statements such as ALTER or OPTIMIZE.
    # It is a session variable, however because of the above, it is rarely used
    # and can be thought of as the amount of memory a DDL statement will be
    # allocated to perform its task.  The MyISAM in the name comes from the fact
    # that a MyISAM table will be created on disk to support the operation.
    TMP="16"
    UNIT="M"
    if [[ $MEMORY -le 512 ]]
    then
        TMP="16"
    elif [[ $MEMORY -le 1024 ]]
    then 
        TMP="32"
    elif [[ $MEMORY -le 4096 ]]
    then 
        TMP="64"
    else
        TMP="128"
    fi  
    D_MYISAM_SORT_BUFFER_SIZE="$TMP$UNIT"
    sed -i "s/<D_MYISAM_SORT_BUFFER_SIZE>/$D_MYISAM_SORT_BUFFER_SIZE/g" $TEMPLATE_DIR/my.cnf.base
    echo "setting D_MYISAM_SORT_BUFFER_SIZE =       $D_MYISAM_SORT_BUFFER_SIZE"

    # The sort buffer is used by any process that uses GROUP BY or ORDER BY.
    # If the amount of memory needed for the sort caused by these operations 
    # exceeds the setting, then the sort operation is done on disk.
    TMP="2"
    UNIT="M"
    if [[ $MEMORY -le 512 ]]
    then
        TMP="2"
    elif [[ $MEMORY -le 1024 ]]
    then 
        TMP="4"
    elif [[ $MEMORY -le 4096 ]]
    then 
        TMP="8"
    else
        TMP="16"
    fi  
    D_SORT_BUFFER_SIZE="$TMP$UNIT"
    sed -i "s/<D_SORT_BUFFER_SIZE>/$D_SORT_BUFFER_SIZE/g" $TEMPLATE_DIR/my.cnf.base
    echo "setting D_SORT_BUFFER_SIZE =              $D_SORT_BUFFER_SIZE"
    
    # Any sequential scan of a table is allocated a read buffer.  
    TMP="1"
    UNIT="M"
    if [[ $MEMORY -le 1024 ]]
    then
        TMP="1"
    elif [[ $MEMORY -le 4096 ]]
    then
        TMP="2"
    else
        TMP="3"
    fi
    D_READ_BUFFER_SIZE="$TMP$UNIT"
    sed -i "s/<D_READ_BUFFER_SIZE>/$D_READ_BUFFER_SIZE/g" $TEMPLATE_DIR/my.cnf.base
    echo "setting D_READ_BUFFER_SIZE =              $D_READ_BUFFER_SIZE"
    
    # ORDER BY is a big part of our system for most current information.  So,
    # this value is set a bit higher than what might otherwise be used.  
    # If INNODB_BUFFER_POOL hits drop below 99%, then this is likely set too
    # high.  
    TMP="2"
    UNIT="M"
    if [[ $MEMORY -le 1024 ]]
    then
        TMP="2"
    elif [[ $MEMORY -le 4096 ]]
    then
        TMP="4"
    else
        TMP="8"
    fi      
    D_READ_RND_BUFFER_SIZE="$TMP$UNIT"
    sed -i "s/<D_READ_RND_BUFFER_SIZE>/$D_READ_RND_BUFFER_SIZE/g" $TEMPLATE_DIR/my.cnf.base
    echo "setting D_READ_RND_BUFFER_SIZE =          $D_READ_RND_BUFFER_SIZE"

    # When a temporary table exceeds this size, it is written to disk.  Temporary
    # table are quite frequent for join support, etc.  However, this is a session
    # level variable, so a busy server can have many of these tables open.  This
    # shoud only be increased if the ratio of created-tmp-disk-tables and 
    # created-tmp-tables becomes too large.
    TMP="4"
    UNIT="M"
    if [[ $MEMORY -le 512 ]]
    then
        TMP="4"
    elif [[ $MEMORY -le 1024 ]]
    then 
        TMP="8"
    elif [[ $MEMORY -le 4096 ]]
    then 
        TMP="32"
    else
        TMP="64"
    fi  
    D_TMP_TABLE_SIZE="$TMP$UNIT"
    sed -i "s/<D_TMP_TABLE_SIZE>/$D_TMP_TABLE_SIZE/g" $TEMPLATE_DIR/my.cnf.base
    echo "setting D_TMP_TABLE_SIZE =                $D_TMP_TABLE_SIZE"

    ACTION="+++++ Copying new config file $TEMPLATE_DIR/my.cnf.base to $MYSQL_HOME/my.cnf +++++"
    echo $ACTION
    
    cp $TEMPLATE_DIR/my.cnf.base $MYSQL_HOME/my.cnf
    chown -R mysql:mysql $MYSQL_BASE
    chmod -R 775 $MYSQL_BASE
}

# Configure the bash profile for the mysql user
function configure_mysql_shell_user
{
    ACTION="+++++ Create the .bash_profile for the mysql user for convenient server starts/stops, etc +++++"
    echo $ACTION
    
    BASH_PROFILE_BASE="$TEMPLATE_DIR/bash_profile.base"
    sed -i "s|<D_MYSQL_BASE>|$MYSQL_BASE|g" $BASH_PROFILE_BASE
    sed -i "s|<D_MYSQL_HOME>|$MYSQL_HOME|g" $BASH_PROFILE_BASE
    
    cp $BASH_PROFILE_BASE /home/mysql/.bash_profile
    chown mysql:mysql /home/mysql/.bash_profile
    chmod 755 /home/mysql/.bash_profile
    
    
}



# *****************************************************************************
# Insure the user is root and that options are passed
# *****************************************************************************
# If no options are supplied, display the usage and exit.
# This test cannot be done in the getopts while/case
# below because if no options are supplied, then the while
# loop is not executed.
if [[ $# -eq 0 ]]
then
   usage
   exit 1
fi


# *****************************************************************************
# Main function sequences the work, documents the process from a high level
# *****************************************************************************
function main
{
    got_root
    install_packages
    layout_mysql_server
    make_users
    configure_mysql_shell_user
    create_mysql_directory_layout
    configure_mysql
    make_mysql_grant_tables
    install_innotop
    install_maatkit      
    print_next_steps
}



# *****************************************************************************
# Run it and time it
# *****************************************************************************
time main
