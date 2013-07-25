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
# This script is executed by NodeCommand.sh to isolate a node from the cluster
# by disabling the Galera library.
#

. ./mysql-config.sh

echo "-- Command start: isolate"

while true
do
        cur_commands=`./get-current-commands.sh`
        if [[ "$cur_commands" == "0" ]]; then
                break
        fi
        echo "Command running"
        sleep 1
done

# Setting the state of the command to running
./restfulapi-call.sh "PUT" "task/$taskid" "state=2"

mysql -u $mysql_user -p$mysql_pwd -e "SET GLOBAL wsrep_provider=none; SET GLOBAL wsrep_cluster_address='gcomm://';"

no_retries=0
while [ $no_retries -lt 30 ]
do
	sleep 1
	node_state=`./get-node-state.sh`
	if [[ "$node_state" == "107" ]]; then
		echo "-- Command finished: success"
		exit 0
	fi
	no_retries=$((no_retries + 1))
done
echo "-- Command finished: error"
exit 1
