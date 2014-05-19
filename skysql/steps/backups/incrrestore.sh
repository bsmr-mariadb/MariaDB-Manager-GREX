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
# This script restores an incremental backup on the database
#

TMPFILE="/tmp/innobackupex-runner.$$.tmp"

## Restore vars
RESTOREPATH="/tmp"

# Creates temporary directories if they do not exist
mkdir -p "$RESTOREPATH/incr"
mkdir -p "$RESTOREPATH/extr"
mkdir -p "$RESTOREPATH/mysql_tmp_cp"

if [[ -z "$db_password" ]]; then
        USEROPTIONS="--user=$db_username"

else
        USEROPTIONS="--user=$db_username --password=$db_password"
fi
DATAFOLDER=$(cat $my_cnf_file | awk 'BEGIN { FS="=" } { if ($1 == "datadir") print $2 }')

if [[ "$DATAFOLDER" == "" ]] ; then
	echo "ERROR :" $(date "+%Y%m%d_%H%M%S") "-- Data folder not defined in MySQL configuration file"
	exit 1
fi

# prepareapply(): Prepares the full backup and applies on it all the incrementals from the oldest to the youngest
# Arguments:
#      -a arg: the array which stores the Backup names (assumes the base fullbackup is stored on its last position)

prepareapply() {
	while getopts  "a:" Option
	do
	case $Option in
	a)   declare -a arrbkp=("${!OPTARG}") ;;

	* ) echo "Not recognized argument"; exit -1 ;;
	esac
	done

	index=$((${#arrbkp[@]} - 1))

	bkpname=${arrbkp[$index]}

	# Extracting previouly retrieved base fullbackup
	cur=`pwd`
	cd "$RESTOREPATH/extr"
	tar -xivf "$backups_remotepath/$bkpname"
	rm -f "$backups_remotepath/$bkpname"
	cd "$cur"

	# Preparing base backup
	innobackupex $USEROPTIONS --defaults-file "$my_cnf_file" --apply-log --redo-only "$RESTOREPATH/extr" &> $TMPFILE
	if [[ -z "$(tail -1 $TMPFILE | grep 'completed OK!')" ]] ; then
		echo "ERROR :" $(date "+%Y%m%d_%H%M%S") "Restore failed (stage 'preparing the backup'):"; echo
		echo "---------- ERROR OUTPUT from innobackupex ----------"
		cat $TMPFILE
		rm -f $TMPFILE
		exit 1
	else
		cat $TMPFILE
	fi
	
	# Applying incremental backups
	INCREMENTALDIR="$RESTOREPATH/incr"
	rm -fR $INCREMENTALDIR/*
	let "index = $index - 1"
	while [[ "$index" -ge 0 ]]
	do
		bkpname=${arrbkp[index]}
		xbstream -x < $backups_remotepath/$bkpname -C "$INCREMENTALDIR"
		innobackupex --apply-log --defaults-file="$my_cnf_file" --use-memory=1G $USEROPTIONS --incremental-dir="$INCREMENTALDIR" "$RESTOREPATH/extr"
		rm -fR $INCREMENTALDIR/*
		rm -f "$backups_remotepath/$bkpname"
		let "index = $index - 1"
	done

	# Prepare the base backup after applying incremental backups
	innobackupex $USEROPTIONS --apply-log --redo-only "$RESTOREPATH/extr" &> $TMPFILE
}


# getbackups(): extracts all the backups and stores them into an array, last pos == base fullbackup 
getbackups() {
	index=0
	
	while [[ "$BACKUPID" != "0" ]]; do
		# Getting backup info
		filename=$(api_call "GET" "system/$system_id/backup/$BACKUPID" "fieldselect=backup~backupurl")
		level=$(api_call "GET" "system/$system_id/backup/$BACKUPID" "fieldselect=backup~level")
		parent_id=$(api_call "GET" "system/$system_id/backup/$BACKUPID" "fieldselect=backup~parentid")
	
		if [[ ! -f "${backups_remotepath}/${filename}.tgz" ]]; then
        		logger -p user.error -t MariaDB-Manager-Remote "Target backup file not found."
        		exit 1
		fi

		cur=$(pwd)
		cd "$backups_remotepath"
		tar xzvf "${filename}.tgz"
		tar_exit_code=$?
		if [[ "$tar_exit_code" != "0" ]]; then
		        logger -p user.error -t MariaDB-Manager-Remote "Unable to extract compressed backup file (file corrupt?)."
		        exit 1
		fi
		rm -f "${filename}.tgz"
		rm -f "${filename}.log"
		cd $cur

		arrbkp[index]="${filename}.bkp"
		if [[ "$level" == "2" ]]; then
          		BACKUPID="$parent_id"
	        else
        	        BACKUPID="0"
	        fi
		let "index = $index + 1"
	done

	prepareapply -a arrbkp[@]
}

# Cleaning potential hung files from previous aborted restore attempt
rm -fR $RESTOREPATH/mysql_tmp_cp/*
rm -fR $RESTOREPATH/extr/*
rm -fR $RESTOREPATH/incr/*

getbackups

if [[ -z "$(tail -1 $TMPFILE | grep 'completed OK!')" ]] ; then
	echo "ERROR :" $(date "+%Y%m%d_%H%M%S") "-- Restore failed - stage 'preparing the backup':"; 
	echo "---------- ERROR OUTPUT from innobackupex ----------"
	cat $TMPFILE
	rm -f $TMPFILE
	exit 1
else
	cat $TMPFILE
fi

# Stopping mysqld
/etc/init.d/mysql stop

if [[ $(mysqladmin $USEROPTIONS status | awk '{print $1}') == "Uptime:" ]]; then
	echo "ERROR :" $(date "+%Y%m%d_%H%M%S") "-- Server not properly shut down"
	exit 1
fi

# Cleaning the data folder
mv $DATAFOLDER/* $RESTOREPATH/mysql_tmp_cp/

# Restore by copyback of the backup folder into data folder
innobackupex $USEROPTIONS --defaults-file "$my_cnf_file" --copy-back "$RESTOREPATH/extr/" &> $TMPFILE

# Changing mysql data folder ownership back to mysql
chown -R mysql:mysql "$DATAFOLDER"

if [[ -z "$(tail -1 $TMPFILE | grep 'completed OK!')" ]] ; then
	echo "ERROR :" $(date "+%Y%m%d_%H%M%S") "-- Restore failed - stage 'copyback backup':"; 
	echo "---------- ERROR OUTPUT from innobackupex ----------"

	cat $TMPFILE
	rm -f $TMPFILE
	exit 1
else
	cat $TMPFILE
fi

# Restarting mysqld
/etc/init.d/mysql start --wsrep-cluster-address=gcomm://

sleep 10

if [[ ! $(mysqladmin $USEROPTIONS status | awk '{print $1}') == "Uptime:" ]]; then
	echo "ERROR :" $(date "+%Y%m%d_%H%M%S") "-- Server not properly started"
	exit 1
fi

mysql $USEROPTIONS -e "SET GLOBAL wsrep_provider=none;"
if [[ $? != 0 ]]; then
	echo "Unable to set global wsrep_provider."
	exit 1
fi

# Cleanup phase
rm -fR $RESTOREPATH/mysql_tmp_cp/*
rm -fR $RESTOREPATH/extr/*
rm -fR $RESTOREPATH/incr/*

exit 0
