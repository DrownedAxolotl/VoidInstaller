echo ##########################
echo Welcome to the Void Linux installer
echo ##########################

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
echo Enter the name of the swap
read swap

echo Enter your hostname
read hostname

mkfs.ext4 -L boot /dev/$boot
mkfs.btrfs -L void /dev/$root
mkswap /dev/$swap
swapon /dev/$swap


mount -o /dev/$root /mnt
btrfs sub create /mnt/@
btrfs sub create /mnt/@home
umount /mnt

mount -o subvol=@ /dev/$root /mnt
mkdir /mnt/boot
mount /dev/$boot /mnt/boot
mkdir /mnt/home
mount -o subvol=@home /dev/$root /mnt/home


REPO=https://repo-fi.voidlinux.org/current
ARCH=x86_64
XBPS_ARCH=$ARCH xbps-install -Sy -R "$REPO" -r /mnt base-system btrfs-progs

for t in sys dev proc; do mount -o bind /$t /mnt/$t; done
cp /etc/resolv.conf /mnt/etc


id_root=$(blkid -s UUID -o value /dev/$root)
cat << EOF > /mnt/etc/fstab
UUID=$(blkid -s UUID -o value /dev/$swap) none swap sw 0 0
UUID=$(blkid -s UUID -o value /dev/$boot) /boot ext4 defaults 0 2
UUID=$id_root / btrfs subvol=@, defaults 0 1
UUID=$id_root /home btrfs subvol=@home, defaults 0 2
tmpfs /tmp tmpfs defaults,nosuid,nodev 0 0 
EOF


echo $hostname > /etc/hostname
echo Set a root password
passwd

#GRUB setup
chroot /mnt xbps-install -Sy grub
chroot /mnt grub-install /dev/$disk
chroot /mnt update-grub
read
chroot /mnt xbps-reconfigure -fa