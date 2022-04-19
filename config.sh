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
|                        Config Script                           |
|                                                                |
|----------------------------------------------------------------|
"


### --- HOSTNAME ---
echo
echo "Please enter the name of the new system."

while true; do
    
    # User input
    read -p "Name: " system_hostname

    # Validation
    if [ system_hostname != "" ]; then
        break
    fi
done

# Export to file
sed -i "s/system_hostname=.*/system_hostname=$system_hostname/" ./settings.sh

### --- VM ---
echo
echo "Is this a VM?"

while true; do

    # User input
    read -p "(Y/N) " system_vm
    system_vm=${system_vm,,}

    # VM
    if [ $system_vm == "y" ]; then
        system_vm=true
        break
    
    # Bare metal
    elif [ $system_vm == "n" ]; then
        system_vm=false
        break
    fi
done

# Export to file
sed -i "s/system_vm=.*/system_vm=$system_vm/" ./settings.sh



### --- DISKS ---

# Get current disks
disks=($(lsblk -n --output TYPE,KNAME | awk '$1=="disk"{print "/dev/"$2}'))


## Selection
echo

# Output
len=${#disks[@]}
for (( i=0; i<$len; i++ )); do
    echo "${disks[$i]}"
done

echo
echo "Which disk do you want to install to?"

diskcheck=true

while $diskcheck; do

    # User input
    read -p "/dev/" disk_name
    disk_dir="/dev/$disk_name"

    # SATA
    if [[ $disk_name == *"sd"* ]]; then
        disk_type="sata"
    
    # NVME
    elif [[ $disk_name == *"nvme"* ]]; then
        disk_type="nvme"
    fi

    # Checks if disk exists
    for (( i=0; i<$len; i++ )); do
        if [[ $disk_dir == "${disks[$i]}" ]]; then
            diskcheck=false
            break
        fi
    done
done

# Export to file
sed -i "s/disk_name=.*/disk_name=$disk_name/" ./settings.sh
sed -i "s/disk_type=.*/disk_type=$disk_type/" ./settings.sh
sed -i "s~disk_dir=.*~disk_dir=$disk_dir~" ./settings.sh


## Full disk encryption
echo
echo "Do you want full disk encryption?"

while true; do

    # User input
    read -p "(Y/N) " crypt
    crypt=${crypt,,}

    # Encryption
    if [ $crypt == "y" ]; then

        # Password input
        while true; do
            echo
            read -p "Please enter a password: " -s crypt_password
            echo
            read -p "Please enter it again: " -s crypt_password2
            echo

            # Matching passwords
            if [ $crypt_password == $crypt_password2 ]; then
                break
            else
                echo "Passwords are not the same, try again."
            fi
        done

        # Export to file
        sed -i "s/crypt=.*/crypt=true/" ./settings.sh
        sed -i "s/crypt_password=.*/crypt_password=$crypt_password/" ./settings.sh

        break
    
    # Plain
    elif [ $crypt == "n" ]; then

        # Export to file
        sed -i "s/crypt=.*/crypt=false/" ./settings.sh
        sed -i "s/crypt_password=.*/crypt_password=false/" ./settings.sh

        break
    fi
done


## EFI or BIOS
echo
echo "Is this an EFI or BIOS system?"

while true; do

    # User input
    read -p "(E/B) " partition_layout
    partition_layout=${partition_layout,,}
    partition_bios=false
    partition_boot=false

    # EFI system
    if [ $partition_layout == "e" ]; then
        partition_layout="efi"

        # Partitions for SATA drive
        if [ $disk_type == "sata" ]; then
            partition_boot=$disk_dir"1"
            partition_root=$disk_dir"2"

        # Partitions for NVME drive
        elif [ $disk_type == "nvme" ]; then
            partition_boot=$disk_dir"p1"
            partition_root=$disk_dir"p2"
        fi

        break

    # BIOS system
    elif [ $partition_layout == "b" ]; then
        partition_layout="bios"

        # Partitions for SATA drive
        if [ $disk_type == "sata" ]; then
            partition_bios=$disk_dir"1"
            partition_root=$disk_dir"2"

        # Partitions for NVME drive
        elif [ $disk_type == "nvme" ]; then
            partition_bios=$diskdir"p1"
            partition_root=$disk_dir"p2"
        fi

        break
    fi
done

sed -i "s~partition_boot=.*~partition_boot=$partition_boot~" ./settings.sh
sed -i "s~partition_bios=.*~partition_bios=$partition_bios~" ./settings.sh
sed -i "s~partition_root=.*~partition_root=$partition_root~" ./settings.sh
sed -i "s~partition_layout=.*~partition_layout='$partition_layout'~" ./settings.sh



## Format
echo
echo "Do you want EXT4 or BTRFS?"

while true; do

    # User input
    read -p "(E/B) " partition_root_format
    partition_root_format=${partition_root_format,,}

    # EXT4
    if [ $partition_root_format == "e" ]; then
        partition_root_format="ext4"
        break
    
    # BTRFS
    elif [ $partition_root_format == "b" ]; then
        partition_root_format="btrfs"
        break
    fi
done

# Export to file
sed -i "s/partition_root_format=.*/partition_root_format=$partition_root_format/" ./settings.sh


### --- SOFTWARE ---

## Base
if [ $system_vm == "true" ]; then
    package_base="base base-devel linux-firmware"
else
    package_base="base base-devel linux-firmware"
fi


## Kernel
echo
echo "Which kernel do you want?"
echo "1) linux"
echo "2) linux-lts"
echo "3) linux-zen"

while true; do

    # User input
    read -p "(1-3) " package_kernel

    # linux
    if [ $package_kernel == "1" ]; then
        package_kernel="linux linux-headers"
        system_kernel="linux"
        break
    
    # linux-lts
    elif [ $package_kernel == "2" ]; then
        package_kernel="linux-lts linux-lts-headers"
        system_kernel="linux-lts"
        break
    
    # linux-zen
    elif [ $package_kernel == "3" ]; then
        package_kernel="linux-zen linux-zen-headers"
        system_kernel="linux-zen"
        break
    fi
done

## Export to file
sed -i "s/packages=.*/packages=$package_base $package_kernel/" ./settings.sh

### --- INSTALL ---
./install.sh