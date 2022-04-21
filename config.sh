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


### --- FUNCTIONS ---

## Write to file
wtf () { sed -i "s|${1}=|${1}=${out}|" ./settings.sh; }


## Print
print () {
    echo
    echo $1
}


## Lowercase
lower () { out=${1,,}; }


## Input
input () {
    local inp

    # Prompt
    read -p "$1" inp

    # Lowercase it
    [[ "$2" == "1" ]] && lower $inp || out=$inp
}



### --- SETTINGS ---

# Remove current
rm settings.sh &> /dev/null

# Create blank copy
cp ./set/blank.sh ./settings.sh



### --- HOSTNAME ---
print "Please enter the name of the new system."

while true; do
    
    # User input
    input "Hostname: "

    # Validation
    [[ ! -z "$out" ]] && break

done

# Export to file
wtf system_hostname



### --- USER ---
print "Please enter your username."

while true; do

    # User input
    input "Username: " 1

    # Validation
    [[ ! -z "$out" ]] && break

done

# Create system_user variable
system_user=$out

# Export to file
wtf system_user


## Password
print "Please enter ${system_user}'s password."

while true; do

    # User input
    read -p "Password: " -s out
    echo
    read -p "Confirm Password: " -s out2
    echo

    # Validation
    if [[ "$out" == "$out2" ]] && [[ ! -z "$out2" ]]; then
        break
    else
        echo "Passwords are not the same, try again."
    fi
done

# Create system_user variable
system_pass=$out

# Export to file
wtf system_pass


## Autologin
print "Do you want $system_user to autologin?"

# User input
input "(y/N) " 1

# Autologin or not
[[ "$out" == "y" ]] && out=true || out=false

# Export to file
wtf system_user_autologin


## Root password
print "Do you want the root password to be the same as ${system_user}'s password?"

# User input
input "(Y/n) " 1

# Password input
if [[ "$out" == "n" ]]; then

    while true; do

        # User input
        read -p "Password: " -s out
        echo
        read -p "Confirm Password: " -s out2
        echo

        # Validation
        if [[ "$out" == "$out2" ]] && [[ ! -z "$out2" ]]; then
            break
        else
            print "Passwords are not the same, try again."
        fi
    done
else
    out=$system_pass
fi

# Export to file
wtf system_root_pass



### --- VM ---
print "Is this a VM?"

# User input
input "(y/N) " 1

# VM or bare metal
[[ "$out" == "y" ]] && out=true || out=false

# Export to file
wtf system_vm



### --- DISKS ---

# Get current disks
disks=($(lsblk -n --output TYPE,KNAME | awk '$1=="disk"{print "/dev/"$2}'))


## Selection
echo

# Get number of disks
len=${#disks[@]}

# Output them
for (( i=0; i<$len; i++ )); do
    echo "${disks[$i]}"
done

print "Which disk do you want to install to?"

diskcheck=true

while $diskcheck; do

    # User input
    input "/dev/" 1

    # Checks if disk exists
    for (( i=0; i<$len; i++ )); do

        # Matching
        if [[ "/dev/{$out}" == "${disks[$i]}" ]]; then
            diskcheck=false
            break
        fi
    done
done

# Set disk_name as a variable
disk_name=$out

# Export to file
wtf disk_name


## Checks if disk is SATA or NVME

# SATA
if [[ "$disk_name" == *"sd"* ]] || [[ "$disk_name" == *"vd"* ]]; then
    out=sata

# NVME
elif [[ "$disk_name" == *"nvme"* ]]; then
    out=nvme
fi

# Set disk_type as a variable
disk_type=$out

# Export to file
wtf disk_type


## Disk type
out=$(cat /sys/block/${out}/queue/rotational)

# SSD or HDD
[[ "$out" == 1 ]] && out=hdd || out=ssd

# Export to file
wtf disk_speed


## Full disk encryption
print "Do you want full disk encryption?"

# User input
input "(y/N) " 1

# Enable or disable crypt
[[ "$out" == "y" ]] && out=true || out=false

# Export to file
wtf crypt

# Password
if [[ "$out" == true ]]; then

    # Password input
    while true; do
        echo
        read -p "Please enter a password: " -s out
        echo
        read -p "Please enter it again: " -s out2
        echo

        # Matching passwords
        if [[ "$out" == "$out2" ]] && ][ ! -z "$out2" ]]; then
            break
        else
            echo "Passwords are not the same, try again."
        fi
    done

    # Export to file
    wtf crypt_password
fi


## EFI or BIOS
[[ -d /sys/firmware/efi ]] && out=efi || out=bios

# Export to file
wtf partition_layout

# Partitions
#partition_bios=false
#partition_boot=false

# EFI system
if [[ "$out" == "efi" ]] && [[ "$disk_name" == "nvme" ]]; then

    # Change 1 to p1 and 2 to p2
    sed -i 's|partition_boot.*|partition_boot=/dev/${disk_name}p1|'
    sed -i 's|partition_root.*|partition_root=/dev/${disk_name}p2|'


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
        system_kernel="linux"
        break
    
    # linux-lts
    elif [ $package_kernel == "2" ]; then
        system_kernel="linux-lts"
        break
    
    # linux-zen
    elif [ $package_kernel == "3" ]; then
        system_kernel="linux-zen"
        break
    fi
done

# Install
packages+=" $system_kernel ${system_kernel}-headers"

# Export to file
sed -i "s/system_kernel=/system_kernel=$system_kernel/" ./settings.sh


## Microcode

# CPU
cpu=$(grep -m 1 'model name' /proc/cpuinfo)

# AMD
if [[ $cpu == *"AMD"* ]]; then
    system_cpu="amd"

