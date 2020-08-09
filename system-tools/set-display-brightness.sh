#!/bin/bash

# Argument
if [ $# -gt 0 ] ; then
	bright=$1
else
	# No argument
	echo "Usage: $0 <BRIGHTNESS>"
	echo "BRIGHTNESS: 0.1-1.0"
	exit 1
fi

if (( $(echo "$bright > 1.0" | bc -l) )) ; then
    bright=1.0
fi

if (( $(echo "$bright < 0.1" | bc -l) )) ; then
    bright=0.1
fi

xrandr --output DP-0 --brightness $bright
xrandr --output DVI-D-0 --brightness $bright
xrandr --output DVI-I-1 --brightness $bright

