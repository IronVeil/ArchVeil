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
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc

## Lang
sed -i "s/#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/" /etc/locale.gen

echo "LANG=en_GB.UTF-8" >> /etc/locale.conf
echo "LC_COLLATE=C" >> /etc/locale.conf
echo "KEYMAP=uk" >> /etc/vconsole.conf



### --- HOST ---

## Hostname
echo $system_hostname >> /etc/hostname

## Hosts
echo "127.0.0.1     localhost" >> /etc/hosts
echo "::1           localhost" >> /etc/hosts
echo "127.0.1.1     $system_hostname.localdomain    $system_hostname" >> /etc/hosts



### --- PACKAGES ---

## Pacman

# Color
sed -i "s/#Color/Color/" /etc/pacman.conf
echo "ILoveCandy" >> /etc/pacman.conf

# Downloads
sed -i "s/#VerbosePkgLists/VerbosePkgLists/" /etc/pacman.conf
sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 7/" /etc/pacman.conf

# Multilib
sed -i "s/#[multilib]/[multilib]/" /etc/pacman.conf
sed -i "s~#Include = /etc/pacman.d/mirrorlist~Include = /etc/pacman.d/mirrorlist~" /etc/pacman.conf