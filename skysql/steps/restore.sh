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
# This script is executed by NodeCommand.sh to start the restore process.
#
# Parameters:
# $1: Backup ID

if [ $# -lt 1 ] ; then
    echo "ERROR :" `date "+%Y%m%d_%H%M%S"` "-- Usage: $0 '<backup id>'"
    exit 1
fi

echo "INFO :" `date "+%Y%m%d_%H%M%S"` "-- Command start: restore"
echo "INFO :" `date "+%Y%m%d_%H%M%S"` "-- params: backup_id $1"

# Setting the state of the command to running
./restfulapi-call.sh "PUT" "task/$taskid" "state=running" > /dev/null

export BACKUPID=$1

backupfilename=`ls -1 $backups_path | grep -s Backup.$BACKUPID\$`
if [[ "$backupfilename" == Full* ]] ; then
    ./steps/backups/fullrestore.sh
else
   ./steps/backups/incrrestore.sh
fi

rststatus=$?
exit $rststatus
