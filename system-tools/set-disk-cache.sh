#!/bin/bash
#set -xv
#
# set-disk-cache v0.1
# (c) Nicolas Krzywinski http://www.nskComputing.de
#
# Created:	    2024 by Nicolas Krzywinski
# Description:	adjusts the disc cache for file copy operations
# Last Changed:
# Change Desc:
# Remarks:	    this script needs root permissions
# Source:		https://lonesysadmin.net/2013/12/22/better-linux-disk-caching-performance-vm-dirty_ratio/
#				https://bugs.launchpad.net/ubuntu/+source/linux/+bug/1208993


### PART ZERO: Settings ###
me=`basename $0`
mode="normal"
normalratio=20
normalbackratio=10
slowratio=80
slowbackratio=50

### PART TWO: PREPARATIONS ###

# Argument
if [ $# -eq 1 ] ; then

	# Only one argument
	case "$1" in
		"normal"|"slow")
			mode="$1"
		;;
		*)
			echo "invalid mode: $1"
		;;
	esac

else
	# No argument
	echo "Usage: $0 [normal|slow]"
	exit 1
fi


### PART THREE: ACTIONS ###

if [ "$mode" = "normal" ]
then
	ratio=$normalratio
	backratio=$normalbackratio
elif [ "$mode" = "slow" ]
then
	ratio=$slowratio
	backratio=$slowbackratio
fi

sysctl vm.dirty_ratio=$ratio
sysctl vm.dirty_background_ratio=$backratio

