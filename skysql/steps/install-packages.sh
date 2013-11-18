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
# Date: October 2013
#
#
# This script installs the necessary MariaDB/Galera packages.
#

logger -p user.info -t MariaDB-Manager-Remote "Command start: install-packages"

# Installing MariaDB packages
yum -y clean all
yum -y install MariaDB-Galera-server MariaDB-client --disablerepo=* --enablerepo=skysql

# Checking if packages were correctly installed
rpm -q MariaDB-Galera-server MariaDB-client
rpm_q_status=$?

if [[ "$rpm_q_status" != "0" ]]; then
	set_error "Error installing MariaDB packages."
	logger -p user.error -t MariaDB-Manager-Remote "Error installing MariaDB packages."
	exit $rpm_q_status
fi

exit 0
