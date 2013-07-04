#!/bin/bash
#


. ./mysql-config.sh

TMPFILE="/tmp/innobackupex-runner.$$.tmp"

## Restore vars
RESTOREPATH="/tmp"

# Creates temporary directories if they do not exist
mkdir -p $RESTOREPATH/incr
mkdir -p $RESTOREPATH/extr
mkdir -p $RESTOREPATH/mysql_tmp_cp

USEROPTIONS="--user=$mysql_user --password=$mysql_pwd"
DATAFOLDER=`cat $my_cnf_file | awk 'BEGIN { FS="=" } { if ($1 == "datadir") print $2 }'`

if [ "$DATAFOLDER" == "" ] ; then
	echo "Error: data folder not defined in MySQL configuration file"
	exit 1
fi

# prepareapply(): Prepares the full backup and applies on it all the incrementals from the oldest to the youngest
# Arguments:
#      -a arg: the array which stores the Backup names (assumes the base fullbackup is stored on its last position)

prepareapply() {
	while getopts  "a:" Option
	do
	case $Option in
	a)   declare -a arrbkp=("${!OPTARG}") ;;

	* ) echo "Not recognized argument"; exit -1 ;;
	esac
	done

	index=$((${#arrbkp[@]} - 1))

	bkpname=${arrbkp[$index]}

	# Extracting previouly retrieved base fullbackup
	cur=`pwd`
	cd $RESTOREPATH/extr
	tar -xivf $backups_path/$bkpname
	cd $cur

	# Preparing base backup
	innobackupex $USEROPTIONS --defaults-file $my_cnf_file --apply-log --redo-only $RESTOREPATH/extr &> $TMPFILE
	if [ -z "`tail -1 $TMPFILE | grep 'completed OK!'`" ] ; then
		echo "Restore failed (stage 'preparing the backup'):"; echo
		echo "---------- ERROR OUTPUT from $INNOBACKUPEX ----------"
		cat $TMPFILE
		rm -f $TMPFILE
		exit 1
	else
		cat $TMPFILE
	fi
	
	# Applying incremental backups
	INCREMENTALDIR=$RESTOREPATH/incr
	rm -fR $INCREMENTALDIR/*
	let "index = $index - 1"
	while [ "$index" -ge 0 ]
	do
		bkpname=${arrbkp[index]}
		xbstream -x < $backups_path/$bkpname -C $INCREMENTALDIR
		innobackupex --apply-log --defaults-file=$my_cnf_file --use-memory=1G $USEROPTIONS --incremental-dir=$INCREMENTALDIR $RESTOREPATH/extr
		rm -fR $INCREMENTALDIR/*
		let "index = $index - 1"
	done

	# Prepare the base backup after applying incremental backups
	innobackupex $USEROPTIONS --apply-log --redo-only $RESTOREPATH/extr &> $TMPFILE
}


# getbackups(): downloads all the backups and stores them into an array, last pos == base fullbackup 
getbackups() {
	index=0
	BACKUPNAME=`ls -1 $backups_path | grep -s Backup.$BACKUPID\$`

	while [[ ! $BACKUPNAME == FullBackup* ]]; do
		arrbkp[index]=$BACKUPNAME     
		. ./steps/backups/getbasebackup.sh
		export BACKUPID=$BASEBACKUPID
		BACKUPNAME=`ls -1 $backups_path | grep -s Backup.$BACKUPID\$`
		let "index = $index + 1"
	done

	arrbkp[index]=$BACKUPNAME
   
	prepareapply -a arrbkp[@]
}

# Cleaning potential hung files from previous aborted restore attempt
rm -fR $RESTOREPATH/mysql_tmp_cp/*
rm -fR $RESTOREPATH/extr/*
rm -fR $RESTOREPATH/incr/*

getbackups

if [ -z "`tail -1 $TMPFILE | grep 'completed OK!'`" ] ; then
	echo "Restore failed - stage 'preparing the backup':"; 
	echo "---------- ERROR OUTPUT from $INNOBACKUPEX ----------"
	cat $TMPFILE
	rm -f $TMPFILE
	exit 1
else
	cat $TMPFILE
fi

# Stopping mysqld
./steps/stop.sh

if [[ `mysqladmin $USEROPTIONS status | awk '{print $1}'` == "Uptime:" ]]; then
	echo "HALTED: Server not properly shut down"
	exit 1
fi

# Cleaning the data folder
mv $DATAFOLDER/* $RESTOREPATH/mysql_tmp_cp/

# Restore by copyback of the backup folder into data folder
innobackupex $USEROPTIONS --defaults-file $my_cnf_file --copy-back $RESTOREPATH/extr/ &> $TMPFILE

if [ -z "`tail -1 $TMPFILE | grep 'completed OK!'`" ] ; then
 echo "Restore failed - stage 'copyback backup':"; 
 echo "---------- ERROR OUTPUT from $INNOBACKUPEX ----------"

 cat $TMPFILE
 rm -f $TMPFILE
 exit 1
else
 cat $TMPFILE
fi

# Restarting mysqld
./steps/start.sh

sleep 10

if [ ! `mysqladmin $USEROPTIONS status | awk '{print $1}'` == "Uptime:" ]; then
 echo "HALTED: Server not properly started"
 exit 1
fi

# Changing mysql data folder ownership back to mysql
chown -R mysql:mysql $DATAFOLDER

# Cleanup phase
rm -fR $RESTOREPATH/mysql_tmp_cp/*
rm -fR $RESTOREPATH/extr/*
rm -fR $RESTOREPATH/incr/*

exit 0
