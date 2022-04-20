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


### --- SETTINGS ---

# Remove current
rm settings.sh

# Create blank copy
cp ./set/blank.sh ./settings.sh



### --- HOSTNAME ---
echo
echo "Please enter the name of the new system."

while true; do
    
    # User input
    read -p "Name: " system_hostname

    # Validation
    if [ ! -z system_hostname ]; then
        break
    fi
done

# Export to file
sed -i "s/system_hostname=.*/system_hostname=$system_hostname/" ./settings.sh



### --- USER ---
echo
echo "Please enter your username."

while true; do

    # User input
    read -p "Username: " system_user
    system_user=${system_user,,}

    # Validation
    if [ ! -z $system_user ]; then
        break
    fi
done

# Export to file
sed -i "s/system_user=.*/system_user=$system_user/" ./settings.sh


## Password
echo
echo "Please enter your password."

while true; do

    # User input
    read -p "Password: " -s system_pass
    echo

    # Validation
    if [ ! -z $system_pass ]; then
        break
    fi
done

# Export to file
sed -i "s/system_pass=.*/system_pass=$system_pass/" ./settings.sh


## Autologin
echo
echo "Do you want $system_user to autologin?"

while true; do

    # User input
    read -p "(Y/N) " system_user_autologin
    system_user_autologin=${system_user_autologin,,}

    # Autologin
    if [ $system_user_autologin == "y" ]; then
        system_user_autologin=true
        break

    # Manual login
    else
        system_user_autologin=false
        break
    fi
done

# Export to file
sed -i "s/system_user_autologin=.*/system_user_autologin=$system_user_autologin/" ./settings.sh


## Root password
echo
echo "Do you want the root password to be the same as the user password?"

while true; do

    # User input
    read -p "(Y/N) " root_same
    root_same=${root_same,,}

    if [ $root_same == "y" ]; then
        system_root_pass=$system_pass
        break
    fi
done

# Password input
if [ $root_same == "n" ]; then

    # User input
    read -p "Root Password: " -s system_root_pass
    echo

    # Validation
    if [ ! -z system_root_pass ]; then
        break
    fi
fi

# Export to file
sed -i "s/system_root_pass=.*/system_root_pass=$system_root_pass/" ./settings.sh



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
    packages+="base base-devel"
else
    packages+="base base-devel linux-firmware"
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
        packages+=" linux linux-headers"
        system_kernel="linux"
        break
    
    # linux-lts
    elif [ $package_kernel == "2" ]; then
        packages+=" linux-lts linux-lts-headers"
        system_kernel="linux-lts"
        break
    
    # linux-zen
    elif [ $package_kernel == "3" ]; then
        packages+=" linux-zen linux-zen-headers"
        system_kernel="linux-zen"
        break
    fi
done

# Export to file
sed -i "s/system_kernel=/system_kernel=$system_kernel/" ./settings.sh


## Bootloader
echo
echo "Which bootloader do you want?"
echo "1) systemd-boot"
echo "2) GRUB"

while true; do

    # User input
    read -p "(1/2) " package_bootloader

    # systemd-boot
    if [ $package_bootloader == "1" ]; then
        break

    # GRUB
    elif [ $package_bootloader == "2" ]; then
        packages+=" grub os-prober"

        # EFI
        if [ $partition_layout == "efi" ]; then
            packages+=" efibootmgr"
        fi

        ## Timeout
        echo
        echo "Do you want a 5 second delay to select other operating systems?"

        while true; do
            read -p "(Y/N) " system_grub_delay
            system_grub_delay=${system_grub_delay,,}

            # Delay
            if [ $system_grub_delay == "y" ]; then
                system_grub_delay=true
                break
            elif [ $system_grub_delay == "n" ]; then
                system_grub_delay=false
                break
            fi
        done

        break
    fi
done

# Export to file
sed -i "s/system_grub_delay=.*/system_grub_delay=$system_grub_delay/" ./settings.sh


## BTRFS
if [ $partition_root_format == "btrfs" ]; then
    packages+=" btrfs-progs"
fi


## Network
echo
echo "Do you want Wi-Fi through NetworkManager?"

while true; do

    # User input
    read -p "(Y/N) " package_network
    package_network=${package_network,,}

    # Wi-Fi
    if [ $package_network == "y" ]; then
        packages+=" networkmanager"
        break
    
    # Ethernet
    elif [ $package_network == "n" ]; then
        break
    fi
done

# Ethernet
packages+=" dhcpcd"


## Editor
echo
echo "Which editor do you want?"
echo "1) neovim"
echo "2) vim"
echo "3) nano"

while true; do

    # User input
    read -p "(1-3) " package_editor

    # neovim
    if [ $package_editor == "1" ]; then
        packages+=" neovim"
        break

    # vim
    elif [ $package_editor == "2" ]; then
        packages+=" vim"
        break

    # nano
    elif [ $package_editor == "3" ]; then
        packages+=" nano"
        break
    fi
done


## Export to file
sed -i "s/packages=.*/packages='$packages'/" ./settings.sh

### --- INSTALL ---
./install.sh