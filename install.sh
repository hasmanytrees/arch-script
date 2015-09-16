#!/bin/bash

# update the system clock
timedatectl set-ntp true

# partition the disk
parted ${TARGET} mklabel gpt
parted ${TARGET} mkpart ESP fat32 1MiB 513MiB
parted ${TARGET} set 1 boot on
parted ${TARGET} mkpart primary ext4 513MiB 100%

# format the partitions
mkfs.fat -F32 ${TARGET}1
mkfs.ext4 ${TARGET}2 -L ArchRoot

# mount the partitions
mount ${TARGET}2 /mnt
mkdir -p /mnt/boot
mount ${TARGET}1 /mnt/boot

# select the mirrors

# install the base packages
pacstrap /mnt base base-devel

# configure the system
genfstab -U /mnt > /mnt/etc/fstab

arch-chroot /mnt /bin/bash

echo "arch" > /etc/hostname

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen

locale-gen

echo "LANG=en_US.UTF-8" > /etc/locale.conf

ln -sf /usr/share/zoneinfo/UTC /etc/localtime

hwclock --systohc--utc

# install bootloader
bootctl install

echo -e "title\tArch Linux" > /boot/loader/entries/arch.conf
echo -e "linux\t/vmlinuz-linux" >> /boot/loader/entries/arch.conf
echo -e "initrd\t/initramfs-linux.img" >> /boot/loader/entries/arch.conf
echo -e "options\troot=Label=ArchRoot rw" >> /boot/loader/entries/arch.conf

echo -e "timeout\t3" > /boot/loader/loader.conf
echo -e "default\tarch" >> /boot/loader/loader.conf

pacman -S iw wpa_supplicant dialog

pacman -S xorg-server xorg-xinit xorg-drivers

pacman -S gdm gnome-shell gnome-terminal gnome-control-center gnome-keyring network-manager-applet nautilus xdg-user-dirs

systemctl enable gdm NetworkManager

xdg-user-dirs-update

# manage users
passwd

useradd -m -G wheel -s /bin/bash forrest

passwd forrest

sed -i '/NOPASSWD/!s/# %wheel/%wheel/g' /etc/sudoers

# reboot
exit

umount -R /mnt

reboot
