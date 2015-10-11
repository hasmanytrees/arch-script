#!/bin/bash


# short URL is https://goo.gl/thsP5H


target_disk=/dev/sdx
boot_diskpart=${target_disk}1
root_diskpart=${target_disk}2


hostname=hostname


root_password=password
admin_username=username
admin_password=password


packages+=" iw"
packages+=" wpa_actiond"
packages+=" dialog"
packages+=" xorg-server"
packages+=" xorg-xinit"
packages+=" xorg-drivers"
packages+=" mesa"
packages+=" mesa-vdpau"
packages+=" gzip"
packages+=" tar"
packages+=" unzip"
packages+=" unrar"
packages+=" infinality-bundle"

###################################################################################################


err_report() {
    echo "Error on line $1"
}


trap 'err_report $LINENO' ERR


set -e


installer=$(dirname $0)/$(basename $0)


function partition_disk() {
  gdisk $target_disk <<-EOF
o
Y
n


+512M
EF00
n




w
Y
EOF

  pvcreate $root_diskpart

  pvdisplay

  vgcreate vg0 $root_diskpart

  vgdisplay

  lvcreate -L 8G vg0 -n swap

  lvcreate -l +100%FREE vg0 -n root

  lvdisplay
}


function format_mount_partitions() {
  mkswap /dev/mapper/vg0-swap
  mkfs.vfat -n EFI $boot_diskpart
  mkfs.ext4 -L ROOT /dev/mapper/vg0-root

  swapon /dev/mapper/vg0-swap
  mount /dev/mapper/vg0-root /mnt
  mkdir -p /mnt/boot
  mount $boot_diskpart /mnt/boot
}


function os() {
  timedatectl set-ntp true

  partition_disk

  format_mount_partitions

  pacstrap /mnt base base-devel wget

  genfstab -U /mnt > /mnt/etc/fstab

  cp -f $installer /mnt

  arch-chroot /mnt /bin/bash -c "bash /$(basename $0) os2"

  umount -R /mnt

  reboot
}


function set_locale_timezone() {
  sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
  locale-gen
  echo "LANG=en_US.UTF-8" > /etc/locale.conf

  ln -sf /usr/share/zoneinfo/America/Denver /etc/localtime
  hwclock --systohc --utc
}


function install_bootloader() {
  bootctl install

  echo -e "title\tArch Linux" > /boot/loader/entries/arch.conf
  echo -e "linux\t/vmlinuz-linux" >> /boot/loader/entries/arch.conf
  echo -e "initrd\t/initramfs-linux.img" >> /boot/loader/entries/arch.conf
  echo -e "options\troot=UUID=$(blkid -s UUID -o value /dev/mapper/vg0-root) rw" >> /boot/loader/entries/arch.conf

  echo -e "timeout\t3" > /boot/loader/loader.conf
  echo -e "default\tarch" >> /boot/loader/loader.conf
}


function add_infinality_repository() {
  echo -e "" >> /etc/pacman.conf
  echo -e "[infinality-bundle]" >> /etc/pacman.conf
  echo -e "Server = http://bohoomil.com/repo/\$arch" >> /etc/pacman.conf

  # hack to get the key recv to work
  dirmngr < /dev/null

  pacman-key -r 962DDE58

  pacman-key --lsign-key 962DDE58
}


function add_third_party_repositories() {
  add_infinality_repository

  pacman -Sy
}


function update_mirrors() {
  pacman -S reflector

  cp -vf /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup

  reflector --verbose --country 'United States' -l 100 -p http --sort rate --save /etc/pacman.d/mirrorlist
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

  sed -i.bak -r 's/^HOOKS=(.*)block(.*)/HOOKS=\1block lvm2\2/g' /etc/mkinitcpio.conf
  mkinitcpio -p linux

  install_bootloader

  add_third_party_repositories

  update_mirrors

  pacman -S --needed --noconfirm $packages

  systemctl enable netctl-auto@$(iw dev | grep Interface | awk '{print $2}')

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
