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
# This script is executed by NodeCommand.sh to start the backup process.
#
# Parameters:
# $1: Backup type ("Full" or "Incremental")
# $2: Base BackupID (only required if $1 = "Incremental)

echo `date "+%Y%m%d_%H%M%S"` "-- Command start: backup"
echo `date "+%Y%m%d_%H%M%S"` "-- params: backup_type $1; base_backup_id $2"

# Parameter validation
if [ "$1" == "" ] ; then
	echo `date "+%Y%m%d_%H%M%S"` "-- $0 invoked with no parameters"
	./restfulapi-call.sh "PUT" "task/$taskid" "errormessage=Missing parameters, backup should be called with a backup type and an optional id"
	exit 1
fi

if [ "$1" == "Full" ] ; then
	level=1
elif [[ "$1" == Incremental* ]] ; then
	level=2
	if [ $# -ge 2 ]; then
		export BASEBACKUPID=$2
	else
		echo `date "+%Y%m%d_%H%M%S"` "if level is 2 (incremental) <basebackupid> is required"
                echo 'Usage: $0 <system id> <node id> <level> [<basebackupid>]'
		./restfulapi-call.sh "PUT" "task/$taskid" "errormessage=Missing backup ID for incremental backup"
                exit 1
	fi
else
	echo `date "+%Y%m%d_%H%M%S"` "-- Invalid parameters"
	./restfulapi-call.sh "PUT" "task/$taskid" "errormessage=Invalid parameters for backup step"
	exit 1
fi

# Setting the state of the command to running
./restfulapi-call.sh "PUT" "task/$taskid" "state=running" > /dev/null

. ./mysql-config.sh

# Making an API call to create the Backup record on the DB, defining BACKUPID
. ./steps/backups/createbackup.sh

# Setting the backup state to 'scheduled'
./steps/backups/updatestatus.sh "$BACKUPID" "scheduled"

if [ "$level" -eq 1 ] ; then
	./steps/backups/fullbackup.sh > /tmp/backup.log.$$
	bkstatus=$?
	backupfilename="FullBackup.$BACKUPID"
elif [ "$level" -eq 2 ] ; then
	./steps/backups/incrbackup.sh > /tmp/backup.log.$$
	bkstatus=$?
	backupfilename="IncrBackup.$BACKUPID"
else
        echo `date "+%Y%m%d_%H%M%S"` "-- level parameter must have a value of 1 (full) or 2 (incremental)"
	./restfulapi-call.sh "PUT" "task/$taskid" "errormessage=Invalid backup level"
        exit 1
fi

binlogpos=`grep binlog /tmp/backup.log.$$ | awk '{ printf("%s%s\n", $6, $8); }' | sed -e s/\'//g`
size=`du -k "$backups_path/$backupfilename" | awk '{ print $1 }'`

if [ "$bkstatus" -eq 0 ] ; then # Backup successful
	# Updating backup state (completed) and other data on the DB
	if [ "$level" -eq 1 ] ; then
		./steps/backups/updatestatus.sh "$BACKUPID" "done" \
			size="$size" \
			storage="$backups_path/$backupfilename" \
			binlog="$binlogpos" \
			log="$backups_path/Log.$BACKUPID"
	elif [ "$level" -eq 2 ] ; then
		./steps/backups/updatestatus.sh "$BACKUPID" "done" \
			size="$size" \
                        log="$backups_path/Log.$BACKUPID" \
			parent="$BASEBACKUPID" \
                        storage="$backups_path/$backupfilename" \
                        binlog="$binlogpos"
	fi

	# Putting the log in place
	mv /tmp/backup.log.$$ "$backups_path/Log.$BACKUPID"
else # Backup unsuccessful
	# Updating backup state (error)
	./steps/backups/updatestatus.sh $BACKUPID "error"
	echo `date "+%Y%m%d_%H%M%S"` "-- Start of failed backup log"
	cat /tmp/backup.log.$$
	echo End of failed backup log
	rm -f /tmp/backup.log.$$
fi

# Returning unix return code
exit $bkstatus
