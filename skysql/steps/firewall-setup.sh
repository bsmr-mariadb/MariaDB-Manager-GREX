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
# Author: Mark Riddoch
# Date: October 2013
#
#
# This script setups up the iptables firewall rules for MariaDB/Galera
# and disables selinux or AppArmor if they are installed
#

echo "Command start: firewall-setup"

# Check if the iptables command is avialable
which iptables > /dev/null 2>&1
if [ $? == 0 ]; then
	iptables -A INPUT -p tcp -m tcp --dport 3306 -j ACCEPT

	# Only open the Galera poer 4567 to the network that is used
	# to communicate with the api_host - this is likely to be the
	# private network used for the Galera nodes to communicate

	dev=`ip route get "$api_host" | awk '$2 == "dev" { print $3 } $4 == "dev" { print $5 }'`
	if [ x"$dev" == "x" ]; then
		iptables -A INPUT -p tcp -m tcp --dport 4567 -j ACCEPT
		logger -p user.warning -t MariaDB-Enterprise-Remote \
			"Unable to determine network device - opening Galera port to the world"
	else
		address=`ip addr show $dev | awk '$1 == "inet" { print $2 }'`

		iptables -A INPUT -p tcp -m tcp --dport 4567 -s "$address" -j ACCEPT
		service iptables save
	fi

	logger -p user.info -t MariaDB-Enterprise-Remote "Updated iptables rules"

fi

# Disable selinux
if [ -d /etc/selinux ]; then
	setenforce 0
	sed -e 's/SELINUX=.*/SELINUX=permissive/' < /etc/selinux/config \
		> /tmp/selinux_config \
		&& mv /tmp/selinux_config /etc/selinux/config

	logger -p user.info -t MariaDB-Enterprise-Remote "Disabled selinux"
fi

# Check for AppArmor and enable mysql
if [ -d /etc/apparmor.d ]; then
	ln -s /etc/apparmor.d/usr.sbin.mysqld /etc/apparmor.s/disable/usr.sbin.mysqld
	service apparmor restart
	logger -p user.info -t MariaDB-Enterprise-Remote "Disabled MySQL in AppAmor"
fi

exit 0
