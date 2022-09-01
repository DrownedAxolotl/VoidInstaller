echo WELCOME TO THE CHROOT
echo ""
lsblk
echo Enter your chosen disk
read disk
echo Enter your root
read root
echo Enter your swap
read swap
echo Enter your boot
read boot
echo Enter your hostname
read hostname


id_root=$(blkid -s UUID -o value /dev/$root)
cat << EOF > /etc/fstab
UUID=$(blkid -s UUID -o value /dev/$swap) none swap sw 0 0
UUID=$(blkid -s UUID -o value /dev/$boot) /boot ext4 defaults 0 2
UUID=$id_root / btrfs compress=zstd,subvol=/@, defaults 0 1
UUID=$id_root /home btrfs compress=zstd,subvol=/@home, defaults 0 2
tmpfs /tmp tmpfs defaults,nosuid,nodev 0 0 
EOF


echo $hostname > /etc/hostname
echo Set a root password
passwd

#GRUB setup
xbps-install -Sy grub
grub-install /dev/$disk
update-grub
read
xbps-reconfigure -fa