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
# Copyright 2014 SkySQL Corporation Ab
#
# Author: Massimo Siani
# Date: May 2014

. ./remote-scripts-config.sh

logger -p user.info -t MariaDB-Manager-Remote "Command start: upgrade"

#Setting the state of the command to running
api_call "PUT" "task/$taskid" "state=running"

latestVersion="MariaDB-Manager-GREX-0.4-63"
latestScriptRelease="1.0.2"
rpm -qa | grep $latestVersion
if [[ "$?" == "0" ]] ; then
	api_call "PUT" "system/$system_id/node/$node_id" "scriptrelease=$latestScriptRelease"
else
	yum clean all
	yum -y update MariaDB-Manager-GREX
	rpm -qa | grep $latestVersion
	if [[ "$?" == "0" ]] ; then
		logger -p user.info -t MariaDB-Manager-Remote "Remote scripts updated to version $latestVersion"
		api_call "PUT" "system/$system_id/node/$node_id" "scriptrelease=$latestScriptRelease"
	else
		errorMessage="Cannot update MariaDB-Manager-GREX, check that MariaDB-Manager-API and MariaDB-Manager-internalrepo on the Manager Node are updated to the latest version"
		logger -p user.error -t MariaDB-Manager-Remote "$errorMessage"
		set_error "$errorMessage"
		exit 1
	fi
fi

exit 0
