#! /bin/bash

echo -ne "
|----------------------------------------------------------------|
|                                                                |
|   ██╗██████╗  ██████╗ ███╗   ██╗██╗   ██╗███████╗██╗██╗        |
|   ██║██╔══██╗██╔═══██╗████╗  ██║██║   ██║██╔════╝██║██║        |
|   ██║██████╔╝██║   ██║██╔██╗ ██║██║   ██║█████╗  ██║██║        |
|   ██║██╔══██╗██║   ██║██║╚██╗██║╚██╗ ██╔╝██╔══╝  ██║██║        |
|   ██║██║  ██║╚██████╔╝██║ ╚████║ ╚████╔╝ ███████╗██║███████╗   |
|   ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝  ╚═══╝  ╚══════╝╚═╝╚══════╝   |
|                                                                |
|                     Post Install Script                        |
|                                                                |
|----------------------------------------------------------------|
"


### --- VARIABLES ---
source ./settings.sh



### --- LOCALE ---

## Timezone
echo "------ Setting timezone"

ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc

## Lang
echo "------ Setting locale"

sed -i "s/#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/" /etc/locale.gen
locale-gen

echo "LANG=en_GB.UTF-8" >> /etc/locale.conf
echo "LC_COLLATE=C" >> /etc/locale.conf
echo "KEYMAP=uk" >> /etc/vconsole.conf



### --- HOST ---
echo "------ Setting hostname"

## Hostname
echo $system_hostname >> /etc/hostname

## Hosts
echo "127.0.0.1     localhost" >> /etc/hosts
echo "::1           localhost" >> /etc/hosts
echo "127.0.1.1     $system_hostname.localdomain    $system_hostname" >> /etc/hosts



### --- PACKAGES ---

## Pacman
echo "------ Tweaking pacman"

# Color
sed -i "33s/#//" /etc/pacman.conf
sed -i "38i ILoveCandy" /etc/pacman.conf

# Downloads
sed -i "36,37s/#//" /etc/pacman.conf

# Multilib
sed -i "94,95s/#//" /etc/pacman.conf


## makepkg
echo "------ Tweaking make"

# CFLAGS
sed -i "41s/-march=x86_64 -mtune=generic/-march=native -mtune=native/" /etc/makepkg.conf

# Rust flags
sed -i "47s/.*/RUSTFLAGS='-C opt-level=2 -C target-cpu=native'/" /etc/makepkg.conf

# Make flags
sed -i '49s/.*/MAKEFLAGS="-j$(nproc)"/' /etc/makepkg.conf
sed -i "75s/#//" /etc/makepkg.conf

# Compression
pacman -Sy --no-confirm pigz pbzip2
sed -i "137s/gzip/pigz/" /etc/makepkg.conf
sed -i "138s/bzip2/pbzip2/" /etc/makepkg.conf
sed -i "139s/-z -/-z --threads=0 -/" /etc/makepkg.conf
sed -i "140s/-q -/-q --threads=0 -/" /etc/makepkg.conf
sed -i "151s/.zst//" /etc/makepkg.conf