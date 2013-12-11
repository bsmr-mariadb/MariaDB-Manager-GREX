#!/bin/sh
#
# This file is distributed as part of the MariaDB Enterprise.  It is free
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
# Copyright 2012-2014 SkySQL Ab
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

scripts_dir=$(dirname $0)
cd $scripts_dir

# Getting and defining API credentials
export auth_key_number=$(awk -F ":" '{ print $1 }' credentials.ini)
export auth_key=$(awk -F ":" '{ print $2 }' credentials.ini)

. ./functions.sh

logger -p user.info -t MariaDB-Manager-Remote "Task: $taskid Command: $step_script $params" 

# Validations
if [[ "$step_script" == "" ]]; then
	logger -p user.error -t MariaDB-Manager-Remote \
			"Task: $taskid Parameter value not defined: step"
	echo "1"
	exit 1
fi

if [[ "$taskid" == "" ]]; then
	logger -p user.error -t MariaDB-Manager-Remote \
			"Task: $taskid Parameter value not defined: task id"
	echo "1"
	exit 1
fi

if [[ "$api_host" == "" ]]; then
	logger -p user.error -t MariaDB-Manager-Remote \
			"Task: $taskid Parameter value not defined: api_host"
	echo "1"
	exit 1
fi

# Getting current node system information from API
task_json=$(api_call "GET" "task/$taskid" "fields=systemid,nodeid")

export system_id=$(jq -r '.task | .systemid' <<<"$task_json")
export node_id=$(jq -r '.task | .nodeid' <<<"$task_json")

# Getting current node DB credentials from API
node_json=$(api_call "GET" "system/$system_id/node/$node_id" \
        "fields=name,dbusername,dbpassword,repusername,reppassword,privateip")

export nodename=$(jq -r '.node | .name' <<<"$node_json")
export db_username=$(jq -r '.node | .dbusername' <<<"$node_json")
export db_password=$(jq -r '.node | .dbpassword' <<<"$node_json")
export rep_username=$(jq -r '.node | .repusername' <<<"$node_json")
export rep_password=$(jq -r '.node | .reppassword' <<<"$node_json")
export privateip=$(jq -r '.node | .privateip' <<<"$node_json")

# Getting current system DB credentials from API (if undefined at node level)
system_json=$(api_call "GET" "system/$system_id" \
        "fields=dbusername,dbpassword,repusername,reppassword")

if [[ "$db_username" == "" ]]; then
        export db_username=$(jq -r '.system | .dbusername' <<<"$system_json")
fi
if [[ "$db_password" == "" ]]; then
        export db_password=$(jq -r '.system | .dbpassword' <<<"$system_json")
fi
if [[ "$rep_username" == "" ]]; then
        export rep_username=$(jq -r '.system | .repusername' <<<"$system_json")
fi
if [[ "$rep_password" == "" ]]; then
        export rep_password=$(jq -r '.system | .reppassword' <<<"$system_json")
fi

# Test command
if [[ "$step_script" == "test" ]]; then
        echo 0; exit
elif [[ "$step_script" == "cancel" ]]; then
        if [[ -f skysql.task.$taskid ]]; then
                p_PID=$(cat skysql.task.$taskid)
                rm -f skysql.tasl.$taskid

                # Getting command process list
                list_PID=$p_PID
                child_list=$(ps -o pid --ppid $p_PID --no-headers | sed -e "s/^ *//" | \
                        tr '\n' ',' | sed -e "s/,$//")

                while [ ! -z "$child_list" ]
                do
                        list_PID="$list_PID,$child_list"
                        child_list=$(ps -o pid --ppid $child_list --no-headers | \
                                sed -e "s/^ *//" | tr '\n' ',' | sed -e "s/,$//")
                done

                # Sending all processes the TERM signal
                kill_list=$(echo $list_PID | sed -e "s/,/ /g")
                kill -s TERM $kill_list
        fi

				exit 0
fi

echo $$ > ./skysql.task.$taskid

# Executing the script corresponding to the step
fullpath="$scripts_dir/steps/$step_script.sh $params"
sh $fullpath            > /tmp/remote.$$.log 2>&1
return_status=$?
if [[ $return_status == 0 ]]; then
	pri="user.info"
else
	pri="user.error"
fi
logger -p $pri -t MariaDB-Manager-Task -f /tmp/remote.$$.log
rm -f /tmp/remote.$$.log

if [[ -f skysql.task.$taskid ]]; then
        rm -f skysql.tasl.$taskid
fi

# Putting script exit code on output for the API-side to be able to read it via ssh
echo $return_status
