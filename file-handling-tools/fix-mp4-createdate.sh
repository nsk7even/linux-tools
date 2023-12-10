#!/bin/bash

#set -xv
#
# fix-mp4-createdate.sh v0.2
# (c) Nicolas Krzywinski http://www.nskComputing.de
#
# Created:	    2023 by Nicolas Krzywinski
# Description:	Sets the MP4 fields CreateDate, TrackCreateDate and
#               MediaCreateDate either from field DateTimeOriginal, or by manual
#               value, specified as second argument (format: yyyy:MM:dd hh:mm:ss)
# Last Changed: 2023-08-18
# Change Desc:  Added option to manually set date
# Remarks:	    Mainly used for MP4 files of GoPro 7 that sometimes does not
#               correctly set these fields

me=`basename $0`
log="/home/nsk/tmp/$me.log"
newdate="foo"
modifydate="false"
jpgmode="false"

# Argument
if [ $# -ge 1 ] ; then
	# one or more arguments
	file=$1

	if [ $# -ge 2 ] ; then
    	# arg two
	    if [ $2 = "--jpg-mode" ] ; then
        	jpgmode="true"
        else
        	newdate=$2
        fi
    fi

	if [ $# -ge 3 ] ; then
    	# arg three
    	if [ $3 = "--set-modify" ] ; then
        	modifydate="true"
        fi
    fi

else
	# No argument
	echo "Usage: $0 target-file [<manual-date>|--jpg-mode [--set-modify]] (arg count was: $#)" > $log
	exit 1
fi

echo "$0 started" > $log

if [ $jpgmode = "true" ] ; then
    exiftool "-CreateDate<GPSDateTime" -s "$file"
    exiftool "-DateTimeOriginal<GPSDateTime" -s "$file"
else
    if [ "$newdate" = "foo" ] ; then
        exiftool "-CreateDate<DateTimeOriginal" -s "$file"
        exiftool "-TrackCreateDate<DateTimeOriginal" -s "$file"
        exiftool "-MediaCreateDate<DateTimeOriginal" -s "$file"
    else
        # Example: 2021:07:31 14:59:03
        exiftool -CreateDate="$newdate" -s "$file"
        exiftool -TrackCreateDate="$newdate" -s "$file"
        exiftool -MediaCreateDate="$newdate" -s "$file"

        if [ $modifydate = "true" ] ; then
            exiftool -ModifyDate="$newdate" -s "$file"
            exiftool -TrackModifyDate="$newdate" -s "$file"
            exiftool -MediaModifyDate="$newdate" -s "$file"
        fi
    fi
fi

echo "exiftool returned: $?" >> $log

exit
