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
# This script is called by the control and backup scripts to make API calls.
#
# Parameters:
# $1: HTTP request type
# $2: API call URI
# $3: API call-specific parameters

. ./restfulapicredentials.sh

# Getting system date in the required format for authentication
api_auth_date=`date --rfc-2822`

# Getting checksum and creating authentication header
md5_chksum=`echo -n $2$auth_key$api_auth_date | md5sum | awk '{print $1}'`
api_auth_header="api-auth-$auth_key_number-$md5_chksum"

# URL for the request
full_url="http://$api_host/restfulapi/$2"

# Sending the request
if [ $# -ge 3 ]; then
	if [ "$1" == "GET" ]; then
		curl -s --request GET -H "Date:$api_auth_date" -H "Authorization:$api_auth_header" \
			-H "Accept:application/json" "$full_url?$3"
		curl_status=$?
	else
		curl -s --request "$1" -H "Date:$api_auth_date" -H "Authorization:$api_auth_header" \
			-H "Accept:application/json" --data "$3" "$full_url"
		curl_status=$?
	fi
else
        curl -s --request $1 -H "Date:$api_auth_date" -H "Authorization:$api_auth_header" \
		-H "Accept:application/json" "$full_url"
	curl_status=$?
fi

if [ $curl_status != 0 ]; then
case $curl_status in

1)
	msg="Unsupported protocol"
	;;
2)
	msg="Failed to connect"
	;;
3)
	msg="Malformed URL"
	;;
5)
	msg="Unable to resolve proxy"
	;;
6)
	msg="Unable to resolve host $api_host"
	;;
7)
	msg="Failed to connect to host $api_host"
	;;
28)
	msg="Request timeout"
	;;
22)
	msg="Page not received"
	;;
*)
	msg="curl failed with exit code $curl_status"
esac

logger -p user.error -t MariaDB-Manager-Task "restfulapi-call: $full_url failed, $msg"
fi

exit $curl_status

