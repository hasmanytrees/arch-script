#!/bin/bash


git_name=name
git_email=email


packages+=" git"
packages+=" openssh"
packages+=" nodejs"
packages+=" npm"


aur_packages+=" atom-editor-bin"


setup_apps() {
  setup_gtk

  setup_git

  setup_npm
}


setup_gtk() {
  gsettings set org.gnome.shell enabled-extensions "['user-theme@gnome-shell-extensions.gcampax.github.com', 'dash-to-dock@micxgx.gmail.com']"

  gsettings set org.gnome.desktop.interface gtk-theme "Numix-Frost"
	gsettings set org.gnome.desktop.wm.preferences theme "Numix-Frost"
	gsettings set org.gnome.shell.extensions.user-theme name "Numix-Frost"

	gsettings set org.gnome.desktop.interface icon-theme "Numix-Square"
}


setup_git() {
  git config --global user.name "$git_name"
  git config --global user.email "$git_email"

  mkdir ~/.ssh
  ssh-keygen -t rsa -b 4096 -C "$git_email" -N "" -f ~/.ssh/id_rsa

  eval "$(ssh-agent -s)"
  ssh-add ~/.ssh/id_rsa
}


setup_npm() {
  # fix npm permissions
  mkdir -p ~/.npm/.global

  npm config set prefix=~/.npm/.global

  echo -e "export PATH=\$HOME/.npm/.global/bin:\$PATH" >> ~/.bashrc
}


run() {
  pacman -S --needed --noconfirm $packages

  yaourt -S --needed --noconfirm $aur_packages

  setup_apps
}