# Intel
elif [[ $cpu == *"Intel"* ]]; then
    system_cpu="intel"
fi

# Install
packages+=" ${system_cpu}-ucode"

# Export to file
sed -i "s/system_cpu=.*/system_cpu=$system_cpu/" ./settings.sh


## Bootloader

# BIOS
if [ $partition_layout == "bios" ]; then
    packages+="grub os-prober"
    system_bootloader="grub"

# EFI
elif [ $partition_layout == "efi" ]; then

    echo
    echo "Which bootloader do you want?"
    echo "1) systemd-boot"
    echo "2) GRUB"

    while true; do

        # User input
        read -p "(1/2) " system_bootloader

        # systemd-boot
        if [ $system_bootloader == "1" ]; then
            system_bootloader="systemd-boot"
            break

        # GRUB
        elif [ $system_bootloader == "2" ]; then
            system_bootloader="grub"
            packages+=" grub os-prober efibootmgr"

            break
        fi
    done
fi

# GRUB Timeout
if [ $system_bootloader == "grub" ]; then
    echo
    echo "Do you want a 5 second delay to select other operating systems?"

    while true; do
        read -p "(Y/N) " system_grub_delay
        system_grub_delay=${system_grub_delay,,}

        # Delay
        if [ $system_grub_delay == "y" ]; then
            system_grub_delay=true
            break

        # No delay
        elif [ $system_grub_delay == "n" ]; then
            system_grub_delay=false
            break
        fi
    done
fi


# Export to file
sed -i "s/system_bootloader=.*/system_bootloader=$system_bootloader/" ./settings.sh
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


## VPN
echo
echo "Do you want to install Mullvad?"

while true; do

    # User input
    read -p "(Y/N) " system_vpn
    system_vpn=${system_vpn}

    # Install vpn
    if [ $system_vpn == "y" ]; then
        system_vpn="true"

        break
    elif [ $system_vpn == "n" ]; then
        system_vpn="false"

        break
    fi
done

# Export to file
sed -i "s/system_vpn=.*/system_vpn=$system_vpn/" ./settings.sh


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


## VScode
echo
echo "Do you want VS Code?"

while true; do
    
    # User input
    read -p "(Y/N) " software_vscode
    software_vscode=${software_vscode,,}

    if [ $software_vscode == "y" ]; then
        software_vscode="true"
        
        break
    elif [ $software_vscode == "n" ]; then
        software_vscode="false"

        break
    fi
done

# Export to file
sed -i "s/software_vscode=.*/software_vscode=$software_vscode/" ./settings.sh


## Desktop envirnoment
echo
echo "Which desktop environment do you want?"
echo "1) None"
echo "2) GNOME"
echo "3) Cinnamon"
echo "4) KDE Plasma"
echo "5) XFCE"

while true; do

    # User input
    read -p "(1-5) " system_desktop

    # None
    if [ $system_desktop == "1" ]; then
        system_desktop="none"
        break
    
    # GNOME
    elif [ $system_desktop == "2" ]; then
        system_desktop="gnome"

        # Install
        packages+=" gnome gnome-terminal nautilus python-nautilus gnome-tweak-tool gdm"

        break

    # Plasma
    elif [ $system_desktop == "4" ]; then
        system_desktop="plasma"

        # Install
        packages+=" plasma sddm konsole kalendar dolphin"

        break
    fi
done


## Desktop server
if [ $system_desktop != "none" ] ; then
    echo
    echo "Do you want X.ORG or Wayland?"

    while true; do

        # User input
        read -p "(X/W) " system_server
        system_server=${system_server,,}

        # X.ORG
        if [ $system_server == "x" ]; then
            system_server="xorg"
            packages+=" xorg"

        # Wayland
        elif [ $system_server == "w" ]; then
            system_server="wayland"
            packages+=" wayland"

            # KDE
            if [ $system_desktop == "plasma" ]; then
                packages+=" plasma-wayland-session"
            fi
        fi
    done
fi

# Export to file
sed -i "s/system_desktop=.*/system_desktop=$system_desktop/" ./settings.sh
sed -i "s/system_server=.*/system_server=$system_server/" ./settings.sh


## Browser
echo
echo "What browser do you want?"
echo "1) None"
echo "2) Firefox"
echo "3) Brave"
echo "4) Google Chrome"

while true; do

    # User input
    read -p "(1-4) " software_browser

    # None
    if [ $software_browser == "1" ]; then
        software_browser="none"

        break
    
    # Firefox
    elif [ $software_browser == "2" ]; then
        software_browser="firefox"

        # Install
        packages+=" firefox"

        break
    
    # Brave
    elif [ $software_browser == "3" ]; then
        software_browser="brave"

        break
    
    # Chrome
    elif [ $software_browser == "4" ]; then
        software_browser="chrome"

        # Insult
        echo
        echo "Please reevaluate your life choices."

        break
    fi
done

# Export to file
sed -i "s/software_browser=.*/software_browser=$software_browser/" ./settings.sh


## pCloud
echo
echo "Do you want pCloud to manage files?"

while true; do

    # User input
    read -p "(Y/N) " $software_pcloud
    software_pcloud=${software_pcloud,,}

    # pCloud
    if [ $software_pcloud == "y" ]; then
        software_pcloud="true"

        break
    
    # No pCloud
    elif [ $software_pcloud == "n" ]; then
        software_pcloud="false"

        break
    fi
done

# Export to file
sed -i "s/software_pcloud=.*/software_pcloud=$software_pcloud/" ./settings.sh


## Export to file
sed -i "s/packages=.*/packages='$packages'/" ./settings.sh

### --- INSTALL ---
./install.sh