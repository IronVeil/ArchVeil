#! /bin/bash


### --- FUNCTIONS

## Funky print
funkyprint () {
    echo ""
    echo "------> $1"
}

## Y/N
decision () {
    read choice
    choice=${choice,,}
}


### --- VARIABLES
funkyprint "Lets set some variables!"


## Disk
funkyprint "Please enter the location of the disk:"
read disk

# SATA
if [[ "$disk" == *"sd"* ]]; then
    config_disktype=sata

    partition_boot=$disk"1"
    partition_root=$disk"2"

# NVME
elif [[ "$disk" == *"nvme"* ]]; then
    config_disktype=nvme

    partition_boot=$disk"p1"
    partition_root=$disk"p2"
fi


## FDE
funkyprint "Do you want full disk encryption? (Y/N)"
decision

# Encryption
if [ $choice == "y" ]; then

    # Sets variables
    config_fde=true
    partition_fde=cryptsystem
    partition_fdemount=/dev/mapper/$partition_fde

    # Password input
    funkyprint "Please enter the FDE password:"
    read partition_password

# No encryption
else
    config_fde=false
fi

## Software
funkyprint "What desktop environment do you want? (1-x)"
echo "1) GNOME"
echo "2) KDE Plasma"
echo "3) Cinnamon"

read config_desktop


### --- DEBUG
echo "DRIVE=$disk"
echo "DISKTYPE=$config_disktype"
echo "BOOT=$partition_boot"
echo "ROOT=$partition_root"
echo "FDE=$config_fde"
echo "PASSWORD=$partition_password"
echo "DESKTOP=$config_desktop"
read sdkjfbfdbg



### --- INSTALLATION

## Partitioning
funkyprint "Partitioning drives..."

umount $disk*
(
    echo g
    echo n
    echo
    echo
    echo +512M
    echo t
    echo 1
    echo n
    echo
    echo
    echo
    echo w
) | fdisk $disk


## Formatting
funkyprint "Formatting drives..."

# Encryption
if [ $config_fde == true ]; then

    # Encrypt and unlock drive
    echo $partition_password | cryptsetup luksFormat $partition_root
    echo $partition_password | cryptsetup open $partition_root $partition_fde

    # Format volume
    mkfs.ext4 $partition_fdemount
    e2label $partition_fdemount ROOT

    # Mount volume
    mount $partition_fdemount /mnt

# No encryption
else

    # Format volume
    mkfs.ext4 $partition_root
    e2label $partition_root ROOT

    # Mount volume
    mount $partition_root /mnt
fi


## Boot partition

# Format volume
mkfs.fat -F32 $partition_boot
fatlabel $partition_boot EFI

# Mount volume
mkdir -p /mnt/boot
mount $partition_boot /mnt/boot