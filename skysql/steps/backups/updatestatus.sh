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
# This script is executed by the backup scripts to update a Backup record on the
# Manager database
#
# Parameters:
# $1 The ID of the backup to be updated
# $2 The new state for the backup
#

. ./restfulapicredentials.sh

if [[ $# -lt 2 ]] ; then
	echo $Usage: $0 '<Backup ID>' '<State>' '[size=<size>]|[storage=<path>]|[binlog=<binlog>]|[log=<Log URL>]'
	exit
fi
backupid=$1

data=( "state=$2" )
shift 2
while [[ $# -gt 0 ]] ; do
	data+=("$1")
	shift
done

request_uri="system/$system_id/backup/$backupid"

api_response=$(api_call "PUT" "$request_uri" "${data[@]}")
echo $api_response > /tmp/mookie.log
