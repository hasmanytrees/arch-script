#!/bin/bash

# short URL is https://goo.gl/thsP5H

# update the system clock
timedatectl set-ntp true

# partition the disk
parted ${TARGET} mklabel gpt
parted ${TARGET} mkpart ESP fat32 1MiB 513MiB
parted ${TARGET} set 1 boot on
parted ${TARGET} mkpart primary ext4 513MiB 100%

# format the partitions
mkfs.fat -F32 ${TARGET}1
mkfs.ext4 ${TARGET}2

# mount the partitions
mount ${TARGET}2 /mnt
mkdir -p /mnt/boot
mount ${TARGET}1 /mnt/boot

# select the mirrors

# install the base packages
pacstrap /mnt base base-devel

# configure the system
genfstab -U /mnt > /mnt/etc/fstab

echo "arch" > /mnt/etc/hostname

echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen

arch-chroot /mnt locale-gen

echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf

arch-chroot /mnt ln -sf /usr/share/zoneinfo/UTC /etc/localtime

arch-chroot /mnt hwclock --systohc --utc

# install bootloader
arch-chroot /mnt bootctl install

echo -e "title\tArch Linux" > /mnt/boot/loader/entries/arch.conf
echo -e "linux\t/vmlinuz-linux" >> /mnt/boot/loader/entries/arch.conf
echo -e "initrd\t/initramfs-linux.img" >> /mnt/boot/loader/entries/arch.conf
echo -e "options\troot=PARTUUID=$(blkid -s PARTUUID -o value ${TARGET}2) rw" >> /mnt/boot/loader/entries/arch.conf

echo -e "timeout\t3" > /mnt/boot/loader/loader.conf
echo -e "default\tarch" >> /mnt/boot/loader/loader.conf

arch-chroot /mnt pacman -S iw wpa_supplicant dialog --no-confirm

arch-chroot /mnt pacman -S xorg-server xorg-xinit xorg-drivers --no-confirm

arch-chroot /mnt pacman -S gdm gnome-shell gnome-terminal gnome-control-center gnome-system-monitor gnome-keyring network-manager-applet nautilus xdg-user-dirs -no-confirm

arch-chroot /mnt systemctl enable gdm NetworkManager

arch-chroot /mnt xdg-user-dirs-update

# manage users
arch-chroot /mnt echo root:root | chpasswd

arch-chroot /mnt useradd -m -G wheel -s /bin/bash forrest

arch-chroot /mnt echo forrest:password | chpasswd

arch-chroot /mnt sed -i '/NOPASSWD/!s/# %wheel/%wheel/g' /etc/sudoers

# reboot
umount -R /mnt

reboot



# TODO
#--------------------------------------------
# Add antergos keys
# Install numix-frost-themes
# Install numix-icon-theme-square
# Install ttf-google-fonts
# Install pamac  ?
# Install b43-firmware
# Install broadcom-wl
