#!/bin/bash
echo "Make sure you're online and root"
echo "WARNING! This will erase all data on the selected drive!"
lsblk
echo Choose installation drive
read diskname
wipefs -a /dev/$diskname
fdisk /dev/$diskname

lsblk
echo "Please enter the name of your root partition"
read rootpartition
echo Enter your boot partition
read bootpartition
echo Enter your swap name
read swappartition

mkfs.btrfs /dev/$rootpartition
mkfs.ext4 /dev/$bootpartition
mkswap /dev/$swappartition

swapon /dev/$swappartition

btrfs_args="noatime,compress=zstd"

echo Creating subvolumes
mkdir /mnt/root
mount -o $btrfs_args /dev/$rootpartition /mnt/root
btrfs sub create /mnt/root/@
btrfs sub create /mnt/root/@home
umount /mnt/root

mkdir /mnt/system
mount -o $btrfs_args,subvol=@ /mnt/system
mkdir /mnt/system/home
mount -o $btrfs_args,subvol=@home /mnt/system/home
mkdir /mnt/system/boot
mount /dev/$bootpartition /mnt/system/boot

REPO=https://repo-fi.voidlinux.org/current
ARCH=x86_64

XBPS_ARCH=$ARCH xbps-install -S -r /mnt/system -R "$REPO" base-system btrfs-progs

for t in sys dev proc; do mount --rbind /$t /mnt/system/$t; done
cp /etc/resolv.conf /mnt/system/etc


echo Please choose your hostname
read hostname && echo $hostname > /mnt/system/etc/hostname

echo Entering chroot...
echo Set root password
chroot /mnt/system passwd

echo Choose your username
read username

echo Generating fstab
id_root=$(blkid -s UUID -o value /dev/$rootpartition)
id_swap=$(blkid -s UUID -o value /dev/$swappartition)
id_boot=$(blkid -s UUID -o value /dev/$bootpartition)
cat << STAB > /mnt/etc/fstab
UUID=$id_swap none swap sw 0 0
UUID=$id_root / btrfs $btrfs_args,subvol=/@, defaults 0 1
UUID=$id_root /home btrfs $btrfs_args,subvol=/@home, defaults 0 2
UUID=$id_boot /boot ext4 defaults 0 2
tmpfs /tmp tmpfs defaults,nosuid,nodev 0 0  
STAB

echo Installing GRUB
chroot /mnt/system xbps-install -S grub || echo GRUB installation failed! Clearing space on the install media may fix the issue.
chroot /mnt/system grub-install /dev/$diskname

chroot /mnt/system update-grub

 

