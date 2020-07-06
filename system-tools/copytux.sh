#!/bin/bash
#set -xv
#
# copytux
version="0.8.4"
# (c) Nicolas Krzywinski http://www.nskComputing.de
#
# Created:	    2011-10 by Nicolas Krzywinski
# Description:	Copies complete system files to configured target directories
#
# Last Changed:	2020-05-02
# Change Desc:	disabled rsync --delete-excluded for system directories
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
grubdevice=/dev/sda

# Source directory
sourcedir=/

# Target directory (leave empty to use multiple target directories below)
# Hint: the first argument to this script overrides this parameter
targetdir=/media/nsk/tera6a_mint

# Target directories (empty parameters will be skipped)
rootdir=/media/nsk/evo850_root				# Absolute root dir path
bootdirpath=/media/nsk/evo850_boot			# Absolute boot dir path OR path to place the boot dir INTO
homedirpath=/media/nsk/evo850_home			# Absolute home dir path OR path to place the home dir INTO
usrdirpath=/media/nsk/evo850_usr			# Absolute usr dir path OR path to place the usr dir INTO
vardirpath=/media/nsk/evo850_var			# Absolute var dir path OR path to place the var dir INTO
srvdirpath=/media/nsk/evo850_srv			# Absolute srv dir path OR path to place the srv dir INTO

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
	sysdirargs=$args
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

if [ "$absolutepaths" = true ]
then
	trailingslash="/"
	echo "* $bootdirpath as directory for /boot"
	echo "* $homedirpath as directory for /home"
	echo "* $usrdirpath as directory for /usr"
	echo "* $vardirpath as directory for /var"
	echo "* $srvdirpath as directory for /srv"
else
	trailingslash=
	echo "* $bootdirpath as directory to place /boot into"
	echo "* $homedirpath as directory to place /home into"
	echo "* $usrdirpath as directory to place /usr into"
	echo "* $vardirpath as directory to place /var into"
	echo "* $srvdirpath as directory to place /srv into"
fi

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

	echo -n "Copying $sourcedir/bin directory... "
	rsync $sysdirargs $sourcedir/bin $rootdir/
	echo "complete."

	echo -n "Copying $sourcedir/etc directory... "
	rsync $sysdirargs $sourcedir/etc $rootdir/
	echo "complete."
	
	echo -n "Copying $sourcedir/lib directory... "
	rsync $sysdirargs $sourcedir/lib $rootdir/
	echo "complete."
	
	if [ -d $sourcedir/lib32 ]
	then
		echo -n "Copying $sourcedir/lib32 directory... "
		rsync $sysdirargs $sourcedir/lib32 $rootdir/
		echo "complete."
	else echo "No $sourcedir/lib32 directory - skipped."
	fi
	
	if [ -d $sourcedir/lib64 ]
	then
		echo -n "Copying $sourcedir/lib64 directory... "
		rsync $sysdirargs $sourcedir/lib64 $rootdir/
		echo "complete."
	else echo "No $sourcedir/lib64 directory - skipped."
	fi

	if [ -d $sourcedir/opt ]
	then
		echo -n "Copying $sourcedir/opt directory... "
		rsync $args $sourcedir/opt $rootdir/
		echo "complete."
	else echo "No $sourcedir/opt directory - skipped."
	fi
	
	if [ -d $sourcedir/root ]
	then
		echo -n "Copying $sourcedir/root directory... "
		rsync $args $sourcedir/root $rootdir/
		echo "complete."
	else echo "No $sourcedir/root directory - skipped."
	fi

# 2017-03-07 trying to skip run as this may not needed or break the target system instead
#	if [ -d $sourcedir/run ]
#	then
#		echo -n "Copying $sourcedir/run directory... "
#		rsync $args $sourcedir/run $rootdir/
#		echo "complete."
#	else echo "No $sourcedir/run directory - skipped."
#	fi

	if [ -d $sourcedir/sbin ]
	then
		echo -n "Copying $sourcedir/sbin directory... "
		rsync $sysdirargs $sourcedir/sbin $rootdir/
		echo "complete."
	else echo "No $sourcedir/sbin directory - skipped."
	fi

	if [ -d $sourcedir/selinux ]
	then
		echo -n "Copying $sourcedir/selinux directory... "
		rsync $sysdirargs $sourcedir/selinux $rootdir/
		echo "complete."
	else echo "No $sourcedir/selinux directory - skipped."
	fi


	# Copy /boot /home /usr /var /srv partitions or directories

	if [ -z "$bootdirpath" ]
	then echo "Skipped /boot"
	else
		echo -n "Copying /boot partition..."
		rsync $sysdirargs $sourcedir/boot$trailingslash $bootdirpath
		echo " complete."
	fi

	if [ -z "$homedirpath" ]
	then echo "Skipped /home"
	else
		echo -n "Copying /home partition..."
		rsync $args $sourcedir/home$trailingslash $homedirpath
		echo " complete."
	fi

	if [ -z "$usrdirpath" ]
	then echo "Skipped /usr"
	else
		echo -n "Copying /usr partition..."
		rsync $sysdirargs $sourcedir/usr$trailingslash $usrdirpath
		echo " complete."
	fi

	if [ -z "$vardirpath" ]
	then echo "Skipped /var"
	else
		echo -n "Copying /var partition..."
		rsync $args $sourcedir/var$trailingslash $vardirpath
		echo " complete."
	fi

	if [ -z "$srvdirpath" ]
	then echo "Skipped /srv"
	else
		echo -n "Copying /srv partition..."
		rsync $args $sourcedir/srv$trailingslash $srvdirpath
		echo " complete."
	fi
fi

if [ $runmode = "full" ]
then
	# Create empty system directories
	echo ""
	echo -n "Creating empty system directories..."
	if [ ! -d $rootdir/dev ]; then mkdir $rootdir/dev; fi
	if [ ! -d $rootdir/media ]; then mkdir $rootdir/media; fi
	if [ ! -d $rootdir/mnt ]; then mkdir $rootdir/mnt; fi
	if [ ! -d $rootdir/proc ]; then mkdir $rootdir/proc; fi
	chmod u-w $rootdir/proc
	if [ ! -d $rootdir/run ]; then mkdir $rootdir/run; fi
	if [ ! -d $rootdir/sys ]; then mkdir $rootdir/sys; fi
	if [ ! -d $rootdir/tmp ]; then mkdir $rootdir/tmp; fi
	chmod a+w,o+t $rootdir/tmp
	if [ ! -d $rootdir/boot ]; then mkdir $rootdir/boot; touch $rootdir/boot/not-mounted; fi
	if [ ! -d $rootdir/home ]; then mkdir $rootdir/home; touch $rootdir/home/not-mounted; fi
	if [ ! -d $rootdir/usr ]; then mkdir $rootdir/usr; touch $rootdir/usr/not-mounted; fi
	if [ ! -d $rootdir/var ]; then mkdir $rootdir/var; touch $rootdir/var/not-mounted; fi
	if [ ! -d $rootdir/srv ]; then mkdir $rootdir/srv; touch $rootdir/srv/not-mounted; fi
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
fi

echo ""
echo "~~~ THE END ~~~"
echo ""
