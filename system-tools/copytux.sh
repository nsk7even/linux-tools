#!/bin/bash
#set -xv
#
# copytux
version="0.9.1"
# (c) Nicolas Krzywinski http://www.nskComputing.de
#
# Created:	    2011-10 by Nicolas Krzywinski
# Description:	Copies complete system files to configured target directories
#
# Last Changed:	2023-12-10
# Change Desc:	merged changes from 0.9 and 0.8.x
#
# Known Bugs / Missing features:
# - Ownership and permissions of root directory are not corrected, if wrong (needs to be root:root rwxr-xr-x)
# - Automatic fstab entries not working
# - Swap is missing in automatic fstab entries
# - Program arguments not good implemented
#
# Remarks:	    Tested on Ubuntu, Linux Mint and Debian Squeeze
#				May run on other distros as well

# SETTINGS ############################################################################################

# Runmode, valid modes are
# full		does full system copy, including all steps
# update	does filesystem sync only (update of all files from source to target)
# grub		does grub configuration and grub install only
# Hint: use any invalid mode descriptor for dry run which just prints out target directories
runmode=full

# Specify the device to install grub (leave empty to skip this step)
grubdevice=

# Source directory
sourcedir=/

# Target directory (leave empty to use multiple target directories below)
# Hint: the first argument to this script overrides this parameter
targetdir=/media/user/backupdisk

# Target directories (empty parameters will be skipped)
rootdir=			# Absolute root dir path
bootdirpath=		# Absolute boot dir path OR path to place the boot dir INTO
homedirpath=		# Absolute home dir path OR path to place the home dir INTO
usrdirpath=			# Absolute usr dir path OR path to place the usr dir INTO
vardirpath=			# Absolute var dir path OR path to place the var dir INTO
srvdirpath=			# Absolute srv dir path OR path to place the srv dir INTO

# Interpret $homedirpath, $usrdirpath, $vardirpath and $srvdirpath as absolute paths
# Otherwise the corresponding subdirectory within the paths will be used:
# 	$homedirpath/home, $usrdirpath/usr, $vardirpath/var and $srvdirpath/srv
# Note: this is automatically disabled if one single $targetdir is set
absolutepaths=true

# Delete all additional files at targets (WARNING - BE CAREFUL!)
# Note: this isn't applied to root
sync=true

# Exclude files matching this pattern (rsync parameter --exclude)
# Note: --delete-excluded is not used for system directories, except /var /opt /srv /root
# Hint: if you want to exclude e. g. /var/lib/toobig, use /var/lib/toobig here, BUT /lib/toobig in $absolutepaths mode
exclude=/etc/fstab

# Prevent interactive kickstart
unattended=false


########################################################################################################
##    ! ! !    DO NOT MODIFY BELOW HERE    ! ! !    ~    ! ! !    DO NOT MODIFY BELOW HERE    ! ! !   ##
########################################################################################################

scriptname=`basename "$0"`
echo $scriptname $version
echo "WARNING: use this command with care!"
echo ""

if [ $runmode = "update" ]
then
    echo "WARNING: runmode=update"
    echo "Target system won't be bootable, if the kernel referred by grub.cfg does not exists anymore"
    echo ""
fi

# FUNCTIONS ############################################################################################

compare_dir_sizes ()
{
	path1="$1"
	path2="$2"

	echo -n "  - Measuring $path1 ... "
	size1=`du -shx "$path1" | cut -f1`
	echo $size1

	echo -n "  - Measuring $path2 ... "
	size2=`du -shx "$path2" | cut -f1`
	echo $size2

	if [ $size1 = $size2 ]
	then echo "[OK] Sizes of $path1 match: $size1"
	else echo "[WARN] Sizes of $path1 does not match: $size1 != $size2!"
	fi
}

get_fstab_entry ()
{
	localmountpoint="$1"
	targetmountpoint="$2"
	devname=`mount | grep "$localmountpoint " | sed -r 's#(\s).*##'`
	uuidkvp=`lsblk --noheadings --pairs --output UUID $devname`
	fstype=`lsblk --noheadings --output FSTYPE $devname`

	if [ $targetmountpoint = "/" ]
	then
		params="errors=remount-ro	0	1"
	else
		case $fstype in
		"ext?")
			params="defaults	0	2"
			;;
		"swap")
			params="sw			0	0"
			;;
		*)
			params="defaults	0	2"
			;;
		esac
	fi

	echo "$uuidkvp	$targetmountpoint	$fstype	$params"
}

report_dir()
{
	if [ -n "$1" ]
		then echo "$2"
	fi
}

