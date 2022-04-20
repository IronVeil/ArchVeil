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
|                     Post Install Script                        |
|                                                                |
|----------------------------------------------------------------|
"


### --- VARIABLES ---
source ./settings.sh



### --- LOCALE ---

## Timezone
echo
echo "------ Setting timezone"

ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc

## Lang
echo
echo "------ Setting locale"

sed -i "s/#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/" /etc/locale.gen
locale-gen

echo "LANG=en_GB.UTF-8" >> /etc/locale.conf
echo "LC_COLLATE=C" >> /etc/locale.conf
echo "KEYMAP=uk" >> /etc/vconsole.conf



### --- HOST ---
echo
echo "------ Setting hostname"

## Hostname
echo $system_hostname >> /etc/hostname

## Hosts
echo "127.0.0.1     localhost" >> /etc/hosts
echo "::1           localhost" >> /etc/hosts
echo "127.0.1.1     $system_hostname.localdomain    $system_hostname" >> /etc/hosts



### --- PACKAGES ---

## Pacman
echo
echo "------ Tweaking pacman"

# Color
sed -i "33s/#//" /etc/pacman.conf
sed -i "38i ILoveCandy" /etc/pacman.conf

# Downloads
sed -i "36,37s/#//" /etc/pacman.conf

# Multilib
sed -i "94,95s/#//" /etc/pacman.conf

# Reflector
pacman -Sy --noconfirm reflector rsync

reflector -c GB --sort rate --save /etc/pacman.d/mirrorlist
systemctl enable reflector.timer


## makepkg
echo
echo "------ Tweaking make"

# CFLAGS
sed -i "41s/-march=x86_64 -mtune=generic/-march=native -mtune=native/" /etc/makepkg.conf

# Rust flags
sed -i "47s/.*/RUSTFLAGS='-C opt-level=2 -C target-cpu=native'/" /etc/makepkg.conf

# Make flags
sed -i '49s/.*/MAKEFLAGS="-j$(nproc)"/' /etc/makepkg.conf
sed -i "75s/#//" /etc/makepkg.conf

# Compression
pacman -Sy --noconfirm pigz pbzip2
sed -i "137s/gzip/pigz/" /etc/makepkg.conf
sed -i "138s/bzip2/pbzip2/" /etc/makepkg.conf
sed -i "139s/-z -/-z --threads=0 -/" /etc/makepkg.conf
sed -i "140s/-q -/-q --threads=0 -/" /etc/makepkg.conf
sed -i "151s/.zst//" /etc/makepkg.conf



### --- USERS ---

## Main
echo
echo "------ Setting up $system_user"

useradd -mG wheel $system_user
echo -e "$system_pass\n$system_pass" | passwd $system_user

# Autologin
if [ $system_user_autologin == "true" ]; then
    echo
    echo "------ Setting up autologin for $system_user"

    mkdir -p /etc/systemd/system/getty@tty1.service.d
    echo "[Service]" >> /etc/systemd/system/getty@tty1.service.d/autologin.conf
    echo "ExecStart=" >> /etc/systemd/system/getty@tty1.service.d/autologin.conf
    echo "ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin $system_user"' - $TERM' >> /etc/systemd/system/getty@tty1.service.d/autologin.conf
fi


## Root
echo
echo "------ Setting up root"

# Password
echo -e "$system_root_pass\n$system_root_pass" | passwd root


## Sudo
echo
echo "------ Setting up sudo"

# Edit file
echo "root ALL=(ALL:ALL) ALL
%wheel ALL=(ALL:ALL) ALL
@includedir /etc/sudoers.d
Defaults pwfeedback
Defaults insults" >> /etc/sudoers


## Root
echo
echo "------ Setting up root"

echo -e "$system_root_pass\n$system_root_pass" | passwd root



### --- SOFTWARE ---

## yay

# Disable need for sudo password
echo "$system_user  ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Install needed tools
pacman -Sy --noconfirm go git

# Clone repo
cd /home/$system_user
su -c "git clone https://aur.archlinux.org/yay.git" $system_user
cd yay

# Make
echo -e "$system_pass" | su -c "makepkg -si" $system_user

# Remove dir
cd ../
rm -r yay


## Performance services

# Installing
su -c "yay -S --noconfirm --save --nocleanmenu --nodiffmenu ananicy-cpp irqbalance memavaild nohang preload prelockd uresourced" $system_user

