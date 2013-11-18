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

./remote-scripts-config.sh

# api_call()
# This function is used to make API calls.
#
# Parameters:
# $1: HTTP request type
# $2: API call URI
# $3: API call-specific parameters
api_call() {
	method="$1"
	request_uri="$2"
	shift 2
	
	# URL for the request
	full_url="http://$api_host/restfulapi/$request_uri"

        # Getting system date in the required format for authentication
        api_auth_date=`date --rfc-2822`

        # Getting checksum and creating authentication header
        md5_chksum=$(echo -n $request_uri$auth_key$api_auth_date | md5sum | awk '{print $1}')
        api_auth_header="api-auth-$auth_key_number-$md5_chksum"

	curlargs=( --data-urlencode suppress_response_codes=true )
	[[ $method == "GET" ]] && curlargs+=('-G')
	for arg; do
	    curlargs+=("--data-urlencode")
	    curlargs+=("$arg")
	done
	
	curl -s -S -X "$method" -H "Date:$api_auth_date" -H "Authorization:$api_auth_header" \
		"$full_url" -H "Accept:application/json" "${curlargs[@]}"
	curl_status=$?

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

                logger -p user.error -t MariaDB-Manager-Remote "restfulapi-call: $full_url failed, $msg"
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
	error_text=$(jq -r '.errors' <<<"$1")
        if [[ "$error_text" != "null" ]] ; then
                logger -p user.error -t MariaDB-Manager-Remote "API call failed: $error_text"
                if [[ "$error_text" =~ "Date header out of range" ]]; then
                        logger -p user.error -t MariaDB-Manager-Remote "Date and time on the local host must be synchronised with the API host"
                fi
                json_err=1
        else
                json_err=0
        fi
}

# get_online_node
# Returns a reference (IP) to an online node on the cluster.
get_online_node() {
	nodes_json=$(api_call "GET" "system/$system_id/node" "state=joined" "fields=nodeid,privateip")
	jq -r --arg cur_node_id $node_id '.nodes | map(if .nodeid != $cur_node_id then .privateip else empty end) | .[0]' <<<"$nodes_json"
}

# get_node_state
# Returns this node's current state.
get_node_state() {
	node_json=$(api_call "GET" "system/$system_id/node/$node_id" "fields=state")
	jq -r '.node | .state' <<<"$node_json"
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
