#!/bin/bash

if [[ "$linux_name" == "CentOS" ]] ; then
	my_cnf_file="/etc/my.cnf"
elif [[ "$linux_name" == "Debian" || "$linux_name" == "Ubuntu" ]] ; then
	my_cnf_file="/etc/mysql/my.cnf"
fi
export my_cnf_file

export backups_remotepath=$(api_call "GET" "config/backups/remotepath" "fieldselect=remotepath")
