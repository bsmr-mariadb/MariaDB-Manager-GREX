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
# This script is executed by NodeCommand.sh to start the restore process.
#
# Parameters:
# $1: Backup ID

if [[ $# -lt 1 ]] ; then
    echo $(date "+%Y%m%d_%H%M%S") "-- Usage: $0 '<backup id>'"
    exit 1
fi

logger -p user.info -t MariaDB-Manager-Remote "Command start: restore"

# Setting the state of the command to running
api_call "PUT" "task/$taskid" "state=running"

. ./mysql-config.sh

export BACKUPID="$1"

backup_json=$(api_call "GET" "system/$system_id/backup/$BACKUPID" "fields=level")
level=$(jq -r '.backup | .level' <<<"$backup_json")

if [[ "$level" == "1" ]] ; then
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
