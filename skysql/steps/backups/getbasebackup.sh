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
# This script is executed by the restore scripts to get the base BackupID of an
# incremental backup
#

request_uri="system/$system_id/backup/$BACKUPID"

api_response=`./restfulapi-call.sh GET "$request_uri"`
export BASEBACKUPID=`echo $api_response | sed 's|.*"backup":\[{||' | sed 's|}\]}||' | 
	awk 'BEGIN { RS=","; FS=":"; } { gsub ("\"", "", $0); if ($1 == "parent") print $2; }'`
