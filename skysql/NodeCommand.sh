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
# This script is invoked remotely by RunCommand.sh on the API machine to execute commands on a given node.
#
# Parameters:
# $1: Step to be executed
# $2-@: Step script-specific parameters

log=/var/log/skysql-remote-exec.log

step_script=$1
export taskid=$2
export api_host=$3
shift 3
params=$@

scripts_dir=`dirname $0`
cd $scripts_dir

logger -p user.info -t MariaDB-Enterprise-Remote "Task: $taskid Command: $step_script $params" 

# Validations
if [ "$step_script" == "" ]; then
	logger -p user.error -t MariaDB-Enterprise-Remote \
			"Task: $taskid Parameter value not defined: step"
	echo "1"
	exit 1
fi

if [ "$taskid" == "" ]; then
	logger -p user.error -t MariaDB-Enterprise-Remote \
			"Task: $taskid Parameter value not defined: task id"
	echo "1"
	exit 1
fi

if [ "$api_host" == "" ]; then
	logger -p user.error -t MariaDB-Enterprise-Remote \
			"Task: $taskid Parameter value not defined: api host"
	echo "1"
	exit 1
fi

# Getting current node system information from API
task_json=`./restfulapi-call.sh "GET" "task/$taskid" "fields=systemid,nodeid"`
task_fields=`echo $task_json | sed 's|^{"task":{||' | sed 's|}}$||'`

export system_id=`echo $task_fields | awk 'BEGIN { RS=","; FS=":" } \
        { gsub("\"", "", $0); if ($1 == "systemid") print $2; }'`
export node_id=`echo $task_fields | awk 'BEGIN { RS=","; FS=":" } \
        { gsub("\"", "", $0); if ($1 == "nodeid") print $2; }'`

# Getting current node DB credentials from API
node_json=`./restfulapi-call.sh "GET" "system/$system_id/node/$node_id" \
        "fields=dbusername,dbpassword,repusername,reppassword,privateip"`
node_fields=`echo $node_json | sed 's|^{"node":{||' | sed 's|}}$||'`

export db_username=`echo $node_fields | awk 'BEGIN { RS=","; FS=":" } \
        { gsub("\"", "", $0); if ($1 == "dbusername") print $2; }'`
export db_password=`echo $node_fields | awk 'BEGIN { RS=","; FS=":" } \
        { gsub("\"", "", $0); if ($1 == "dbpassword") print $2; }'`
export rep_username=`echo $node_fields | awk 'BEGIN { RS=","; FS=":" } \
        { gsub("\"", "", $0); if ($1 == "repusername") print $2; }'`
export rep_password=`echo $node_fields | awk 'BEGIN { RS=","; FS=":" } \
        { gsub("\"", "", $0); if ($1 == "reppassword") print $2; }'`
export privateip=`echo $node_fields | awk 'BEGIN { RS=","; FS=":" } \
        { gsub("\"", "", $0); if ($1 == "privateip") print $2; }'`

# Test command
if [ "$step_script" == "test" ]; then
        echo 0; exit
fi

# Executing the script corresponding to the step
fullpath="$scripts_dir/steps/$step_script.sh $params"
sh $fullpath            > /tmp/remote.$$.log 2>&1
return_status=$?
if [ $return_status == 0 ]; then
	pri="user.info"
else
	pri="user.error"
fi
logger -p $pri -t MariaDB-Enterprise-Task -f /tmp/remote.$$.log
rm -f /tmp/remote.$$.log

# Putting script exit code on output for the API-side to be able to read it via ssh
echo $return_status