# Enabling
systemctl disable systemd-oomd
systemctl enable ananicy-cpp irqbalance memavaild nohang preload prelockd uresourced

# Enable zram checking
sed -i 's|zram_checking_enabled = False|zram_checking_enabled = True|g' /etc/nohang/nohang.conf

# Enable need for sudo password
sed -i '$d' /etc/sudoers


## Sound

# Installing
yay -S --noconfirm --save --nocleanmenu --nodiffmenu pipewire-pulse pipewire-jack lib32-pipewire-jack alsa-plugins alsa-firmware sof-firmware alsa-card-profiles


## Fonts

# Installing
yay -S --noconfirm --save --nocleanmenu --nodiffmenu ttf-fira-code ttf-fira-sans noto-fonts noto-fonts-emoji ttf-ms-fonts


## GUI tweaks
if [ $system_desktop !- "none" ]; then
    yay -S --noconfirm --save --nocleanmenu --nodiffmenu libappindicator-gtk3 appmenu-gtk-module xdg-desktop-portal
fi


### --- SERVICES ---
echo
echo "------ Enabling services"


## Networking
if [[ $packages == *"networkmanager"* ]]; then
    systemctl enable NetworkManager
fi

# DHCPCD
systemctl enable dhcpcd

# VPN
if [ $system_vpn == "true" ]; then

    # Install
    yay -S --noconfirm --save --nocleanmenu --nodiffmenu mullvad-vpn-bin
fi


## Login managers

# GNOME
if [ $system_desktop == "gnome" ]; then
    systemctl enable gdm

# Plasma
elif [ $system_desktop == "plasma" ]; then
    systemctl enable sddm
fi


## Browser

# Brave
if [ $software_browser == "brave" ]; then
    yay -S --noconfirm --save --nocleanmenu --nodiffmenu brave-bin

# Chrome
elif [ $software_browser == "chrome" ]; then
    yay -S --noconfirm --save --nocleanmenu --nodiffmenu google-chrome
fi


## pCloud
if [ $software_pcloud == "true" ]; then
    yay -S --noconfirm --save --nocleanmenu --nodiffmenu pcloud-drive
fi


## Extension manager
if [ $system_desktop == "gnome" ]; then
    yay -S --noconfirm --save --nocleanmenu --nodiffmenu extension-manager
fi



### --- BOOTLOADER ---

## mkinitcpio
echo
echo "------ Modifying mkinitcpio"

# Filesystem
sed -i "7s/.*/MODULES=($partition_root_format)" /etc/mkinitcpio.conf

# Encrypted
if [ $crypt == "true" ]; then

    # Add hooks
    sed -i "52s/.*/HOOKS=(base udev autodetect keyboard keymap modconf block encrypt lvm2 filesystems fsck)" /etc/mkinitcpio.conf
fi

# Rebuild kernel
mkinitcpio -P


## Bootloader
echo
echo "------ Installing bootloader"

## systemd-boot
if [ $system_bootloader == "systemd-boot" ]; then

    # Install
    bootctl install

    # Add entry
    echo "title Arch Linux" >> /boot/loader/entries/arch.conf

    # Kernel
    echo "linux /vmlinuz-$system_kernel
initrd /${system_cpu}-ucode.img
initrd /initramfs-${system_kernel}.img" >> /boot/loader/entries/arch.conf

    # UUID
    uuid=$(blkid -o value -s UUID ${partition_root})
    
    # Root
    if [ $crypt == "true" ]; then
        echo "options cryptdevice=${uuid}:${crypt_name} root=${crypt_partition} rw quiet splash" >> /boot/loader/entries/arch.conf

        # SSD TRIM support
        if [ $disk_speed == "ssd" ]; then
            sed -i "s/${crypt_name}/${crypt_name}:allow-discards"
        fi

    else
        echo "options root=UUID=$uuid rw quiet splash" >> /boot/loader/entries/arch.conf
    fi

## GRUB
elif [ $system_bootloader == "grub" ]; then

    # Enable os-prober
    sed -i "63s/#//" /etc/default/grub

    # Toggle delay
    if [ $system_grub_delay == "true" ]; then
        sed -i "4s/5/0/" /etc/default/grub
    fi

    # EFI
    if [ $partition_layout == "efi" ]; then

        # Install
        grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

    # BIOS
    elif [ $partition_layout == "bios" ]; then
        
        # Install
        grub-install --target=i386-pc $disk_dir
    fi

    # Config
    grub-mkconfig -o /boot/grub/grub.cfg
fi