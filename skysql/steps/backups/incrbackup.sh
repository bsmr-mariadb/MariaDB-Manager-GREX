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
# This script creates an incremental backup on the configurated directory
#

TMPFILE="/tmp/innobackupex-runner.$$.tmp"
if [[ -z "$db_password" ]]; then
        USEROPTIONS="--user=$db_username"

else
        USEROPTIONS="--user=$db_username --password=$db_password"
fi

# Checking if backup tool exists
if [[ ! -x $(which innobackupex) ]]; then
	echo "ERROR :" $(date "+%Y%m%d_%H%M%S") "-- 'innobackupex' command does not exist."
	exit 1
fi

# Checking if the script can access the database
if ! $(echo 'exit' | /usr/bin/mysql -s $USEROPTIONS) ; then
	echo "ERROR :" $(date "+%Y%m%d_%H%M%S") "-- Supplied mysql username or password appears to be incorrect."
	exit 1
fi

# Getting the position for the base backup
INCRLSN=$BASEBACKUPID
#INCRLSN=$(grep 'latest check point (for incremental):' "$backups_remotepath/Log." | awk '{ printf("%s\n", $8); }' | sed -e s/\'//g)

# Generating the backup file
innobackupex $USEROPTIONS --defaults-file="$my_cnf_file" --incremental --incremental-lsn="$INCRLSN" --stream=xbstream ./ > "$backups_remotepath/$backup_filename" 2> $TMPFILE

if [[ -z "$(tail -1 $TMPFILE | grep 'completed OK!')" ]] ; then
	echo "ERROR :" $(date "+%Y%m%d_%H%M%S") "-- innobackupex failed:"; echo
	echo "---------- ERROR OUTPUT from innobackupex ----------"
	cat $TMPFILE
	rm -f $TMPFILE
	exit 1
else
	cat $TMPFILE
fi

exit 0
