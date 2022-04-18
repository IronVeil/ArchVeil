#! /bin/bash


### FUNCTIONS

# Funky print
funkyprint () {
    echo ""
    echo "------> $1"
}

# Y/N
decision () {
    read choice
    choice=${choice,,}
}


### VARIABLES
funkyprint "Lets set some variables!"


# Disk
funkyprint "Please enter the location of the disk:"
read disk

if [[ "$disk" == *"sd"* ]]; then
    config_disktype=sata

    partition_boot=$disk"1"
    partition_root=$disk"2"
elif [[ "$disk" == *"nvme"* ]]; then
    config_disktype=nvme

    partition_boot=$disk"p1"
    partition_root=$disk"p2"
fi


# FDE
funkyprint "Do you want full disk encryption? (Y/N)"
decision

if [ $choice == "y" ]; then
    config_fde=true
    partition_fde=cryptsystem
    partition_fdemount=/dev/mapper/$partition_fde

    funkyprint "Please enter the FDE password:"

    read partition_password
else
    config_fde=false
fi


### DEBUG
echo "DRIVE=$disk"
echo "DISKTYPE=$config_disktype"
echo "BOOT=$partition_boot"
echo "ROOT=$partition_root"
echo "FDE=$config_fde"
echo "PASSWORD=$partition_password"
read sdkjfbfdbg


### INSTALLATIOn

# Parition
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

funkyprint "Formatting drives..."

if [ $config_fde == true ]; then
    echo $partition_password | cryptsetup luksFormat $partition_root
    echo $partition_password | cryptsetup open $partition_root $partition_fde

    mkfs.ext4 $partition_fdemount
    e2label $partition_fdemount ROOT

    mount $partition_fdemount /mnt

else
    mkfs.ext4 $partition_root
    e2label $partition_root ROOT

    mount $partition_root /mnt
fi

mkfs.fat -F32 $partition_boot
fatlabel $partition_boot EFI

mkdir -p /mnt/boot
mount $partition_boot /mnt/boot