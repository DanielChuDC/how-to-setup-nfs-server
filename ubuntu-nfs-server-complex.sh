#!/bin/bash

usage() {
  echo "Usage:
$0 [-p <LVM physical volume>] [-l <LVM logical volume>] [-f]
 
Options:
 -p physical LVM volume device to extend (check pvdisplay)
 -l logical LVM volume to extend (check lvdisplay)
 -f force extending without a disk rescan. Use this if the OS has detected the enlarged disk already, otherwise we first check whether the underlying disk is larger after a SCSI rescan
    
Example:
./ubuntu-nfs-server-complex.sh -p /dev/sda2 -l /dev/VolGroup/lv_root -f
 
It is highly recommended you backup the boot sector of your disk before as a safety measure with something like the following:
# dd if=/dev/sda of=sda_mbr_backup.mbr bs=512 count=1 
# sfdisk -d /dev/sda > sda_mbr_backup.bak
 
You can restore the partition table then like this:
# dd if=sda_mbr_backup.mbr of=/dev/sda bs=512 count=1
# sfdisk /dev/sda < sda_mbr_backup.bak --force" 1>&2
  exit 1
} 


resizefs_rclocal() {
  # Resize the filesystem using a script in rc.local if the OS run with sysvinit.
  echo "#Cleanup rc.local again
sed -i /etc/rc.local -e '/\/root\/fsresize\.sh/d' --follow-symlinks
sed -i /etc/rc.local -re 's/^#(exit 0)$/\1/' --follow-symlinks" >> /root/fsresize.sh
  
  sed -i /etc/rc.local -re 's/^(exit 0)$/#\1/' --follow-symlinks
  echo "/root/fsresize.sh" >> /etc/rc.local
}

# Get options passed to the script.
while getopts ":p:l:f" o; do
  case "${o}" in
    p)
      p=${OPTARG}
      ;;
    l)
      l=${OPTARG}
      ;;
    f)
      f=1
      ;;
    *)
      usage
      ;;
  esac
done
shift $((OPTIND-1))

echo $OPTIND

if [ -z "${p}" ] || [ -z "${l}" ]
then
  usage
fi


command -v fdisk >/dev/null 2>&1 && command -v parted >/dev/null 2>&1 && command -v pvresize >/dev/null 2>&1 || {
  echo -e "Error: Some of the required utilities (fdisk, parted, lvm tools etc) don't seem to be installed on this system.  Aborting.\n" >&2
  exit 1
}

# Check if a valid LVM physical volume was supplied by verifying the pvdisplay exit code ($?).
pvdisplay $p > /dev/null
if [ $? != 0 ] || ( ! (file $p | grep -q "block special"))
then
  echo -e "Error: $p does not look like a block device or LVM physical volume. Aborting.\n"
  usage
fi

# Check if a valid LVM logical volume was supplied by verifying the lvdisplay exit code ($?).
lvdisplay $l > /dev/null
if [ $? != 0 ]
then
  echo -e "Error: $l does not look like a LVM logical volume. Aborting.\n"
  usage
fi