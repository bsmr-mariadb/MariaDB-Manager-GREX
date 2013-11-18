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

. ./remote-scripts-config.sh

logger -p user.info -t MariaDB-Manager-Remote "Command start: recover"

# Setting the state of the command to running
api_call "PUT" "task/$taskid" "state=running"

# Getting the IP of an online node
cluster_online_ip=$(get_online_node)

if [[ -n $cluster_online_ip ]]; then
	# Finding the Galera wsrep library
	if [[ -f /usr/lib/galera/libgalera_smm.so ]]; then
		mysql -u $db_username -p$db_password -e \
			"SET GLOBAL wsrep_provider='/usr/lib/galera/libgalera_smm.so';"
	elif [[ -f /usr/lib64/galera/libgalera_smm.so ]]; then
		mysql -u $db_username -p$db_password -e \
			"SET GLOBAL wsrep_provider='/usr/lib64/galera/libgalera_smm.so';"
	else
		logger -p user.error -t MariaDB-Manager-Remote "No Galera wsrep library found."
		set_error "Failed to find Galera wsrep library."
		exit 1
	fi

	mysql -u $db_username -p$db_password -e \
		"SET GLOBAL wsrep_cluster_address='gcomm://$cluster_online_ip:4567';"
else
	logger -p user.error -t MariaDB-Manager-Remote "No active cluster to rejoin."
	set_error "No active cluster to join."
	exit 1
fi

$(wait_for_state "joined")
if [[ $? -eq 0 ]]; then
	logger -p user.info -t MariaDB-Manager-Remote "Command finished successfully"
else
	logger -p user.error -t MariaDB-Manager-Remote "Command finished with an error: node state not OK"
	set_error "Timeout waiting for node to join the cluster."
	exit 1
fi
