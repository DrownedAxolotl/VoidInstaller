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
echo Enter the name of the EFI System partition
read efi
echo Enter the name of the root partition
read root
echo Enter the name of the swap
read swap

echo Enter your hostname
read hostname

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
mkdir /mnt/boot/efi
mount /dev/$efi /mnt/boot/efi
mkdir /mnt/home
mount -o compress=zstd,subvol=@home /dev/$root /mnt/home


curl https://repo-default.voidlinux.org/live/current/void-x86_64-ROOTFS-20221001.tar.xz > voidlinux.tar.xz
tar -xvf voidlinux.tar.xz -C /mnt

for t in sys dev proc; do mount -o bind /$t /mnt/$t; done
cp /etc/resolv.conf /mnt/etc


id_root=$(blkid -s UUID -o value /dev/$root)
cat << EOF > /mnt/etc/fstab
UUID=$(blkid -s UUID -o value /dev/$swap) none swap sw 0 0
UUID=$(blkid -s UUID -o value /dev/$efi) /boot/efi vfat  defaults 0 2
UUID=$id_root / btrfs compress=zstd,subvol=@, defaults 0 1
UUID=$id_root /home btrfs compress=zstd,subvol=@home, defaults 0 2
tmpfs /tmp tmpfs defaults,nosuid,nodev 0 0 
EOF


chroot /mnt xbps-install -Su xbps
chroot /mnt xbps-install -u
chroot /mnt xbps-install base-system btrfs-progs
chroot /mnt xbps-remove -R base-voidstrap


echo Configuring rc.conf...
echo Do you want to use the Serbian latin keyboard? [Y/n]
read sr_keys

[ $sr_keys = n ] || echo KEYMAP=sr-latin > /mnt/etc/rc.conf 


echo Configuring locales...
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/default/libc-locales
chroot /mnt xbps-reconfigure -f glibc-locales


echo $hostname > /mnt/etc/hostname
echo Set a root password
chroot /mnt passwd

#Refind setup
chroot /mnt xbps-install refind
chroot /mnt refind-install --usedefault /dev/$efi --alldrivers
chroot /mnt mkrlconf
cat << EOF > /mnt/boot/refind_linux.conf
"Boot with standard options" "root=/dev/$root ro rootflags=subvol=@ init=/sbin/init rd.luks=0 rd.md=0 rd.dm=0 loglevel=4 gpt add_efi_memmap vconsole.unicode=1 vconsole.keymap=us locale.LANG=en_US.UTF-8 rd.live.overlay.overlayfs=1"
EOF
chroot /mnt xbps-reconfigure -fa
