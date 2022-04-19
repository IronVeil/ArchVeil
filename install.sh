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


## Confirmation
confirm () {
    while true; do
        read -p "(Y/N) " confirm
        confirm=${confirm,,}

        if [ $confirm == "y" ]; then
            break
        elif [ $confirm == "n" ]; then
            exit
        fi
    done
}


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

# Confirm
confirm


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

# Base
if [ $config_vm == true ]; then
    package_base="base base-devel"
else
    package_base="base base-devel linux-firmware"
fi


## Kernel
echo
echo "What kernel do you want?"
echo "1) linux"
echo "2) linux-lts"
echo "3) linux-zen"

while true; do

    # User input
    read -p "(1-3) " choice

    # linux
    if [ $choice == "1" ]; then
        package_kernel="linux linux-headers"
        break

    # linux-lts
    elif [ $choice == "2" ]; then
        package_kernel="linux-lts linux-lts-headers"
        break

    # linux-zen
    elif [ $choice == "3" ]; then
        package_kernel="linux-zen linux-zen-headers"
        break

    fi
done


## Microcode

# Get cpu
cpu=$(cat /proc/cpuinfo | grep 'model name' | uniq)

# AMD
if [[ $cpu == *"AMD"* ]]; then
    package_microcode="amd-ucode"

# Intel
elif [[ $cpu == *"Intel"* ]]; then
    package_microcode="intel-ucode"
fi


## Bootloader
echo
echo "Do you want systemd-boot or GRUB?"

while true; do
	
	# User input
	read -p "(S/G) " config_bootloader
	config_bootloader=${config_bootloader,,}

	# systemd-boot
	if [ $config_bootloader == "s" ]; then
		config_bootloader="systemd-boot"
		break

	# GRUB
	elif [ $config_bootloader == "g" ]; then
		config_bootloader="grub"
		package_bootloader="grub efibootmgr os-prober"
		break
	fi
done


## Wi-Fi
echo
echo "Do you want NetworkManager?"

while true; do

	# User input
	read -p "(Y/N) " config_networkmanager
	config_networkmanager=${config_networkmanager,,}

	# NetworkManager
	if [ $config_networkmanager == "y" ]; then
		$package_internet="dhcpcd networkmanager"
		break
	
	# Ethernet
	elif [ $config_networkmanager == "n" ]; then
		$package_internet="dhcpcd"
		break
	fi
done


## GUI
echo
echo "Do you want a GUI?"

while true; do
	read -p "(Y/N) " config_gui
	config_gui=${config_gui,,}

	# GUI
	if [ $config_gui == "y" ]; then
		config_gui=true
		break
	
	# Terminal
	elif [ $config_gui == "n" ]; then
		config_gui=false
		break
	fi
done


## GUI programs
if [ $config_gui == true ]; then

	## Backend
	echo
	echo "Do you want X.ORG or Wayland?"
	
	while true; do

		# User input
		read -p "(X,W) " config_displaybackend
		config_displaybackend=${config_displaybackend,,}

		# X.ORG
		if [ $config_displaybackend == "x" ]; then
			package_displaybackend="xorg"
			break

		# Wayland
		elif [ $config_displaybackend == "w" ]; then
			package_displaybackend="wayland"
			break
		fi
	done


	## Desktop environment
	echo
	echo "Which DE do you want?"
	echo "1) GNOME"
	echo "2) KDE Plasma"
	echo "3) Cinnamon"

	while true; do

		# User input
		read -p "(1-3) " config_desktop
		
		# GNOME
		if [ $config_desktop == "1" ]; then
			$package_desktop="gnome gdm gnome-terminal nautilus python-nautilus"
		elif [ $config_desktop == "2" ]; then

			# Wayland
			if [ $config_displaybackend == "w" ]; then
				$package_desktop="plasma dolphin konsole plasma-wayland-session"

			# X.ORG
			else
				$package_desktop="plasma dolphin konsole"
			fi
		fi
	done
fi


## Checking
echo
echo "Is this all correct?"

echo "KERNEL=$package_kernel"
echo "MICROCODE=$package_microcode"
echo "BOOTLOADER=$package_bootloader"
echo "NETWORK=$package_internet"
echo "DISPLAY BACKEND=$package_displaybackend"
echo "DESKTOP=$package_desktop"
echo

confirm
