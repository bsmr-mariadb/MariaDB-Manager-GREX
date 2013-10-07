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
# This script looks for current MySQL/MariaDB installations and updates node state
# accordingly.
#

echo "INFO :" `date "+%Y%m%d_%H%M%S"` "-- Command start: probe"

mysqld_found=false
mysqld_comp=false
rpm_installed=false
mysql_port_busy=false
new_state='unprovisioned'

# Checking for mysqld on PATH directories
version_output=`mysqld --version`
if [ $? == 0 ]; then
	mysqld_found=true
	echo $version_output | grep MariaDB.*wsrep
	if [ $? == 0 ]; then
		mysqld_comp=true
	fi	
fi

# Checking for MariaDB/Galera installation on rpm
rpm -qa | grep MariaDB-Galera
if [ $? == 0 ]; then
	rpm_installed=true
fi

# Checking if port 3306 is busy
lsof -i -n -P | grep "TCP .*:3306 (LISTEN)"
if [ $? == 0 ]; then
	mysql_port_busy=true
fi

# Determining next state
if $mysqld_found ; then
	if $mysqld_comp ; then
		new_state='provisioned'
	else
		new_state='incompatible'
	fi
elif $rpm_installed ; then
	new_state='provisioned'
elif $mysql_port_busy ; then
	new_state='incompatible'
fi

# Updating node state
./restfulapi-call.sh "PUT" "system/$system_id/node/$node_id" "state=$new_state"