report_dirs()
{
	if [ "$absolutepaths" = true ]
	then
		suffix1="for"
		suffix2=""
		trailingslash="/"
	else
		suffix1="to place "
		suffix2="into"
		trailingslash=
	fi

	report_dir "$bootdirpath" "* $bootdirpath as directory $suffix1 /boot $suffix2"
	report_dir "$homedirpath" "* $homedirpath as directory $suffix1 /home $suffix2"
	report_dir "$usrdirpath" "* $usrdirpath as directory $suffix1 /usr $suffix2"
	report_dir "$vardirpath" "* $vardirpath as directory $suffix1 /var $suffix2"
	report_dir "$srvdirpath" "* $srvdirpath as directory $suffix1 /srv $suffix2"
}

copy_rootdir()
{
    # note: this won't touch symlinks of newer systems,
    # but will copy directories of older systems
	if [ -d $sourcedir/$1 ]
	then
		echo -n "Copying $sourcedir/$1 directory... "
		rsync $2 $sourcedir/$1 $rootdir/
		echo "complete."
	else echo "No $sourcedir/$1 directory - skipped."
	fi
}

copy_partition()
{
	if [ -z "$1" ]
	then
		echo "Skipped $2"
	else
		echo -n "Copying partition $2 ..."
		rsync $3 $sourcedir$2$trailingslash $1
		echo " complete."
	fi
}

create_rootdir()
{
    if [ ! -d $rootdir/$1 ]; then mkdir $rootdir/$1; fi
}


# LOGIC FLOW ###########################################################################################

me=`whoami`

if [ $me != "root" ]
then
	echo "ERROR: this script has to be run as root!"
	exit 2
fi

rootdirargs="-lptgoD"   # note: this is like -a, but without -r (recursive) as we only want the root files
args="-ax"

# Set rsync argument for deleting additional files safely afterwards
if [ "$sync" = true ]
	then args="$args --delete"
fi

sysdirargs=$args

if [ -n "$exclude" ]
then
	args="$args --exclude=$exclude"
	sysdirargs="$args --exclude=grub.cfg"
	rootdirargs="$rootdirargs --exclude=$exclude"

	# don't do this for root and sysdirs
	if [ "$sync" = true ]
		then args="$args --delete-excluded"
	fi
fi

# Use argument if not empty
if [ -n "$1" ]
then
	if [ -n "$2" ]
	then
		sourcedir=$1
		targetdir=$2

		if [ -n "$3" ]
		then
			runmode=$3
		fi
	else
		if [ "$1" != "settings" ]
		then
			targetdir=$1
		fi
	fi
else
	echo "Usage: $scriptname {settings | targetdir | sourcedir targetdir runmode}"
	echo ""
	echo "settings    Use internal script settings"
	echo "sourcedir   Full path to source directory to copy system from"
	echo "targetdir   Full path to target directory to copy system to"
	echo "runmode     Run mode of this script: full, update, grub"
	echo "   full:    does full system copy, including all steps"
	echo "   update:  does filesystem sync only (update of all files from source to target)"
	echo "   grub:    does grub configuration and grub install only"
	exit 1
fi

# One target directory
if [ -n "$targetdir" ]
then
	rootdir=$targetdir
	bootdirpath=$targetdir
	homedirpath=$targetdir
	usrdirpath=$targetdir
	vardirpath=$targetdir
	srvdirpath=$targetdir

	# Deactivate $absolutepaths if using one target directory
	absolutepaths=false
fi

echo "RUNMODE: $runmode"
echo ""
echo "Using ..."
echo "* $sourcedir as source directory"
echo "* $rootdir as directory for / (root)"

# Clear sourcedir if it is set to root, cause we have the slash prefix already everywhere
if [ $sourcedir = "/" ]
	then sourcedir=
fi

report_dirs

if [ "$unattended" != true ]
then
	read -p "Start copy? (y/n) " answer
	if [ "$answer" != "y" ]
	then
		echo "Aborting."
		exit 3
	fi
fi

