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
# This script makes a GetAllNodes request to the API and parses it to get an online node
# that can be used as a reference to the cluster
#

. ./restfulapicredentials.sh

api_node_list=`./restfulapi-call.sh GET system/$scds_system_id/node "state=joined&fields=nodeid,privateip"`
node_list=`echo $api_node_list | sed 's|{"nodes":\[||' | sed 's|\]}||'`

echo $node_list | awk 'BEGIN { RS="}," } { sub(/^{/, "", $0); sub(/}.*$/, "", $0); print $0; }' | {
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
                cluster_node_ip=`echo ${node_array[$i]} | awk -v cur_node_id=$scds_node_id \
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

