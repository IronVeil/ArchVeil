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
    echo 'ExecStart=-/sbin/agetty -o "-p -f -- \\u" --noclear --autologin username - $TERM' >> /etc/systemd/system/getty@tty1.service.d/autologin.conf
fi


## Root
echo
echo "------ Setting up root"

echo -e "$system_root_pass\n$system_root_pass" | passwd root



### --- SERVICES ---
echo
echo "------ Enabling services"


## Networking
if [[ $packages == *"networkmanager"* ]]; then
    systemctl enable NetworkManager
fi

# DHCPCD
systemctl enable dhcpcd



### --- BOOTLOADER ---
echo
echo "------ Installing bootloader"

## GRUB
if [[ $packages == *"grub"* ]]; then

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

## systemd-boot
else
    
    # Install
    bootctl install

    # Add entry
    echo "title Arch Linux" >> /boot/loader/entries/arch.conf
    
    # linux
    if [ $system_kernel == "linux" ]; then
        echo "linux /vmlinuz-linux
        initrd /initramfs-linux.img" >> /boot/loader/entries/arch.conf

    # linux-lts
    elif [ $system_kernel == "linux-lts" ]; then
        echo "linux /vmlinuz-linux-lts
        initrd /initramfs-linux-lts.img" >> /boot/loader/entries/arch.conf

    # linux-zen
    elif [ $system_kernel == "linux-zen" ]; then
        echo "linux /vmlinuz-linux-zen
        initrd /initramfs-linux-zen.img" >> /boot/loader/entries/arch.conf
    fi

    # AMD
    if [ $system_cpu == "amd" ]; then
        pacman -Sy --noconfirm amd-ucode
        echo "initrd /amd-ucode.img" >> /boot/loader/entries/arch.conf
    
    # Intel
    elif [ $system_cpu == "intel" ]; then
        pacman -Sy --noconfirm intel-ucode
        echo "initrd /intel-ucode.img" >> /boot/loader/entries/arch.conf
    fi
fi