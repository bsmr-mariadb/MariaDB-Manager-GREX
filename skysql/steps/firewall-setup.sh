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
if [[ $? == 0 ]]; then

	# Only open the Galera ports 4444, 4567, 4568 to the network
	# that are used to communicate with the api_host - this is likely
	# to be the private network used for the Galera nodes to communicate
	#
	# Open port 3306 to all networks as we do not know where clients
	# will connect from

	dev=$(ip route get "$api_host" | awk '$2 == "dev" { print $3 } $4 == "dev" { print $5 }')
	if [[ x"$dev" == "x" ]]; then
		iptables -I INPUT -p tcp -m tcp --dport 4567 -j ACCEPT
		iptables -I INPUT -p tcp -m tcp --dport 4568 -j ACCEPT
		iptables -I INPUT -p tcp -m tcp --dport 4444 -j ACCEPT
		iptables -I INPUT -p tcp -m tcp --dport 3306 -j ACCEPT
		iptables -I INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
		iptables -I INPUT -p tcp --dport 3306 -j ACCEPT -m state --state NEW
		logger -p user.warning -t MariaDB-Manager-Remote \
			"Unable to determine network device - opening Galera port to the world"
	else
		iptables -I INPUT -i "$dev" -p tcp -m tcp --dport 4567 -j ACCEPT
		iptables -I INPUT -i "$dev" -p tcp -m tcp --dport 4568 -j ACCEPT
		iptables -I INPUT -i "$dev" -p tcp -m tcp --dport 4444 -j ACCEPT
		iptables -I INPUT -i "$dev" -p tcp -m tcp --dport 3306 -j ACCEPT
		iptables -I INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
		iptables -I INPUT -p tcp --dport 3306 -j ACCEPT -m state --state NEW
	fi
	service iptables save
	# Restart iptables if it is already running
	if service iptables status > /dev/null ; then
		service iptables restart
	fi

	logger -p user.info -t MariaDB-Manager-Remote "Updated iptables rules"

fi

# Disable selinux
if [[ -d /etc/selinux ]]; then
	setenforce 0
	sed -e 's/SELINUX=.*/SELINUX=permissive/' < /etc/selinux/config \
		> /tmp/selinux_config \
		&& mv /tmp/selinux_config /etc/selinux/config

	logger -p user.info -t MariaDB-Manager-Remote "Disabled selinux"
fi

# Check for AppArmor and enable mysql
if [[ -d /etc/apparmor.d ]]; then
	ln -s /etc/apparmor.d/usr.sbin.mysqld /etc/apparmor.d/disable/usr.sbin.mysqld
	service apparmor restart
	logger -p user.info -t MariaDB-Manager-Remote "Disabled MySQL in AppAmor"
fi

exit 0
