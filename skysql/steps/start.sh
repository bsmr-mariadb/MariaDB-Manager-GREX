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

echo $(date "+%Y%m%d_%H%M%S") "-- Command start: start"

# Setting the state of the command to running
api_call "PUT" "task/$taskid" "state=running"

# Getting the IP of an online node
cluster_online_ip=$(get_online_node)

if [[ -n "$cluster_online_ip" ]]; then
        /etc/init.d/mysql start --wsrep-cluster-address=gcomm://$cluster_online_ip:4567
	start_status=$?
else # Starting a new cluster
	/etc/init.d/mysql start --wsrep-cluster-address=gcomm://
	start_status=$?
fi

if [[ $start_status != 0 ]]; then
	echo $(date "+%Y%m%d_%H%M%S") "MariaDB start returned failure"
	set_error "MariaDB start command failed."
	exit $start_status
fi

$(wait_for_state "joined")
if [[ $? -eq 0 ]]; then
	echo "INFO :" $(date "+%Y%m%d_%H%M%S") "-- Command finished successfully"
else
	set_error "Timeout waiting for node to start."
	echo $(date "+%Y%m%d_%H%M%S") "-- Command finished with an error: node state not OK"
	exit 1
fi
