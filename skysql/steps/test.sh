#!/bin/sh

hostname="10.0.0.3"
rep_username="sst"
rep_password="sstpwd"

# Creating MariaDB configuration file
hostname=`uname -n`
sed -e "s/###NODE-ADDRESS###/$hostname/" \
	-e "s/###REP-USERNAME###/$rep_username/" \
	-e "s/###REP-PASSWORD###/$rep_password/"	\
	steps/conf_files/skysql-galera.cnf > /etc/my.cnf.d/skysql-galera.cnf

