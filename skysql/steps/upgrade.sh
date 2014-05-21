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
. ./mysql-config.sh
mkdir -p $backups_remotepath
chown skysqlagent:skysqlagent $backups_remotepath

packageAPI="MariaDB-Manager-API"
packageRepo="MariaDB-Manager-internalrepo"
packageName="MariaDB-Manager-GREX"
toBeScriptRelease=$(api_call "GET" "system/0/node/0/component/api" "fieldselect=apiproperties~release" 2>/dev/null)
scriptRelease=$(cat GREX-release 2>/dev/null)

if [[ "x$scriptRelease" == "x$toBeScriptRelease" ]] ; then
	api_call "PUT" "system/$system_id/node/$node_id" "scriptrelease=$scriptRelease"
	exit 0
fi

logger -p user.info -t MariaDB-Manager-Remote "Command start: upgrade"

#Setting the state of the command to running
api_call "PUT" "task/$taskid" "state=running"

if [[ "$linux_name" == "CentOS" ]] ; then
	cmd_clean="yum clean all"
	cmd_update="yum -y update $packageName MariaDB-Galera-server galera --disablerepo=* --enablerepo=MariaDB-Manager"
elif [[ "$linux_name" == "Debian" || "$linux_name" == "Ubuntu" ]] ; then
	cmd_clean="aptitude update"
	cmd_update="aptitude -y safe-upgrade $packageName mariadb-galera-server galera"
fi

$cmd_clean &>/dev/null
$cmd_update &>/dev/null
scriptRelease=$(cat GREX-release 2>/dev/null)
if [[ "x$scriptRelease" == "x" ]] ; then
	logger -p user.warn -t MariaDB-Manager-Remote "Cannot determine the GREX release: further errors may be logged"
fi
if [[ "x$scriptRelease" == "x$toBeScriptRelease" ]] ; then
	logger -p user.info -t MariaDB-Manager-Remote "Remote scripts updated to release $scriptRelease"
	api_call "PUT" "system/$system_id/node/$node_id" "scriptrelease=$scriptRelease"
else
	errorMessage="Cannot update $packageName, check that $packageAPI and $packageRepo on the Manager Node are updated to release $scriptRelease"
	logger -p user.error -t MariaDB-Manager-Remote "$errorMessage"
	set_error "$errorMessage"
	exit 1
fi

cmd_logger_info "Command end: upgrade"

exit 0
