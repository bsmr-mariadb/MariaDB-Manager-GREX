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
# This script is executed by NodeCommand.sh to make a node rejoin the cluster (from
# an isolated state) by re-enabling the Galera library and establishing a connection
# with an online node of the cluster.
#

. ./mysql-config.sh

echo "-- Command start: recover"

no_retries=120
while [ $no_retries -gt 0 ]
do
        cur_commands=`./get-current-commands.sh`
        if [[ "$cur_commands" == "0" ]]; then
                break
        fi
        sleep 1
        no_retries=$((no_retries - 1))
done

if [ $no_retries -eq 0 ]; then
        echo "-- Command aborted: system busy with other commands"
        exit 1
fi

# Setting the state of the command to running
./restfulapi-call.sh "PUT" "task/$taskid" "state=2" > /dev/null

# Getting the IP of an online node
cluster_online_ip=`./get-online-node.sh`

if [ -n $cluster_online_ip ]; then
	# Finding the Galera wsrep library
	if [ -f /usr/lib/galera/libgalera_smm.so ]; then
		mysql -u $mysql_user -p$mysql_pwd -e "SET GLOBAL wsrep_provider='/usr/lib/galera/libgalera_smm.so';"
	elif [ -f /usr/lib64/galera/libgalera_smm.so ]; then
		mysql -u $mysql_user -p$mysql_pwd -e "SET GLOBAL wsrep_provider='/usr/lib64/galera/libgalera_smm.so';"
	else
		echo "Error: no Galera wsrep library found."
		exit 1
	fi

	mysql -u $mysql_user -p$mysql_pwd -e "SET GLOBAL wsrep_cluster_address='gcomm://$cluster_online_ip:4567';"
else
	echo "Error: no active cluster to rejoin."
	exit 1
fi

no_retries=30
while [ $no_retries -gt 0 ]
do
        sleep 1
        node_state=`./get-node-state.sh`
        if [[ "$node_state" == "104" ]]; then
                echo "-- Command finished successfully"
                exit 0
        fi
        no_retries=$((no_retries - 1))
done
echo "-- Command finished with an error: node state not OK"
exit 1

