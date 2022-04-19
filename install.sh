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
|                       Install Script                           |
|                                                                |
|----------------------------------------------------------------|
"


## VM
echo
echo "Is this a VM?"

while true; do

    # User input
    read -p "(Y/N) " config_vm
    config_vm=${config_vm,,}

    if [ $config_vm == "y" ]; then
        config_vm=true
        break
    elif [ $config_vm == "n" ]; then
        config_vm=false
        break
    fi
done



### --- DISKS ---

echo -ne "
------------------------------------------------------------------

                      Partitioning Disks

------------------------------------------------------------------
"

# Get current disks
disks=($(lsblk -n --output TYPE,KNAME | awk '$1=="disk"{print "/dev/"$2}'))


## Selection
echo
echo "Which disk do you want to install to?"

while true; do

    # User input
    read -p "/dev/" disk_name
    disk_dir="/dev/$disk_name"

    # Gets type of drive
    if [[ $disk_name == *"sd"* ]]; then
        disk_type="sata"
    elif [[ $disk_name == *"nvme"* ]]; then
        disk_type="nvme"
    fi

    # Checks if disk exists
    if [[ $disk_dir == *"$disks"* ]]; then
        break
    fi

done


## Full disk encryption
echo
echo "Do you want full disk encryption?"

while true; do

    # User input
    read -p "(Y/N) " disk_fde
    disk_fde=${disk_fde,,}

    # Encryption
    if [ $disk_fde == "y" ]; then
        disk_fde=true
        disk_fde_name=cryptsystem

        # Password input
        while true; do
            echo
            read -p "Please enter a password: " -s disk_password
            echo
            read -p "Please enter it again: " -s disk_passwordcheck
            echo

            # Matching passwords
            if [ $disk_password == $disk_passwordcheck ]; then
                break
            else
                echo "Passwords are not the same, try again."
            fi
        done
    fi

    break
done


## EFI or BIOS
echo
echo "Is this an EFI or BIOS system?"

while true; do

    # User input
    read -p "(E/B) " disk_layout
    disk_layout=${disk_layout,,}

    # EFI system
    if [ $disk_layout == "e" ]; then

        # Partitions for SATA drive
        if [ $disk_type == "sata" ]; then
            disk_partition_boot=$disk_dir"1"
            disk_partition_root=$disk_dir"2"

        # Partitions for NVME drive
        elif [ $disk_type == "nvme" ]; then
            disk_partition_boot=$disk_dir"p1"
            disk_partition_root=$disk_dir"p2"
        fi

        break

    # BIOS system
    elif [ $disk_layout == "b" ]; then

        # Partitions for SATA drive
        if [ $disk_type == "sata" ]; then
            disk_partition_bios=$disk_dir"1"
            disk_partition_root=$disk_dir"2"

        # Partitions for NVME drive
        elif [ $disk_type == "nvme" ]; then
            disk_partition_bios=$diskdir"p1"
            disk_partition_root=$disk_dir"p2"
        fi

        break
    fi
done


## Format
echo
echo "Do you want EXT4 or BTRFS?"

while true; do

    # User input
    read -p "(E/B) " disk_format
    disk_format=${disk_format,,}

    if [ $disk_format == "e" ] || [ $disk_format == "b" ]; then
        break
    fi
done


## Checking
echo
echo "Is this all correct?"

echo "VM=$config_vm"
echo "DISK=$disk_dir"

if [ $disk_layout = "e" ]; then
    echo "LAYOUT=EFI"
    echo "BOOT=$disk_partition_boot"
else
    echo "LAYOUT=BIOS"
    echo "BIOS=$disk_partition_bios"
fi

echo "ROOT=$disk_partition_root"
echo "ENCRYPT=$disk_fde"
echo "ENCRYPT PASSWORD=$disk_password"

if [ $disk_format == "e" ]; then
    echo "FORMAT=EXT4"
elif [ $disk_format == "b" ]; then
    echo "FORMAT=BTRFS"
fi

echo

# Confirmation
while true; do
    read -p "(Y/N) " confirm
    confirm=${confirm,,}

    if [ $confirm == "y" ]; then
        break
    elif [ $confirm == "n" ]; then
        exit
    fi
done


## Partitioning
echo
echo "--- Partitioning Drive"

# Unmount
umount $disk_dir*

# Wipe partitions
sgdisk --zap-all $disk_dir

# Partition
if [ $disk_layout == "e" ]; then
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
    ) | fdisk $disk_dir

elif [ $disk_layout == "b" ]; then
    (
        echo g
        echo n
        echo
        echo
        echo +1M
        echo t
        echo 4
        echo n
        echo
        echo
        echo
        echo w
    ) | fdisk $disk_dir
fi


# FDE
if [ $disk_fde == true ]; then

    # Setup encrypted volume
    echo $disk_password | cryptsetup luksFormat $disk_partition_root
    echo $disk_password | cryptsetup open $disk_partition_root $disk_fde_name

    # Set location
    disk_partition_crypt=/dev/mapper/$disk_fde_name

    # Format
    if [ $disk_format == "e" ]; then
        mkfs.ext4 $disk_partition_crypt
    elif [ $disk_format == "b" ]; then
        mkfs.btrfs -f $disk_partition_crypt
    fi
    
    # Mount
    mount $disk_partition_crypt /mnt

else

    # Format
    if [ $disk_format == "e" ]; then
        mkfs.ext4 $disk_partition_root
    elif [ $disk_format == "b" ]; then
        mkfs.btrfs -f $disk_partition_root
    fi

    # Mount
    mount $disk_partition_root /mnt
fi

# Boot
if [ $disk_layout == "e" ]; then

    # Make dir
    mkdir -p /mnt/boot

    # Format
    mkfs.fat -F32 $disk_partition_boot

    # Mount
    mount $disk_partition_boot /mnt/boot
fi



### --- PACKAGES ---
echo -ne "
------------------------------------------------------------------

                      Installing Packages

------------------------------------------------------------------
"

#