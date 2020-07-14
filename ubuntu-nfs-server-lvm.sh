#!/bin/bash

# This script should be executed on Linux Ubuntu Virtual Machine

EXPORT_DIRECTORY=${1:-/export/data}
DATA_DIRECTORY=${2:-/data}
AKS_SUBNET=${3:-*}

echo "Updating packages"
sudo apt-get -y update

echo "Installing NFS kernel server"

sudo apt-get -y install nfs-kernel-server


echo "Check the LVM version."
sudo apt-get -y install lvm2
lvm version

echo "After adding the new disk to the VM we have to rescan de BUS for new attached devices"
echo "- - -" > /sys/class/scsi_host/host2/scan

echo "To display all of the available block storage devices that LVM can potentially manage, use the lvmdiskscan command:"
sudo lvmdiskscan

echo "Return kernel message"
dmesg | grep sdb

echo "Assume the first data disk is added called /dev/sdb and pvcreate"
pvcreate /dev/sdb

echo "Making data directory ${DATA_DIRECTORY}"
pvcreate /dev/sdb

echo "Making new directory to be exported and linked to data directory: ${EXPORT_DIRECTORY}"
vgcreate NFS-SHARE /dev/sdb1

echo "lvcreate 5GB volume"
lvcreate -L 5GB -n NFS-LVM NFS-SHARE

echo "Format the logical disk as EXT4, make new directory and mount it"
mkfs.ext4 /dev/mapper/NFS--SHARE-NFS--LVM 
mkdir /nfs
mount /dev/mapper/NFS--SHARE-NFS--LVM /nfs

echo "write record on /etc/fstab to persist the record"
echo >> "/dev/mapper/NFS--SHARE-NFS--LVM         /nfs    ext4 errors=remount-ro          0       1" /etc/fstab 

echo "configure the NFS share, first of all on a proper hardened O.S. we should be adding permissions at wrapper level for each daemon and network"
cat /etc/hosts.allow 
cat <<EOF >>/etc/fstab
# Created on $(date # : <<-- this will be evaluated before cat;)
portmap: 192.168.1.128/27
lockd: 192.168.1.128/27
mountd: 192.168.1.128/27
rquotad: 192.168.1.128/27
statd: 192.168.1.128/27
EOF

cat /etc/exports 
echo >> "/nfs  192.168.1.135/27(rw,no_root_squash,async) 127.0.0.1/8(rw,no_root_squash,async)" /etc/exports

echo "Restart the portmap service"
service portmap restart

echo "Check the NFS policies configured on the server"
exportfs -a 

nohup service nfs-kernel-server restart