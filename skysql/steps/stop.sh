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
# Date: July 2013
#
#
# This script is executed by NodeCommand.sh to terminate mysqld.
#

. ./remote-scripts-config.sh

logger -p user.info -t MariaDB-Manager-Remote "Command start: stop"

# Setting the state of the command to running
api_call "PUT" "task/$taskid" "state=running"

/etc/init.d/mysql stop
stop_status=$?
if [[ "$stop_status" != 0 ]]; then
	logger -p user.error -t MariaDB-Manager-Remote "MariaDB stop returned failure"
	set_error "MariaDB stop command failed."
	exit $stop_status
fi

$(wait_for_state "down")
if [[ $? -eq 0 ]]; then
	logger -p user.info -t MariaDB-Manager-Remote "Command finished successfully"
else
	set_error "Timeout waiting for node to stop."
	logger -p user.error -t MariaDB-Manager-Remote "Command finished with an error: node state not OK"
	exit 1
fi
