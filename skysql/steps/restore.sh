#!/bin/bash
#
# This file is distributed as part of the MariaDB Enterprise.  It is free
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
# Copyright 2012-2014 SkySQL Ab
#
# Author: Marcos Amaral
# Date: July 2013
#
#
# This script is executed by NodeCommand.sh to start the restore process.
#
# Parameters:
# id: Backup ID

logger -p user.info -t MariaDB-Manager-Remote "Command start: restore"

# Parameter parsing and validation
set $params
while [[ $# > 0 ]]; do
        param_name="${1%%=*}"
        param_value="${1#*=}"

        if [[ "$param_name" == "id" ]]; then
                id="$param_value"
        fi

        shift
done

if [[ -z "$id" ]] ; then
        logger -p user.error -t MariaDB-Manager-Remote "$0 invoked with no backup id parameter"
        set_error "Required 'id' parameter missing."
        exit 1
fi

# Setting the state of the command to running
api_call "PUT" "task/$taskid" "state=running"

. ./mysql-config.sh

export BACKUPID="$id"

backupfilename=( "$backups_path"/*Backup."$BACKUPID" )
if (( "${#backupfilename[@]}" == 0 )) || [[ ! -f "${backupfilename[0]}" ]] ; then 
        logger -p user.error -t MariaDB-Manager-Remote "Target backup file not found."
elif (( "${#backupfilename[@]}" > 1 )); then
        logger -p user.error -t MariaDB-Manager-Remote "Multiple files found for the same backup ID: $BACKUPID"
else
        backupfilename="${backupfilename[0]##*/}"
fi

if [[ "$backupfilename" == Full* ]] ; then
   ./steps/backups/fullrestore.sh
   restorestatus=$?
else
   ./steps/backups/incrrestore.sh
   restorestatus=$?
fi

time=$(date +%s)
if [[ "$restorestatus" -eq 0 ]]; then
    ./steps/backups/updatestatus.sh "$BACKUPID" "done" restored="@$time"
fi

exit $restorestatus
