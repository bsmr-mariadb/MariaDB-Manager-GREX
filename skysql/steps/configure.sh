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
# This script does the necessary configuration steps to have the node ready for
# command execution.
#

logger -p user.info -t MariaDB-Manager-Remote "Command start: configure"

trap cleanup SIGTERM
cleanup() {
        if [[ -f /etc/my.cnf.d/skysql-galera.cnf ]]; then
                rm -f /etc/my.cnf.d/skysql-galera.cnf
        fi
        exit 1
}

# Determining path of galera library
if [[ -f /usr/lib/galera/libgalera_smm.so ]]; then
	galera_lib_path="/usr/lib/galera/libgalera_smm.so"
elif [[ -f /usr/lib64/galera/libgalera_smm.so ]]; then
	galera_lib_path="/usr/lib64/galera/libgalera_smm.so"
else
	logger -p user.error -t MariaDB-Manager-Remote "No Galera wsrep library found."
	set_error "Failed to find Galera wsrep library."
	exit 1
fi

# Creating MariaDB configuration file
hostname=$(uname -n)
if [[ "$linux_name" == "CentOS" ]]; then
        sed -e "s/###NODE-ADDRESS###/$privateip/g" \
                -e "s/###NODE-NAME###/$nodename/g" \
                -e "s/###REP-USERNAME###/$rep_username/g" \
                -e "s/###REP-PASSWORD###/$rep_password/g" \
                -e "s|###GALERA-LIB-PATH###|$galera_lib_path|g" \
                steps/conf_files/skysql-galera.cnf > /etc/my.cnf.d/skysql-galera.cnf

	if [[ ! -s /etc/my.cnf.d/skysql-galera.cnf ]]; then
        	logger -p user.error -t MariaDB-Manager-Remote "Error generating galera configuration file."
	        set_error "Error generating galera configuration file"
        	exit 1
	fi
elif [[ "$linux_name" == "Debian" || "$linux_name" == "Ubuntu" ]]; then
        echo "!includedir /etc/mysql/conf.d/" > /etc/mysql/my.cnf
        sed -e "s/###NODE-ADDRESS###/$privateip/g" \
                -e "s/###NODE-NAME###/$nodename/g" \
                -e "s/###REP-USERNAME###/$rep_username/g" \
                -e "s/###REP-PASSWORD###/$rep_password/g" \
                -e "s|###GALERA-LIB-PATH###|$galera_lib_path|g" \
                steps/conf_files/skysql-galera.cnf > /etc/mysql/conf.d/skysql-galera.cnf

	if [[ ! -s /etc/mysql/conf.d/skysql-galera.cnf ]]; then
	        logger -p user.error -t MariaDB-Manager-Remote "Error generating galera configuration file."
        	set_error "Error generating galera configuration file"
	        exit 1
	fi
fi

# Setting up MariaDB users
/etc/init.d/mysql start --wsrep-cluster-address=gcomm://

sleep 5

# Debian only: copy the debian.cnf into /etc/mysql if available in the API
if [[ "$linux_name" == "Debian" || "$linux_name" == "Ubuntu" ]] ; then
	debianConf=$(api_call "GET" "system/${system_id}/node/0/component/grex/property/debian.cnf" "fieldselect=componentproperty~debian.cnf")
	if [[ "x$debianConf" =~ ^xUnable[[:space:]]to[[:space:]]find ]] ; then
		debianConf=$(cat /etc/mysql/debian.cnf)
		api_call "PUT" "system/${system_id}/node/0/component/grex/property/debian.cnf" "value=$debianConf"
	else
		echo "$debianConf" > /etc/mysql/debian.cnf
		debianPassword=$(grep "^password" /etc/mysql/debian.cnf | head -n 1 | cut -f2 -d"=" | tr -d ' \t\n\r\f')
		mysql -u root -e "UPDATE mysql.user SET Password=PASSWORD('$debianPassword') WHERE User='debian-sys-maint'"			
	fi
fi

mysql -u root -e "DELETE FROM mysql.user WHERE user = ''; \
GRANT ALL PRIVILEGES ON *.* TO $rep_username@'%' IDENTIFIED BY '$rep_password'; \
GRANT ALL PRIVILEGES ON *.* TO $db_username@'%' IDENTIFIED BY '$db_password'; \
FLUSH PRIVILEGES;"

/etc/init.d/mysql stop

if [[ "$linux_name" == "CentOS" ]]; then
        my_cnf_path="/etc/my.cnf"
elif [[ "$linux_name" == "Debian" || "$linux_name" == "Ubuntu" ]]; then
        my_cnf_path="/etc/mysql/my.cnf"
fi

if [[ my_cnf_path != "" ]]; then
        sed -e "s|export my_cnf_file=.*|export my_cnf_file=\"$my_cnf_path\"|" \
                mysql-config.sh > /tmp/mysql-config.sh.tmp

        mv /tmp/mysql-config.sh.tmp mysql-config.sh
else
        my_cnf_path=$(cat mysql-config.sh | \
                awk 'BEGIN { FS="=" } { gsub("\"", "", $2); if ($1 == "export my_cnf_file") print $2 }')
fi

if [[ ! -s mysql-config.sh ]]; then
	logger -p user.error -t MariaDB-Manager-Remote "Error generating mysql-config.sh configuration file."
	set_error "Error generating mysql-config.sh configuration file"
	exit 1
fi

cat $my_cnf_path | grep -q ^datadir=.*
if [[ $? = 0 ]]; then
        sed -e "s|datadir=.*|datadir=/var/lib/mysql|" $my_cnf_path > /tmp/my.cnf.tmp
        mv /tmp/my.cnf.tmp $my_cnf_path
else
        echo "[mysqld]" >> $my_cnf_path
        echo "datadir=/var/lib/mysql" >> $my_cnf_path
fi

# Disabling mysqld auto startup on boot
if [[ "$linux_name" == "CentOS" ]]; then
	chkconfig --del mysql
elif [[ "$linux_name" == "Debian" || "$linux_name" == "Ubuntu" ]]; then
	update-rc.d -f mysql remove
fi

# Updating node state
state_json=$(api_call "PUT" "system/$system_id/node/$node_id" "state=provisioned")
if [[ $? != 0 ]] ; then
	set_error "Failed to set the node state to provisioned"
	logger -p user.error -t MariaDB-Manager-Remote "Failed to set the node state to provisioned"
	exit 1
fi
#json_error "$state_json"
#if [[ "$json_err" != "0" ]]; then
#	set_error "Failed to set the node state to provisioned"
#        logger -p user.error -t MariaDB-Manager-Remote "Failed to set the node state to provisioned"
#        exit 1
#fi
