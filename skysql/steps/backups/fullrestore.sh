#!/bin/bash
#
# This file is distributed as part of MariaDB Manager.  It is free
# software: you can redistribute it and/or modify it under the terms of the
# GNU General Public License as published by the Free Software Foundation,
# version 2.
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
# Copyright 2012-2014 SkySQL Corporation Ab
#
# Author: Marcos Amaral
# Date: July 2013
#
#
# This script restores a full backup on the database
#

TMPFILE="/tmp/innobackupex-runner.$$.tmp"

RESTOREPATH="/tmp"
DATAFOLDER=$(cat "$my_cnf_file" | awk 'BEGIN { FS="=" } { if ($1 == "datadir") print $2 }')

if [[ "$DATAFOLDER" == "" ]] ; then
        echo "ERROR :" $(date "+%Y%m%d_%H%M%S") "-- Data folder not defined in MySQL configuration file"
        exit 1
fi

# Creates temporary directories if they do not exist
mkdir -p "$RESTOREPATH/extr"
mkdir -p "$RESTOREPATH/mysql_tmp_cp"

if [[ -z "$db_password" ]]; then
        USEROPTIONS="--user=$db_username"

else
        USEROPTIONS="--user=$db_username --password=$db_password"
fi

# Checking if the script can access the database
if ! $(echo 'exit' | /usr/bin/mysql -s $USEROPTIONS) ; then
	echo "ERROR :" $(date "+%Y%m%d_%H%M%S") "-- Supplied mysql username or password appears to be incorrect"
	exit 1
fi

# Cleaning potential hung files from previous aborted restore attempt
rm -rf "$RESTOREPATH"/mysql_tmp_cp
mkdir -p "$RESTOREPATH"/mysql_tmp_cp
rm -rf "$RESTOREPATH/extr"
mkdir -p "$RESTOREPATH/extr"

# Getting backup filename
filename=$(api_call "GET" "system/$system_id/backup/$BACKUPID" "fieldselect=backup~backupurl")

if [[ ! -f "${backups_remotepath}/${filename}.tgz" ]]; then
	errorMessage="Target backup file ${filename}.tgz not found."
	logger -p user.error -t MariaDB-Manager-Remote "$errorMessage"
	set_error "$errorMessage"
	exit 1
fi

# Extracting compressed backup file
cur=$(pwd)
cd "$backups_remotepath"
tar_output=$(tar xzvf "${filename}.tgz")
tar_exit_code=$?
if [[ "$tar_exit_code" != "0" ]]; then
	logger -p user.error -t MariaDB-Manager-Remote "Unable to extract compressed backup file (file corrupt?)."
	exit 1
fi
cd $cur

# Untarring previously retrieved fullbackup
cur=$(pwd)
cd "$RESTOREPATH/extr"
tar -xivf "${backups_remotepath}/${filename}.bkp"
cd $cur

# Preparing the backup - applying logs
innobackupex $USEROPTIONS --defaults-file "$my_cnf_file" --apply-log "$RESTOREPATH/extr" &> $TMPFILE

if [[ -z "$(tail -1 $TMPFILE | grep 'completed OK!')" ]] ; then
	echo "Restore failed (stage 'preparing the backup'):"; echo
	echo "---------- ERROR OUTPUT from innobackupex ----------"
	cat $TMPFILE
	rm -f $TMPFILE
	exit 1
else
	cat $TMPFILE
fi

# Cleaning remote backups folder
rm -f "${backups_remotepath}/${filename}.bkp"
rm -f "${backups_remotepath}/${filename}.tgz"
rm -f "${backups_remotepath}/${filename}.log"

# Stopping mysqld
/etc/init.d/mysql stop

mysql_status=$(mysqladmin $USEROPTIONS status | awk '{print $1}')

if [[ "$mysql_status" == "Uptime:" ]]; then
	echo "ERROR :" $(date "+%Y%m%d_%H%M%S") "-- Server not properly shut down"
	exit 1
fi

# Cleaning the data folder
mv $DATAFOLDER/* $RESTOREPATH/mysql_tmp_cp/

# Restore by copyback of the backup folder into data folder
innobackupex $USEROPTIONS --defaults-file="$my_cnf_file" --copy-back "$RESTOREPATH/extr/" &> $TMPFILE

if [[ -z "$(tail -1 $TMPFILE | grep 'completed OK!')" ]] ; then
	echo "ERROR :" $(date "+%Y%m%d_%H%M%S") "-- Restore failed (stage 'copyback backup'):"; echo
	echo "---------- ERROR OUTPUT from innobackupex ----------"

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
if [[ $? != 0 ]]; then
	echo "ERROR :" $(date "+%Y%m%d_%H%M%S") "-- Server not properly started"
	exit 1
fi

sleep 10

if [[ ! $(mysqladmin $USEROPTIONS status | awk '{print $1}') == "Uptime:" ]]; then
	echo "ERROR :" $(date "+%Y%m%d_%H%M%S") "-- Server not properly started"
	exit 1
fi

mysql $USEROPTIONS -e "SET GLOBAL wsrep_provider=none;"
if [[ $? != 0 ]]; then
	echo "ERROR :" $(date "+%Y%m%d_%H%M%S") "-- Failed to isolate node"
	exit 1
fi

# Cleanup phase
rm -fR $RESTOREPATH/mysql_tmp_cp/*
rm -fR $RESTOREPATH/extr/*

exit 0
