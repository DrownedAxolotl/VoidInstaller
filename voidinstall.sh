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
echo Enter your swap name
read swappartition

mkfs.btrfs -L root /dev/$rootpartition
mkswap /dev/$swappartition

swapon /dev/$swappartition

mount -o compress=zstd /dev/$rootpartition /mnt
btrfs sub create /mnt/@
btrfs sub create /mnt/@home
umount /mnt

mount -o compress=zstd,subvol=@ /mnt
mkdir /mnt/home
mount -o compress=zstd,subvol=@home /mnt/home

REPO=https://repo-fi.voidlinux.org/current
ARCH=x86_64

XBPS_ARCH=$ARCH xbps-install -S -r /mnt -R "$REPO" base-system btrfs-progs

mount -o bind /dev /mnt/dev
mount -o bind /proc /mnt/proc
mount -o bind /sys /mnt/sys
mount -o bind /run /mnt/run
cp /etc/resolv.conf /mnt/etc

echo Please choose your hostname
read hostname && echo $hostname >> /mnt/etc/hostname

echo Entering chroot...
echo Set root password
chroot /mnt passwd

echo Choose your username
read username

echo Generating fstab
id_root=$(blkid -s UUID -o value /dev/$rootpartition)
id_swap=$(blkid -s UUID -o value /dev/$swappartition)
cat << STAB >> /mnt/etc/fstab
UUID=$id_swap none swap sw 0 0
UUID=$id_root / btrfs subvol=/@, defaults 0 1
UUID=$id_root /home btrfs subvol=/@home, defaults 0 1
tmpfs /tmp tmpfs defaults,nosuid,nodev 0 0  
STAB

echo Installing GRUB
chroot /mnt xbps-install grub
chroot /mnt grub-install /dev/$diskname

 

