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



### --- CONFIRMATION ---
echo
echo "Summary:"
echo
echo "Disk $disk_name will be formatted with a(n) $partition_layout layout."

if [ $crypt == true ]; then
    echo "The root will be encrypted with the name $crypt_name, mounted on $crypt_partition and with the password of $crypt_password. It will have the $partition_root_format filesystem."
else
    echo "The root will be formatted as $partition_root_format."
fi

if [ system_vm == true ]; then
    echo "The system is a VM and is called $system_hostname."
else
    echo "The system will be called $system_hostname"
fi

echo "The base packages to install are: $packages"

## Confirm
while true; do
    echo
    echo "Are you sure you want to do this? Type 'YES' in capital letters."

    read -p "> " confirm

    if [ $confirm == "YES" ]; then
        break
    else
        exit
    fi
done


### --- PARTITION ---
echo "------ Partitioning $disk_name"

# EFI
if [ $partition_layout == "efi" ]; then
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

# BIOS
elif [ $partition_layout == "bios" ]; then
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


echo "------ Formatting $disk_name"

# FDE
if [ $crypt == true ]; then
    echo $crypt_password | cryptsetup luksFormat $partition_root
    echo $crypt_password | cryptsetup open $partition_root $crypt_name

    if [ $partition_root_format == "ext4" ]; then
        mkfs.ext4 $crypt_partition
    elif [ $partition_root_format == "btrfs" ]; then
        mkfs.btrfs $crypt_partition
    fi

    mount $crypt_partition /mnt

else
    if [ $partition_root_format == "ext4" ]; then
        mkfs.ext4 $partition_root
    elif [ $partition_root_format == "btrfs" ]; then
        mkfs.btrfs -f $partition_root
    fi

    mount $partition_root /mnt
fi

# Boot
if [ $partition_layout == "efi" ]; then
    mkdir -p /mnt/boot
    mount $partition_boot /mnt/boot
fi


### --- SOFTWARE
pacstrap /mnt $packages