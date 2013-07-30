#!/bin/sh
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
# This script creates a full backup on the configurated directory
#

. ./mysql-config.sh

# Creating the backup directory if it does not exist
mkdir -p $backups_path

TMPFILE="/tmp/innobackupex-runner.$$.tmp"
USEROPTIONS="--user=$mysql_user --password=$mysql_pwd"

# Checking if backup tool exists
if [ ! -x `which innobackupex` ]; then
	echo "ERROR :" `date "+%Y%m%d_%H%M%S"` "-- 'innobackupex' command does not exist."
	exit 1
fi

# Checking if the script can access the database
if ! `echo 'exit' | /usr/bin/mysql -s $USEROPTIONS` ; then
	echo "ERROR :" `date "+%Y%m%d_%H%M%S"` "-- Supplied mysql username or password appears to be incorrect."
	exit 1
fi

# Generating the backup file
innobackupex $USEROPTIONS --defaults-file=$my_cnf_file --stream=tar ./ > $backups_path/FullBackup.$BACKUPID 2> $TMPFILE

if [ -z "`tail -1 $TMPFILE | grep 'completed OK!'`" ] ; then
	echo "ERROR :" `date "+%Y%m%d_%H%M%S"` "-- $INNOBACKUPEX failed:"; echo
	echo "---------- ERROR OUTPUT from $INNOBACKUPEX ----------"
	cat $TMPFILE
	rm -f $TMPFILE
	exit 1
else
	cat $TMPFILE
fi

exit 0
