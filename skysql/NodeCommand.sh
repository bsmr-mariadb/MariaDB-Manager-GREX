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
shift
params=$@

scripts_dir=`dirname $0`

echo "- Command request:" >> $log

# Executing the script corresponding to the step
cd $scripts_dir
fullpath="$scripts_dir/steps/$step_script.sh $params"
sh $fullpath            >> $log 2>&1

echo "----------------------------------------------------------" >> $log

# Putting script exit code on output for the API-side to be able to read it via ssh
echo $?
