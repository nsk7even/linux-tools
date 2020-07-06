#!/bin/bash

# Argument
if [ $# -eq 1 ] ; then
	# Only one argument
	file=$1
	
else
	# No argument
	echo "Usage: $0 target-file (arg count was: $#)" > /home/nsk/tmp/autorename.log
	exit 1
fi

echo "$0 started" > /home/nsk/tmp/autorename.log

exiftool -overwrite_original_in_place -P '-filename<CreateDate' -d "%Y-%m-%d %H-%M-%S%%-c.%%le" "$file"

echo "exiftool returned: $?" >> /home/nsk/tmp/autorename.log

# -if  'not $CreateDate'  '-CreateDate<FileModifyDate'
# disabled: creates directory in year/month format and moves file into
#exiftool -o . '-Directory<CreateDate' -d /mnt/vault/pictures/%Y/%m -r /mnt/vault/unsorted_pictures/staging

exit
