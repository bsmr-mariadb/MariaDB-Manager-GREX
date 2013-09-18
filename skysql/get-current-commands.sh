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
# This script returns the number of commands in the 'running' state at time
# of execution
#

. ./restfulapicredentials.sh
no_commands=0

api_ret=`./restfulapi-call.sh "GET" "task" "state=running"`
task_ids=`echo $api_ret | awk '{ gsub("^.*\\\[", "", $0); gsub("\\\].*", "", $0); 
				gsub("\"", "", $0); print $0 }'`

if [[ ! "$task_ids" == "" ]]; then
        running_commands=`echo $task_ids | awk -v cur_task_id=$taskid '
		BEGIN { RS="},"; FS=","; counter=0 } { 
			split($1, a, ":"); 
			if (a[2] != cur_task_id)
				counter++;
		} 
		END { print counter }'`
        no_commands=$((no_commands + running_commands))
fi

echo $no_commands
