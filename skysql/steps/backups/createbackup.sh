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
# This script is executed by the backup scripts to create the Backup record on the
# Manager DB and returns the BackupID
#

# Validation
if [ "$system_id" = "" ] ; then
	echo '$0: Expected to be called with system_id variable set'
	exit 1
fi
if [ "$node_id" = "" ] ; then
	echo '$0: Expected to be called with node_id variable set'
	exit 1
fi
if [ "$level" = "" ] ; then
        echo '$0: Expected to be called with level variable set'
        exit 1
fi
if [ $level -eq 2 ] && [ "$BASEBACKUPID" = "" ] ; then
	echo '$0: Expected to be called with BASEBACKUPID variable set when level is 2 (incremental)'
	exit 1
fi	

# Building the data parameter with the API call-specific arguments
start_date=`date +"%Y-%m-%d %H:%M:%S"`
data="systemid=$system_id&node=$node_id&level=$level&started=$start_date"
if [ $level -eq 2 ] ; then
        data="$data&parentid=$BASEBACKUPID"
fi

request_uri="system/$system_id/backup"

api_response=`./restfulapi-call.sh "POST" $request_uri "$data"`

# Parsing API response and setting BACKUPID for the invoking script
export BACKUPID=`echo $api_response | sed 's|[{}]||g' | 
	awk 'BEGIN { RS=","; FS=":" } { gsub("\"", "", $0); if ($1 == "insertkey") print $2; }'`
