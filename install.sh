#!/bin/bash
echo "###############################"
echo Welcome to the Void Linux installer
echo "###############################"

lsblk
echo Select an installation drive
read disk
wipefs -a /dev/$disk
fdisk /dev/$disk

lsblk
echo Enter the name of the root partition
read root
echo Enter the name of the boot partition
read boot
echo Enter the name of the EFI System partition
read efi
echo Enter the name of the swap
read swap

echo Enter your hostname
read hostname

mkfs.ext4 -L boot /dev/$boot
mkfs.btrfs -L void /dev/$root
mkfs.vfat /dev/$efi
mkswap /dev/$swap
swapon /dev/$swap


mount -o compress=zstd /dev/$root /mnt
btrfs sub create /mnt/@
btrfs sub create /mnt/@home
umount /mnt

mount -o compress=zstd,subvol=@ /dev/$root /mnt
mkdir /mnt/boot
mount /dev/$boot /mnt/boot
mkdir /mnt/boot/efi
mount /dev/$efi /mnt/boot/efi
mkdir /mnt/home
mount -o compress=zstd,subvol=@home /dev/$root /mnt/home


REPO=https://repo-fi.voidlinux.org/current
XBPS_ARCH=x86_64 xbps-install -Sy -R "$REPO" -r /mnt base-system btrfs-progs

for t in sys dev proc; do mount -o bind /$t /mnt/$t; done
cp /etc/resolv.conf /mnt/etc


id_root=$(blkid -s UUID -o value /dev/$root)
cat << EOF > /mnt/etc/fstab
UUID=$(blkid -s UUID -o value /dev/$swap) none swap sw 0 0
UUID=$(blkid -s UUID -o value /dev/$boot) /boot ext4 defaults 0 2
UUID=$(blkid -s UUID -o value /dev/$efi) /boot/efi vfat  defaults 0 2
UUID=$id_root / btrfs compress=zstd,subvol=@, defaults 0 1
UUID=$id_root /home btrfs compress=zstd,subvol=@home, defaults 0 2
tmpfs /tmp tmpfs defaults,nosuid,nodev 0 0 
EOF

echo Configuring rc.conf...
echo KEYMAP=sr-latin > /mnt/etc/rc.conf

echo Configuring locales...
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/default/libc-locales
chroot /mnt xbps-reconfigure -f glibc-locales


echo $hostname > /mnt/etc/hostname
echo Set a root password
chroot /mnt passwd

#Refind setup
chroot /mnt xbps-install refind
chroot /mnt refind-install --alldrivers
chroot /mnt xbps-reconfigure -fa
