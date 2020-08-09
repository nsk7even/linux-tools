#!/bin/bash

path=`dirname "$0"`

current=`xrandr --verbose | grep Brightness | sed "s/.*: \(.*\)/\1/p" | head -1`
echo "current brightness: $current"
current=`echo "scale=0; $current * 100 / 1" | bc -l`

bright=`zenity --scale --title="xrandr Brightness Control" --window-icon="/usr/share/icons/hicolor/scalable/apps/mate-brightness-applet.svg" --text="Set brightness:" --value="$current" --min-value=1 --max-value=100`

bright=`echo "$bright / 100" | bc -l`
echo "new brightness: $bright"

$path/set-display-brightness.sh $bright

