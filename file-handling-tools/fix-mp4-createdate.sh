#!/bin/bash

me=`basename $0`
log="/home/nsk/tmp/$me.log"

# Argument
if [ $# -eq 1 ] ; then
	# Only one argument
	file=$1
	
else
	# No argument
	echo "Usage: $0 target-file (arg count was: $#)" > $log
	exit 1
fi

echo "$0 started" > $log

exiftool "-CreateDate<DateTimeOriginal" -s "$file"
exiftool "-TrackCreateDate<DateTimeOriginal" -s "$file"
exiftool "-MediaCreateDate<DateTimeOriginal" -s "$file"

# Option: fix date
#exiftool "-CreateDate=2021:07:31 14:59:03" -s "$file"
#exiftool "-TrackCreateDate=2021:07:31 14:59:03" -s "$file"
#exiftool "-MediaCreateDate=2021:07:31 14:59:03" -s "$file"

echo "exiftool returned: $?" >> $log

exit
