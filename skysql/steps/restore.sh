#!/bin/bash

if [ $# -lt 1 ] ; then
    echo "Usage: $0 '<backup id>'"
    exit 1
fi

. ./mysql-config.sh
. ./restfulapicredentials.sh

export node_id=$scds_node_id
export system_id=$scds_system_id
export BACKUPID=$1

backupfilename=`ls -1 $backups_path | grep -s Backup.$BACKUPID\$`
if [[ "$backupfilename" == Full* ]] ; then
    ./steps/backups/fullrestore.sh
else
   ./steps/backups/incrrestore.sh
fi

rststatus=$?
exit $rststatus
