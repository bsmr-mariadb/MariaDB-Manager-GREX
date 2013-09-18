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
# This script returns the current SkySQL Manager state of the current node
#

. ./restfulapicredentials.sh

api_ret=`./restfulapi-call.sh "GET" "system/$scds_system_id/node/$scds_node_id" "fields=state" \
	| sed 's|^{"node":{||' | sed 's|}}$||'`

sys_state=`echo $api_ret | awk 'BEGIN { FS=":" } /\"state\"/ {
	gsub("\"", "", $0);
	if ($1 == "state") print $2; }'`
echo $sys_state
