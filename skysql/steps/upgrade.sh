#!/bin/bash
# Command script stub

. ./remote-scripts-config.sh

logger -p user.info -t MariaDB-Manager-Remote "Command start: upgrade"

# Setting the state of the command to running
api_call "PUT" "task/$taskid" "state=running"

exit 0
