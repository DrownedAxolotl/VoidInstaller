echo ##########################
echo Welcome to the Void Linux installer
echo ##########################

echo Select an installation drive
lsblk
read disk
wipefs -a /dev/$disk
fdisk /dev/$disk

lsblk
echo Enter the name of the root partition
read root
#echo Enter the name of the boot partition
#read boot
echo Enter the name of the swap
read swap

echo Enter your hostname
read hostname

#mkfs.ext4 /dev/$boot
mkfs.ext4 /dev/$root
mkswap /dev/$swap
swapon /dev/$swap

:'
mount -o compress=zstd /dev/$root /mnt
btrfs sub create /mnt/@
btrfs sub create /mnt/@home
umount /mnt
'

:'
mount -o compress=zstd,suvol=@ /dev/$root /mnt
mkdir /mnt/boot
mount /dev/$boot /mnt/boot
mkdir /mnt/home
mount -o compress=zstd,suvol=@home /dev/$root /mnt/home
'
mount /dev/$root /mnt

REPO=https://repo-fi.voidlinux.org/current
ARCH=x86_64
XBPS_ARCH=$ARCH xbps-install -Sy -R "$REPO" -r /mnt base-system btrfs-progs

for t in sys dev proc; do mount -o bind /$t /mnt/$t; done
cp /etc/resolv.conf /mnt/etc

echo Entering the chroot environment...
cp chroot.sh /mnt/chroot.sh
chroot /mnt bash chroot.sh

rm /mnt/chroot.sh
