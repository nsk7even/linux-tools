# set-display-brightness.sh

## Purpose

Adjusts the brightness of one or multiple displays on a desktop system.

## Prerequisites

- xrandr
- bash
- bc

## Configuration

**Note that you have to modify the script to specify your displays!**

Go to the bottom of the script to these three lines:

    xrandr --output DP-0 --brightness $bright
    xrandr --output DVI-D-0 --brightness $bright
    xrandr --output DVI-I-1 --brightness $bright

These three lines are for three displays. You need one line per display.
You may remove any additional lines you don't need and duplicate them, if you need more.

Next, find out your display id(s) via the `xrandr` command:

`xrandr | grep " connected"`

You get an output of one line per connected displays:

    DVI-I-1 connected 1600x1200+0+0 (normal left inverted right x axis y axis) 408mm x 306mm
    DP-0 connected primary 1920x1200+1600+0 (normal left inverted right x axis y axis) 519mm x 324mm
    DVI-D-0 connected 1600x1200+3520+0 (normal left inverted right x axis y axis) 408mm x 306mm

The identificator of the displays is at the beginning of each line.

Set up the script lines stated above with the identificators of your displays.

If you have two displays, connected via display ports, it may look like this:

    xrandr --output DP-0 --brightness $bright
    xrandr --output DP-1 --brightness $bright


## Usage

To set full brightness:

`./set-display-brightness.sh 1.0`

To set half brightness:

`./set-display-brightness.sh 0.5`


