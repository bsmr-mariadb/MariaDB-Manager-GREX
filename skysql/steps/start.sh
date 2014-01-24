#!/bin/bash
#
# This file is distributed as part of the MariaDB Enterprise.  It is free
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
# Copyright 2012-2014 SkySQL Ab
#
# Author: Marcos Amaral
# Date: July 2013
#
#
# This script is executed by NodeCommand.sh to start mysqld and establish a connection
# with the rest of the cluster (if there are any nodes online).
#

. ./remote-scripts-config.sh

logger -p user.info -t MariaDB-Manager-Remote "Command start: start"

# Setting the state of the command to running
api_call "PUT" "task/$taskid" "state=running"

# Getting the IP of an online node
cluster_online_ip=$(get_online_node)

if [[ "$cluster_online_ip" != "null" ]]; then
        /etc/init.d/mysql start --wsrep-cluster-address=gcomm://$cluster_online_ip:4567
	start_status=$?
else # Starting a new cluster
	/etc/init.d/mysql start --wsrep-cluster-address=gcomm://
	start_status=$?
fi

if [[ $start_status != 0 ]]; then
	logger -p user.error -t MariaDB-Manager-Remote "MariaDB start returned failure."
	set_error "MariaDB start command failed."
	exit $start_status
fi

$(wait_for_state "joined")
if [[ $? -eq 0 ]]; then
	logger -p user.info -t MariaDB-Manager-Remote "Command finished successfully"
else
	set_error "Timeout waiting for node to start."
	logger -p user.error -t MariaDB-Manager-Remote "Command finished with an error: node state not OK"
	exit 1
fi
