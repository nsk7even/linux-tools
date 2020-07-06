#!/bin/bash
#set -xv
#
# autoshutdown v0.2
# (c) Nicolas Krzywinski http://www.nskComputing.de
#
# Created:	    2019 by Nicolas Krzywinski
# Description:	When executed at system startup, waits if no user logs on and shuts down the system then
# Last Changed: 2019-10-28
# Change Desc:	full path to poweroff binary
# Remarks:	


### PART ZERO: Settings ###
logging=true
me=`basename $0`
logfile=/var/log/$me.log
logrows=40
log_cmd_outputs=false
waittime=900


### PART ONE: FUNCTIONS ###

# Logging function
log () {
	if $logging
	then
		date=`date --iso-8601=minutes`

		if [ "$1" = "none" ] ; then
			echo $date "--- Program tick: nothing to do ---" >> $logfile
		elif [ "$1" = "start" ] ; then
			echo $date "$0 started processing.." >> $logfile
		elif [ "$1" = "stop" ] ; then
			echo $date "$0 finished" >> $logfile
	# Note: To reactivate this, check for $1 is needed because is can consist of more than one word
	#	elif [ $1 -eq 0 ] ; then
	#		echo $date Success: $2 >> $logfile
	#	elif [ $1 -eq 1 ] ; then
	#		echo $date Failure: $2 >> $logfile
		elif [ "$1" = "clean" ] ; then
			# Clean up logfile
			tail -n $logrows $logfile > $logfile.tmp
			rm $logfile
			mv $logfile.tmp $logfile
		else
			echo -e "$date $1" >> $logfile
		fi
	fi

	return 0
}



### PART TWO: PREPARATIONS ###





### PART THREE: ACTIONS ###

# We start now with actions..
log "start"

log "waiting for 5 minutes now ..."
sleep $waittime
log "5 minutes are over, checking if s. o. logged on to the system ..."

users=`users`

if [ -z "$users" ]
then
	log "No one logged on - shutting down now ..."
	/sbin/poweroff &
else
	log "Users logged on:"
	log "$users"
fi


### PART FOUR: POSTPARATIONS ###

# We are stopping now..
log "stop"

# Clean up log file
log "clean"