if [ $runmode = "full" ] || [ $runmode = "update" ]
then
	# Copy /root partition
	echo -n "Copying files of $sourcedir/ directory... "
	rsync $rootdirargs $sourcedir/* $rootdir/
	echo "complete."

    copy_rootdir bin "$sysdirargs"
    copy_rootdir etc "$sysdirargs"
    copy_rootdir lib "$sysdirargs"
	copy_rootdir lib32 "$sysdirargs"
	copy_rootdir lib64 "$sysdirargs"
	copy_rootdir opt "$args"
    copy_rootdir root "$args"
	copy_rootdir sbin "$sysdirargs"
    copy_rootdir selinux "$sysdirargs"
    copy_rootdir snap "$sysdirargs"

	# Copy /boot /home /usr /var /srv partitions or directories
	copy_partition "$bootdirpath" "/boot" "$sysdirargs"
	copy_partition "$homedirpath" "/home" "$args"
	copy_partition "$usrdirpath" "/usr" "$sysdirargs"
	copy_partition "$vardirpath" "/var" "$args"
	copy_partition "$srvdirpath" "/srv" "$args"
fi

if [ $runmode = "full" ]
then
	# Create empty system directories
	echo ""
	echo -n "Creating empty system directories..."
	create_rootdir dev
	create_rootdir media
	create_rootdir mnt
	create_rootdir proc
	chmod u-w $rootdir/proc
	create_rootdir run
	create_rootdir sys
	create_rootdir tmp
	chmod a+w,o+t $rootdir/tmp
	create_rootdir boot; touch $rootdir/boot/not-mounted
	create_rootdir home; touch $rootdir/home/not-mounted
	create_rootdir usr; touch $rootdir/usr/not-mounted
	create_rootdir var; touch $rootdir/var/not-mounted
	create_rootdir srv; touch $rootdir/srv/not-mounted
	echo " complete."

	# Copy symlinks from root dir
	echo -n "Copying system symlinks from root dir..."
	# TODO: 2018-07-23: initrd.img and vmlinuz not there
	cp -a $sourcedir/initrd.img $sourcedir/initrd.img.old $sourcedir/lib64 $sourcedir/vmlinuz $sourcedir/vmlinuz.old $rootdir/
	echo " complete."
fi

if [ $runmode = "full" ] || [ $runmode = "update" ]
then
	# Size checks
	echo ""
	echo "Comparing directory sizes:"

	if [ -n "$bootdirpath" ]
	then
		if [ "$absolutepaths" = true ]
		then compare_dir_sizes "$sourcedir/boot" "$bootdirpath"
		else compare_dir_sizes "$sourcedir/boot" "$bootdirpath/boot"
		fi
	fi

	if [ -n "$homedirpath" ]
	then
		if [ "$absolutepaths" = true ]
		then compare_dir_sizes "$sourcedir/home" "$homedirpath"
		else compare_dir_sizes "$sourcedir/home" "$homedirpath/home"
		fi
	fi

	if [ -n "$usrdirpath" ]
	then
		if [ "$absolutepaths" = true ]
		then compare_dir_sizes "$sourcedir/usr" "$usrdirpath"
		else compare_dir_sizes "$sourcedir/usr" "$usrdirpath/usr"
		fi
	fi

	if [ -n "$vardirpath" ]
	then
		if [ "$absolutepaths" = true ]
		then compare_dir_sizes "$sourcedir/var" "$vardirpath"
		else compare_dir_sizes "$sourcedir/var" "$vardirpath/var"
		fi
	fi

	if [ -n "$srvdirpath" ]
	then
		if [ "$absolutepaths" = true ]
		then compare_dir_sizes "$sourcedir/srv" "$srvdirpath"
		else compare_dir_sizes "$sourcedir/srv" "$srvdirpath/srv"
		fi
	fi

	compare_dir_sizes "$sourcedir/root" "$rootdir"
fi

if [ $runmode = "full" ] || [ $runmode = "grub" ]
then
	# chroot
	echo ""
	echo "Now chroot'ing to $rootdir ..."

	if [ $bootdirpath != $rootdir ]; then mount --bind $bootdirpath $rootdir/boot; fi
	if [ $usrdirpath != $rootdir ]; then mount --bind $usrdirpath $rootdir/usr; fi

	mount --bind /proc $rootdir/proc
	mount --bind /dev $rootdir/dev
	mount --bind /sys $rootdir/sys
	mount --bind /run $rootdir/run

	# Build grub config
	if [ -n "$grubdevice" ] && [ -b $grubdevice ]
		then
			echo -n "  grub-install: "
			chroot $rootdir grub-install --recheck $grubdevice
	fi

	echo "  update-grub:"
	chroot $rootdir update-grub

	if [ $? -eq 0 ]
		then
			# 2017-02-04: added population of fstab
			echo ""
			echo "Writing fstab entries:"
			fstab=$rootdir/etc/fstab
			sed -i -r 's/^/#/' $fstab
			todayis=`date --iso-8601`
			echo "#" >> $fstab
			echo "# $todayis: automatic entries by "`basename $0` >> $fstab
			get_fstab_entry "$rootdir" "/" | tee -a $fstab

			if [ "$absolutepaths" = true ]
			then
				get_fstab_entry "$bootdirpath" "/" | tee -a $fstab
				get_fstab_entry "$homedirpath" "/" | tee -a $fstab
				get_fstab_entry "$usrdirpath" "/" | tee -a $fstab
				get_fstab_entry "$vardirpath" "/" | tee -a $fstab
				get_fstab_entry "$srvdirpath" "/" | tee -a $fstab
			fi

			echo ""
			echo "#################################################################################################"
			echo "IMPORTANT: Verify auto-generated entries in $fstab!"
			echo "#################################################################################################"
		else
			echo "Build of grub config failed!"
	fi

	# Clean up
	if [ $bootdirpath != $rootdir ]; then umount $rootdir/boot; fi
	if [ $usrdirpath != $rootdir ]; then umount $rootdir/usr; fi
	umount $rootdir/proc
	umount $rootdir/dev
	umount $rootdir/sys
	umount $rootdir/run
fi

echo ""
echo "~~~ THE END ~~~"
echo ""
