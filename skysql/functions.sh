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
# This script contains auxiliary functions necessary by the other scripts.
#

# api_call()
# This function is used to make API calls.
#
# Parameters:
# $1: HTTP request type
# $2: API call URI
# $3: API call-specific parameters
api_call() {
        # Getting system date in the required format for authentication
        api_auth_date=`date --rfc-2822`

        # Getting checksum and creating authentication header
        md5_chksum=$(echo -n $2$auth_key$api_auth_date | md5sum | awk '{print $1}')
        api_auth_header="api-auth-$auth_key_number-$md5_chksum"

        # URL for the request
        full_url="http://$api_host/restfulapi/$2"

        # Sending the request
        if [[ $# -ge 3 ]]; then
                if [[ $1 == "GET" ]]; then
                        curl --request GET -H "Date:$api_auth_date" -H "Authorization:$api_auth_header" -H "Accept:application/json" $full_url?$3
                        curl_status=$?
                else
                        curl --request $1 -H "Date:$api_auth_date" -H "Authorization:$api_auth_header" -H "Accept:application/json" --data "$3" $full_url
                        curl_status=$?
                fi
        else
                curl -s --request $1 -H "Date:$api_auth_date" -H "Authorization:$api_auth_header" -H "Accept:application/json" $full_url
                curl_status=$?
        fi

        if [[ "$curl_status" != 0 ]]; then
                case "$curl_status" in

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
                exit $curl_status
        fi
}

# set_error()
# This function is an alias to invoke an API call to set the error message for the current task.
#
# Parameters:
# $1: HTTP request type
set_error() {
        api_call "PUT" "task/$taskid" "errormessage=$1"
}

# json_error
# Look at the JSON return from an API call and process any error information
# contained in that return.
#
# Parameters
# $1: The JSON returned from the API call
#
# Returns
# $json_err:    0 if no error was detected
json_error() {
        if [[ "$1" =~ '{"errors":"' ]] ; then
                error_text=$(sed -e 's/^{"errors":\["//' -e 's/"\]}$//' <<<$1)
                logger -p user.error -t MariaDB-Manager-Task "API call failed: $error_text"
                if [[ "$error_text" =~ "Date header out of range" ]]; then
                        logger -p user.error -t MariaDB-Manager-Task "Date and time on the local host must be synchronised with the API host"
                fi
                json_err=1
        else
                json_err=0
        fi
}

# get_online_node
# Returns a reference (IP) to an online node on the cluster.
get_online_node() {
	api_node_list=$(api_call GET system/$system_id/node "state=joined&fields=nodeid,privateip")
	node_list=`echo $api_node_list | sed 's|{"nodes":\[||' | sed 's|\]}||'`

	echo $node_list | awk 'BEGIN { RS="}," } \
			{ sub(/^{/, "", $0); sub(/}.*$/, "", $0); print $0; }' | {
	        node_array[0]=""
	        i=0
        	while read line; do
                	if [ -n "$line" ]; then
                        	node_array[$i]=$line
	                        ((i+=1))
        	        else
                	        break
	                fi
        	done
	        ((i-=1))

        	cluster_node_ip=""
	        while [ $i -ge 0 ]; do
        	        cluster_node_ip=`echo ${node_array[$i]} | awk -v cur_node_id=$node_id \
                			'BEGIN { RS=","; FS=":"; notcurrent=0; ip="" } {
	                        for (i=1; i<=NF; i++) {
        	                        if(length($i) > 1) {
                	                        sub(/^\"/, "", $i); sub(/\".*$/, "", $i);
                        	        }
	                        }
        	                if ($1 == "nodeid" && $2 != cur_node_id) {
                	                notcurrent = 1
                        	}
	                        if ($1 == "privateip") {
        	                        ip = $2
                	        }
	                } END { if (notcurrent) print ip; }'`
        	        if [ -n "$cluster_node_ip" ]; then
                	        break
	                fi
        	        ((i-=1))
	        done

        	echo $cluster_node_ip
	}
}

# get_node_state
# Returns this node's current state.
get_node_state() {
	node_json=$(api_call "GET" "system/$system_id/node/$node_id" "fields=state")
	node_fields=$(echo $node_json | sed 's|^{"node":{||' | sed 's|}}$||')

	node_state=$(echo $node_fields | awk 'BEGIN { FS=":" } /\"state\"/ {
        	gsub("\"", "", $0);
	        if ($1 == "state") print $2; }')
	echo $node_state
}

# wait_for_state
# Waits for a node state change, times out after a configurable number of retries
wait_for_state() {
	no_retries=$state_wait_retries
	while [[ "$no_retries" -gt 0 ]]
	do
		sleep 1
        	node_state=$(get_node_state)
	        if [[ "$node_state" == "$1" ]]; then
                	exit 0
	        fi
        	no_retries=$((no_retries - 1))
	done

	exit 1
}

export -f api_call
export -f set_error
export -f json_error
export -f get_online_node
export -f get_node_state
export -f wait_for_state
