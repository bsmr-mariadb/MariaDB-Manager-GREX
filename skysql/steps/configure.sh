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
# This script does the necessary configuration steps to have the node ready for
# command execution.
#

echo "INFO :" `date "+%Y%m%d_%H%M%S"` "-- Command start: configure"

# Creating MariaDB configuration file
hostname=`uname -n`
sed -e "s/###NODE-ADDRESS###/$privateip/" \
	-e "s/###REP-USERNAME###/$rep_username/" \
	-e "s/###REP-PASSWORD###/$rep_password/" \
	steps/conf_files/skysql-galera.cnf > /etc/my.cnf.d/skysql-galera.cnf

# Setting up MariaDB users
/etc/init.d/mysql start

sleep 5

mysql -u root -e "DELETE FROM mysql.user WHERE user = ''; \
GRANT ALL PRIVILEGES ON *.* TO $rep_username@'%' IDENTIFIED BY '$rep_password'; \
GRANT ALL PRIVILEGES ON *.* TO $db_username@'%' IDENTIFIED BY '$db_password'; \
GRANT ALL PRIVILEGES ON *.* TO root@'%' IDENTIFIED BY 'sky' WITH GRANT OPTION; \
FLUSH PRIVILEGES;"

/etc/init.d/mysql stop

# Updating node state
./restfulapi-call.sh "PUT" "system/$system_id/node/$node_id" "state=provisioned"