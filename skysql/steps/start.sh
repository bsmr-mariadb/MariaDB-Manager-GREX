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
# This script is executed by NodeCommand.sh to start mysqld and establish a connection
# with the rest of the cluster (if there are any nodes online).
#

. ./remote-scripts-config.sh

echo `date "+%Y%m%d_%H%M%S"` "-- Command start: start"

# Setting the state of the command to running
./restfulapi-call.sh "PUT" "task/$taskid" "state=running" > /dev/null

# Getting the IP of an online node
cluster_online_ip=`./get-online-node.sh`

if [ -n "$cluster_online_ip" ]; then
        /etc/init.d/mysql start --wsrep-cluster-address=gcomm://$cluster_online_ip:4567
else # Starting a new cluster
	/etc/init.d/mysql start --wsrep-cluster-address=gcomm://
fi

no_retries=$state_wait_retries
while [ "$no_retries" -gt 0 ]
do
        sleep 1
        node_state=`./get-node-state.sh`
        if [[ "$node_state" == "joined" ]]; then
                echo "INFO :" `date "+%Y%m%d_%H%M%S"` "-- Command finished successfully"
                exit 0
        fi
        no_retries=$((no_retries - 1))
done
./restfulapi-call.sh "PUT" "task/$taskid" "errormessage=Timeout waiting for node to start"
echo `date "+%Y%m%d_%H%M%S"` "-- Command finished with an error: node state not OK"
exit 1

