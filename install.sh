#!/bin/bash


# short URL is https://goo.gl/thsP5H


target_disk=/dev/sdc
boot_diskpart=${target_disk}1
root_diskpart=${target_disk}2


hostname=hostname


root_password=password


admin_username=username
admin_password=password


packages+=" iw"
packages+=" wpa_supplicant"
packages+=" dialog"
packages+=" xorg-server"
packages+=" xorg-xinit"
packages+=" xorg-drivers"
packages+=" mesa"
packages+=" mesa-vdpau"
packages+=" gdm"
packages+=" gnome-shell"
packages+=" gnome-shell-extensions"
packages+=" gnome-keyring"
packages+=" network-manager-applet"
packages+=" gnome-control-center"
packages+=" gnome-system-monitor"
packages+=" gnome-tweak-tool"
packages+=" gnome-terminal"
packages+=" nautilus"
packages+=" xdg-user-dirs-gtk"
packages+=" file-roller"
packages+=" gzip"
packages+=" tar"
packages+=" unzip"
packages+=" unrar"

packages+=" antergos/numix-frost-themes"
packages+=" antergos/numix-icon-theme"
packages+=" antergos/numix-icon-theme-square"
packages+=" antergos/ttf-google-fonts"
packages+=" antergos/pamac"
#packages+=" antergos/gnome-shell-extension-dash-to-dock"
#packages+=" antergos/b43-firmware"
#packages+=" antergos/broadcom-wl"


###################################################################################################


err_report() {
    echo "Error on line $1"
}


trap 'err_report $LINENO' ERR


set -e


installer=$(dirname $0)/$(basename $0)


function partition_disk() {
    parted_commands+=" mklabel gpt"
    parted_commands+=" mkpart ESP fat32 1MiB 513MiB"
    parted_commands+=" set 1 boot on"
    parted_commands+=" mkpart primary ext4 513MiB 100%"

    parted --script $target_disk $parted_commands
}


function format_mount_partitions() {
    mkfs.ext4 $root_diskpart
    mkfs.fat -F32 $boot_diskpart

    mount $root_diskpart /mnt

    mkdir -p /mnt/boot
    mount $boot_diskpart /mnt/boot
}


function os() {
    timedatectl set-ntp true

    partition_disk

    format_mount_partitions

    pacstrap /mnt base base-devel

    genfstab -U /mnt > /mnt/etc/fstab

    cp -f $installer /mnt
    arch-chroot /mnt /bin/bash -c "bash /$(basename $0) os2"

    umount -R /mnt

    reboot
}


function set_locale_timezone() {
    sed -i 's/#en-US.UTF-8/en-US.UTF-8/' /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf

    ln -sf /usr/share/zoneinfo/America/Denver /etc/localtime
    hwclock --systohc --utc
}


function install_bootloader() {
    bootctl install

    echo -e "title\tArch Linux" > /mnt/boot/loader/entries/arch.conf
    echo -e "linux\t/vmlinuz-linux" >> /mnt/boot/loader/entries/arch.conf
    echo -e "initrd\t/initramfs-linux.img" >> /mnt/boot/loader/entries/arch.conf
    echo -e "options\troot=PARTUUID=$(blkid -s PARTUUID -o value ${TARGET}2) rw" >> /mnt/boot/loader/entries/arch.conf

    echo -e "timeout\t3" > /mnt/boot/loader/loader.conf
    echo -e "default\tarch" >> /mnt/boot/loader/loader.conf
}


function install_antergos_keyring() {
    wget http://mirrors.antergos.com/antergos/x86_64/antergos-keyring-20150806-1-any.pkg.tar.xz

    pacman -U antergos-keyring-20150806-1-any.pkg.tar.xz

    pacman-key --init archlinux antergos && pacman-key --populate archlinux antergos

    echo -e "[antergos]" >> /etc/pacman.conf
    echo -e "SigLevel = PackageRequired" >> /etc/pacman.conf
    echo -e "Usage = All" >> /etc/pacman.conf
    echo -e "Server = http://mirrors.antergos.com/$repo/$arch" >> /etc/pacman.conf

    pacman -Syy

    rm antergos-keyring-20150806-1-any.pkg.tar.xz
}


function update_mirrors() {
    pacman -S reflector

    cp -vf /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup

    reflector --verbose --country 'United States' -l 10 -p http --sort rate --save /etc/pacman.d/mirrorlist
}


function manage_users() {
    echo root:$root_password | chpasswd

    useradd -m -G wheel -s /bin/bash $admin_username

    echo $admin_username:$admin_password | chpasswd

    sed -i '/NOPASSWD/!s/# %wheel/%wheel/g' /etc/sudoers
}


function os2() {
    echo $hostname > /etc/hostname

    set_locale_timezone

    install_bootloader

    install_antergos_keyring
    
    update_mirrors

    pacman -S --needed --noconfirm $packages

    systemctl enable gdm NetworkManager

    xdg-user-dirs-update

    manage_users

    # return to os
    exit
}


if [ $1 ]; then
    args=""
    for (( i=2;$i<=$#;i=$i+1 )); do args+=" ${!i}"; done
    eval $1 $args
else
    echo "No option entered (to begin installation enter the option: os)."
fi
