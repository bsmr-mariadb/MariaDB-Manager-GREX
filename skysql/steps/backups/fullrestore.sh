#!/bin/bash
#
#  Part of SkySQL Galera Cluster Remote Commands package
#
# This file is distributed as part of the SkySQL Galera Cluster Remote Commands
# package.  It is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, version 2.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 51
# Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
# Copyright 2013 (c) SkySQL Ab 
#
# Author: Marcos Amaral
# Date: July 2013
#
#
# This script restores a full backup on the database
#

TMPFILE="/tmp/innobackupex-runner.$$.tmp"

RESTOREPATH="/tmp"
DATAFOLDER=`cat $my_cnf_file | awk 'BEGIN { FS="=" } { if ($1 == "datadir") print $2 }'`

if [ "$DATAFOLDER" == "" ] ; then
        echo "ERROR :" `date "+%Y%m%d_%H%M%S"` "-- Data folder not defined in MySQL configuration file"
        exit 1
fi

# Creates temporary directories if they do not exist
mkdir -p $RESTOREPATH/extr
mkdir -p $RESTOREPATH/mysql_tmp_cp

USEROPTIONS="--user=$db_username --password=$db_password"

# Checking if the script can access the database
if ! `echo 'exit' | /usr/bin/mysql -s $USEROPTIONS` ; then
	echo "ERROR :" `date "+%Y%m%d_%H%M%S"` "-- Supplied mysql username or password appears to be incorrect"
	exit 1
fi

# Cleaning potential hung files from previous aborted restore attempt
rm -fR $RESTOREPATH/mysql_tmp_cp/*
rm -fR $RESTOREPATH/extr/*

# Untarring previously retrieved fullbackup
cur=`pwd`
cd $RESTOREPATH/extr
tar -xivf $backups_path/FullBackup.$BACKUPID
cd $cur

# Preparing the backup - applying logs
innobackupex $USEROPTIONS --defaults-file $my_cnf_file --apply-log $RESTOREPATH/extr &> $TMPFILE

if [ -z "`tail -1 $TMPFILE | grep 'completed OK!'`" ] ; then
	echo "Restore failed (stage 'preparing the backup'):"; echo
	echo "---------- ERROR OUTPUT from $INNOBACKUPEX ----------"
	cat $TMPFILE
	rm -f $TMPFILE
	exit 1
else
	cat $TMPFILE
fi

# Stopping mysqld
/etc/init.d/mysql stop

mysql_status=`mysqladmin $USEROPTIONS status | awk '{print $1}'`

if [[ "$mysql_status" == "Uptime:" ]]; then
	echo "ERROR :" `date "+%Y%m%d_%H%M%S"` "-- Server not properly shut down"
	exit 1
fi

# Cleaning the data folder
mv $DATAFOLDER/* $RESTOREPATH/mysql_tmp_cp/

# Restore by copyback of the backup folder into data folder
innobackupex $USEROPTIONS --defaults-file=$my_cnf_file --copy-back $RESTOREPATH/extr/ &> $TMPFILE

if [ -z "`tail -1 $TMPFILE | grep 'completed OK!'`" ] ; then
	echo "ERROR :" `date "+%Y%m%d_%H%M%S"` "-- Restore failed (stage 'copyback backup'):"; echo
	echo "---------- ERROR OUTPUT from $INNOBACKUPEX ----------"

	cat $TMPFILE
	rm -f $TMPFILE
	exit 1
else
	cat $TMPFILE
fi

# Changing mysql datafolder ownership back to mysql
chown -R mysql:mysql $DATAFOLDER

# Restarting mysqld
/etc/init.d/mysql start --wsrep-cluster-address=gcomm://

sleep 10

if [ ! `mysqladmin $USEROPTIONS status | awk '{print $1}'` == "Uptime:" ]; then
 echo "ERROR :" `date "+%Y%m%d_%H%M%S"` "-- Server not properly started"
 exit 1
fi

mysql $USEROPTIONS -e "SET GLOBAL wsrep_provider=none;"

# Cleanup phase
rm -fR $RESTOREPATH/mysql_tmp_cp/*
rm -fR $RESTOREPATH/extr/*

exit 0
