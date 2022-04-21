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
|                        Install Script                          |
|                                                                |
|----------------------------------------------------------------|
"


### --- VARIABLES ---
source ./settings.sh
source ./func.sh



### --- CONFIRMATION ---

# TODO: List information

## Confirm
print "Are you sure you want to do this? Type 'YES' in capital letters."

# User input
input "(y/N) "

# Installs or not
[[ "$out" == "YES" ]] || exit



### --- PARTITION ---
print "------ Partitioning $disk_name"

## Unmount
umount /dev/${disk_name}*
umount -R /mnt
cryptsetup close $crypt_partition


## EFI
if [[ "$partition_layout" == "efi" ]]; then
    (
        echo g
        echo n
        echo
        echo
        echo +512M
        echo y
        echo t
        echo 1
        echo n
        echo
        echo
        echo
        echo w
    ) | fdisk $disk_dir

## BIOS
elif [[ "$partition_layout" == "bios" ]]; then
    (
        echo g
        echo n
        echo
        echo
        echo +1M
        echo y
        echo t
        echo 4
        echo n
        echo
        echo
        echo
        echo w
    ) | fdisk $disk_dir
fi


print "------ Formatting $disk_name"

## FDE
if [[ "$crypt" == "true" ]]; then
    echo -e $crypt_password | cryptsetup luksFormat $partition_root
    echo -e $crypt_password | cryptsetup open $partition_root $crypt_name

    # Formats it
    [[ "$partition_root_format" == "ext4" ]] && mkfs.ext4 $crypt_partition || mkfs.btrfs -f $crypt_partition

    # Mounts it
    mount $crypt_partition /mnt

# Plain
else
    # Formats it
    [[ "$partition_root_format" == "ext4" ]] && echo | mkfs.ext4 $partition_root || mkfs.btrfs -f $partition_root

    # Mount
    mount $partition_root /mnt
fi


## Boot
if [[ "$partition_layout" == "efi" ]]; then

    # Format
    mkfs.fat -F32 $partition_boot

    # Mount
    mkdir -p /mnt/boot
    mount $partition_boot /mnt/boot
fi


### --- SOFTWARE ---
print "------ Installing software"

# Parallel downloads
sed -i "37s/#//" /etc/pacman.conf

# Install
pacstrap /mnt $packages


### --- POST INSTALL ---

## fstab
print "------ Generating fstab"

genfstab -U /mnt >> /mnt/etc/fstab


## Post-install script
print "------ Running post-install script"

# Movement
mkdir -p /mnt/install
cp ./{settings.sh,postinstall.sh,func.sh} /mnt/install
chmod -R +x /mnt/install/*

# Use script
arch-chroot /mnt ./install/postinstall.sh