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
pacman -Sy --noconfirm reflector

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

echo -e "$system_root_pass\n$system_root_pass" | passwd root



### --- SOFTWARE ---

## yay
if [ $extra_aur == "true" ]; then

    # Clone repo
    cd /home/$system_user
    su -c "git clone https://aur.archlinux.org/yay.git" $system_user
    cd yay

    # Make
    su -c "makepkg -si" $system_user

    # Remove dir
    cd ../
    rm -r yay
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



### --- BOOTLOADER ---
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
    
    # Root
    if [ $crypt == "true" ]; then
        break
    else
        uuid=$(blkid -o value -s UUID ${partition_root})
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