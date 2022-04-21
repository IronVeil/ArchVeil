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
source ./func.sh



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
        echo
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

# Sets system_vm as a variable
system_vm=$out

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
        if [[ "/dev/${out}" == "${disks[$i]}" ]]; then
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
out=$(cat /sys/block/${disk_name}/queue/rotational)

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
        if [[ "$out" == "$out2" ]] && [[ ! -z "$out2" ]]; then
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

# Sets partition_layout as a variable
partition_layout=$out

# Export to file
wtf partition_layout

# Partitions

# EFI system
if [[ "$out" == "efi" ]] && [[ "$disk_name" == "nvme" ]]; then

    # Change 1 to p1 and 2 to p2
    sed -i 's|partition_boot.*|partition_boot=/dev/${disk_name}p1|' ./settings.sh
    sed -i 's|partition_root.*|partition_root=/dev/${disk_name}p2|' ./settings.sh
fi


## Format
print "Do you want EXT4 or BTRFS?"

# User input
input "(E/b) " 1

# EXT4 or BTRFS
[[ "$out" == "b" ]] && out=btrfs || out=ext4

# Sets partition_root_format
partition_root_format=$out

# Export to file
wtf partition_root_format



### --- SOFTWARE ---

## Base
packages="base base-devel"

# Firmware
[[ $system_vm ]] || packages+=" linux-firmware"


## Kernel
print "Which kernel do you want?"
echo "1) linux *"
echo "2) linux-lts"
echo "3) linux-zen"

# User input
input "(1-3) "

# Selects kernel
case $out in

    # linux-lts
    2)
        out=linux-lts
        ;;

    # linux-zen
    3)
        out=linux-zen
        ;;

    # linux
    *)
        out=linux
        ;;
esac

# Install
packages+=" $out ${out}-headers"

# Export to file
wtf system_kernel


## Microcode

# CPU
cpu=$(grep -m 1 'model name' /proc/cpuinfo)

# Sets to correct brand
[[ "$cpu" == *"AMD"* ]] && out="amd" || out="intel"

# Install
packages+=" ${out}-ucode"

# Export to file
wtf system_cpu


## Bootloader

# BIOS
if [[ "$partition_layout" == "bios" ]]; then
    out="grub"

# EFI
elif [[ "$partition_layout" == "efi" ]]; then

    print "Do you want systemd-boot or GRUB?"

    # User input
    input "(s/G) " 1

    [[ "$out" == "s" ]] && out="systemd-boot" || out="grub"
fi

# Export to file
wtf system_bootloader

# GRUB stuff
if [[ "$out" == "grub" ]]; then

    # Installs
    packages+=" grub os-prober"

    # Installs efibootmgr if needed
    [[ "$partition_layout" == "efi" ]] && packages+=" efibootmgr"

    # Delay
    print "Do you want a 5 second delay to select other operating systems?"
    
    # User input
    input "(Y/n) " 1

    # Enable or disable delay
    [[ "$out" == "n" ]] && out=false || out=true

    # Export to file
    wtf system_grub_delay
fi


## BTRFS
[[ "$system_root_format" == "btrfs" ]] && packages+=" btrfs-progs"


## Network
print "Do you want Wi-Fi through NetworkManager?"

# User input
input "(Y/n) " 1

# Installs DHCPCD
packages+=" dhcpcd"

# Installs networkmanager if needed
[[ "$out" == "n" ]] || packages+=" networkmanager"


## VPN
print "Do you want to install Mullvad?"

# User input
input "(y/N) " 1

# Toggles to install or not
[[ "$out" == "y" ]] && out=true || out=false

# Export to file
wtf system_vpn


## Editor
print "Which editor do you want?"
echo "1) neovim *"
echo "2) vim"
echo "3) nano"

# User input
input "(1-3) "

# Selects editor
case $out in

    # vim
    2)
        packages+=" vim"
        ;;

    # nano
    3)
        packages+=" nano"
        ;;
    
    # neovim
    *)
        packages+=" neovim"
        ;;
esac


## VScode
print "Do you want VS Code?"

# User input
input "(y/N) " 1

# Selects to install or not
[[ "$out" == "y" ]] && out=true || out=false

# Export to file
wtf software_vscode



## Desktop envirnoment
print "Which desktop environment do you want?"
echo "1) None *"
echo "2) GNOME"
echo "3) Cinnamon"
echo "4) KDE Plasma"
echo "5) XFCE"

# User input
input "(1-5) "

# Selects which DE
case $out in

    # GNOME
    2)
        out=gnome
        packages+=" gnome gnome-terminal nautilus python-nautilus gnome-tweak-tool gdm"
        ;;

    # Plasma
    4)
        out=plasma
        packages+=" plasma sddm konsole kalendar dolphin"
        ;;

    # None
    *)
        out=none
        ;;
esac

# Sets system_desktop as a variable
system_desktop=$out

# Export to file
wtf system_desktop


## Desktop server
if [[ "$out" != "none" ]] ; then
    print "Do you want X.ORG or Wayland?"

    # User input
    input "(x/W) " 1

    # X.ORG
    if [[ "$out" == "x" ]]; then
        out="xorg"
        packages+=" xorg"

    # Wayland
    else
        out="wayland"
        packages+=" wayland"

        # KDE
        if [[ "$system_desktop" == "plasma" ]]; then
            packages+=" plasma-wayland-session"
        fi
    fi

    # Export to file
    wtf system_server
fi


## Browser
print "What browser do you want?"

echo "1) None"
echo "2) Firefox *"
echo "3) Brave"
echo "4) Google Chrome"

# User input
input "(1-4) "

# Select browser
case $out in

    # None
    1)
        out=none
        ;;

    # Brave
    3)
        out=brave
        ;;
    
    # Chrome
    4)
        print "Please re-evaluate your life choices"
        out=chrome
        ;;

    # Firefox
    *)
        out=firefox
        packages+=" firefox"
        ;;
esac

# Export to file
wtf software_browser


## pCloud
print "Do you want install cloud-syncing software to manage files?"

# User input
input "(Y/n) " 1

# Installs pCloud or not
[[ "$out" == "n" ]] && out=false || out=true

# Export to file
wtf software_cloud


## Gaming
print "Do you want to install gaming services?"

# User input
input "(y/N) " 1

# Installs gaming stuff or not
[[ "$out" == "y" ]] && out=true || out=false

# Export to file
wtf software_games


## Export to file
out="$packages"

# Export to file
wtf packages

# Add quote marks
sed -i 's|packages=|packages="|' ./settings.sh
sed -i '/packages/ s/$/"/' ./settings.sh



### --- INSTALL ---
./install.sh