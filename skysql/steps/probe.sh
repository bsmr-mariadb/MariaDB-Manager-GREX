#!/bin/bash
#
# This file is distributed as part of MariaDB Manager.  It is free
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
# Copyright 2012-2014 SkySQL Corporation Ab
#
# Author: Marcos Amaral
# Date: October 2013
#
#
# This script looks for current MySQL/MariaDB installations and updates node state
# accordingly.
#

logger -p user.info -t MariaDB-Manager-Remote "Command start: probe"

mysqld_found=false
mysqld_comp=false
rpm_installed=false
mysql_port_busy=false
new_state='unprovisioned'

# Checking for mysqld on PATH directories
version_output=$(mysqld --version)
if [[ $? == 0 ]]; then
	mysqld_found=true
	echo $version_output | grep "MariaDB.*wsrep"
	if [[ $? == 0 ]]; then
		logger -p user.info -t MariaDB-Manager-Remote \
			"Probe: A MySQL configuration with the Galera replicator has been detected."
		mysqld_comp=true
	fi	
fi

# Checking for MariaDB/Galera installation on rpm
rpm -qa | grep MariaDB-Galera
if [[ $? == 0 ]]; then
	logger -p user.info -t MariaDB-Manager-Remote \
		"Probe: The MariaDB-Galera RPM package is already installed."
	rpm_installed=true
fi

# Checking if port 3306 is busy
netstat -a | egrep -is "^tcp.*(3306)|(mysql) *LISTEN"
if [[ $? == 0 ]]; then
	mysql_port_busy=true
	logger -p user.info -t MariaDB-Manager-Remote "Probe: A listener already exists on the MySQL port."
fi

# Determining next state
if $mysqld_found ; then
	if $mysqld_comp ; then
		new_state='provisioned'
		logger -p user.info -t MariaDB-Manager-Remote \
			"Probe: A compatible MySQL installation detected."
	else
		new_state='incompatible'
		logger -p user.info -t MariaDB-Manager-Remote \
			"Probe: An incompatible MySQL installation detected."
	fi
elif $rpm_installed ; then
	new_state='provisioned'
elif $mysql_port_busy ; then
	new_state='incompatible'
fi

# Updating node state
state_json=$(api_call "PUT" "system/$system_id/node/$node_id" "state=$new_state")
if [[ $? != 0 ]] ; then
        set_error "Failed to set the node state to $new_state."
        logger -p user.error -t MariaDB-Manager-Remote "Failed to set the node state to $new_state."
        exit 1
fi
json_error "$state_json"
if [[ "$json_err" != "0" ]]; then
        set_error "Failed to set the node state to $new_state."
        logger -p user.error -t MariaDB-Manager-Remote "Failed to set the node state to $new_state."
        exit 1
fi
