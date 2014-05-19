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
# Author: Massimo Siani
# Date: July 2013
#
#
# This script is executed by NodeCommand.sh to start the backup process.
#
# Parameters:
# type: Backup type: 1 (Full) or 2 (Incremental)
# parent: Base BackupID (only required if type = 2)

logger -p user.info -t MariaDB-Manager-Remote "Command start: backup"

# Parameter parsing and validation
[[ "x$params" != "x" ]] && set $params
while [[ $# > 0 ]]; do
        param_name="${1%%=*}"
        param_value="${1#*=}"

        if [[ "$param_name" == "type" ]]; then
                level="$param_value"
        fi
        if [[ "$param_name" == "parent" ]]; then
                parent="$param_value"
        fi

        shift
done

if [[ -z "$level" ]] ; then
        logger -p user.error -t MariaDB-Manager-Remote "$0 invoked with no backup type parameter"
        set_error "Required 'type' parameter missing."
        exit 1
fi
if [[ "$level" -eq 2 ]]; then
        if [[ -z "$parent" ]] ; then
                logger -p user.error -t MariaDB-Manager-Remote "Missing parent backup ID for incremental backup."
                set_error "Missing parent backup ID for incremental backup."
                exit 1
        else
                export BASEBACKUPID="$parent"
        fi
elif [[ "$level" -ne 1 ]]; then
        logger -p user.error -t MariaDB-Manager-Remote "Invalid backup type value for backup step."
        set_error "Invalid value for parameter 'type'."
        exit 1
fi

# Setting the state of the command to running
api_call "PUT" "task/$taskid" "state=running"

. ./mysql-config.sh

# Making an API call to create the Backup record on the DB, defining BACKUPID
. ./steps/backups/createbackup.sh

# Setting the backup state to 'scheduled'
./steps/backups/updatestatus.sh "$BACKUPID" "scheduled"

filename="bkp_${BACKUPID}_sys_${system_id}_node_${node_id}"

if [[ "$level" -eq 2 ]] ; then
	filename="${filename}_parent_${BASEBACKUPID}"
fi

time=$(date +"%Y_%m_%d_%H_%M")
filename="${filename}_t_${time}"
export backup_filename="$filename.bkp"
log_filename="$filename.log"

if [[ "$level" -eq 1 ]] ; then
	./steps/backups/fullbackup.sh > /tmp/backup.log.$$
	bkstatus=$?
elif [[ "$level" -eq 2 ]] ; then
	./steps/backups/incrbackup.sh > /tmp/backup.log.$$
	bkstatus=$?
	backupfilename="IncrBackup.$BACKUPID"
fi

#binlogpos=$(grep binlog /tmp/backup.log.$$ | awk '{ printf("%s%s\n", $6, $8); }' | sed -e s/\'//g)
incr_lsn=$(grep 'latest check point (for incremental):' /tmp/backup.log.$$ | awk '{ printf("%s\n", $8); }' | sed -e s/\'//g)
size=$(du -k "$backups_remotepath/$backup_filename" | awk '{ print $1 }')

if [[ "$bkstatus" -eq 0 ]] ; then # Backup successful
	# Updating backup state (completed) and other data on the DB
	if [[ "$level" -eq 1 ]] ; then
		./steps/backups/updatestatus.sh "$BACKUPID" "done" \
			size="$size" \
			backupurl="$filename" \
			binlog="$incr_lsn" \
			log="$log_filename"
	elif [[ "$level" -eq 2 ]] ; then
		./steps/backups/updatestatus.sh "$BACKUPID" "done" \
			size="$size" \
                        backupurl="$filename" \
                        binlog="$incr_lsn" \
			log="$log_filename" \
			parent="$BASEBACKUPID"
	fi

	# Putting the log in place
	mv /tmp/backup.log.$$ "$backups_remotepath/$log_filename"
else # Backup unsuccessful
	# Updating backup state (error)
	./steps/backups/updatestatus.sh $BACKUPID "error"
	set_error "Error creating backup from database."
	logger -p user.error -t MariaDB-Manager-Remote "Start of failed backup log:"
	logger -p user.error -t MariaDB-Manager-Remote "$(cat /tmp/backup.log.$$)"
	logger -p user.error -t MariaDB-Manager-Remote "End of failed backup log"
	rm -f /tmp/backup.log.$$
fi

cur=$(pwd)
cd "$backups_remotepath"
tar czvf "${filename}.tgz" "${backup_filename}" "${log_filename}"
rm -f "${backup_filename}" "${log_filename}"
chown skysqlagent:skysqlagent "${filename}.tgz"
cd $cur

# Returning unix return code
exit $bkstatus
