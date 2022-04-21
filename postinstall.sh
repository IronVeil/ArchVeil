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
source /install/settings.sh
source /install/func.sh



### --- LOCALE ---

## Timezone
print "------ Setting timezone"

ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc

## Lang
print "------ Setting locale"

sed -i "161s/#//" /etc/locale.gen
locale-gen

echo "LANG=en_GB.UTF-8
LC_COLLATE=C" >> /etc/locale.conf
echo "KEYMAP=uk" >> /etc/vconsole.conf



### --- HOST ---
print "------ Setting hostname"

## Hostname
echo $system_hostname >> /etc/hostname

## Hosts
echo "127.0.0.1     localhost
::1           localhost
127.0.1.1     $system_hostname.localdomain    $system_hostname" >> /etc/hosts



### --- PACKAGES ---

## Pacman
print "------ Tweaking pacman"

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
print "------ Tweaking make"

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
print "------ Setting up $system_user"

useradd -mG wheel $system_user
echo -e "$system_pass\n$system_pass" | passwd $system_user

# Autologin
if [[ "$system_user_autologin" == "true" ]]; then
    print "------ Setting up autologin for $system_user"

    # Enable autologin
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    echo "[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin $system_user"' - $TERM' >> /etc/systemd/system/getty@tty1.service.d/autologin.conf
fi


## Root
print "------ Setting up root"

# Password
echo -e "$system_root_pass\n$system_root_pass" | passwd root


## Sudo
print "------ Setting up sudo"

# Edit file
echo "root ALL=(ALL:ALL) ALL
%wheel ALL=(ALL:ALL) ALL
@includedir /etc/sudoers.d
Defaults pwfeedback
Defaults insults" >> /etc/sudoers



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
echo | su -c "makepkg -si" $system_user

# Remove dir
cd ../
rm -r yay


## Performance services

# Installing
aur "ananicy-cpp irqbalance memavaild nohang preload prelockd uresourced"

# Enabling
systemctl disable systemd-oomd
systemctl enable ananicy-cpp irqbalance memavaild nohang preload prelockd uresourced

# Enable zram checking
sed -i 's|zram_checking_enabled = False|zram_checking_enabled = True|g' /etc/nohang/nohang.conf


## Sound

# Installing
aur "pipewire-pulse pipewire-jack lib32-pipewire-jack alsa-plugins alsa-firmware sof-firmware alsa-card-profiles"


## Fonts

# Installing
aur "ttf-fira-code ttf-fira-sans noto-fonts noto-fonts-emoji ttf-ms-fonts"


## GUI tweaks
[[ "$system_desktop" != "none" ]] && aur "libappindicator-gtk3 appmenu-gtk-module xdg-desktop-portal"


## Enable need for sudo password
sed -i '$d' /etc/sudoers


### --- SERVICES ---
print "------ Enabling services"


## Networking
[[ "$packages" == *"networkmanager"* ]] && systemctl enable NetworkManager

# DHCPCD
systemctl enable dhcpcd

# VPN
[[ "$system_vpn" == "true" ]] && aur "mullvad-vpn-bin"


## Login managers

# GNOME
if [[ "$system_desktop" == "gnome" ]]; then
    systemctl enable gdm

# Plasma
elif [[ "$system_desktop" == "plasma" ]]; then
    systemctl enable sddm
fi


## Browser

# Brave
if [[ "$software_browser" == "brave" ]]; then
    aur "brave-bin"

# Chrome
elif [[ "$software_browser" == "chrome" ]]; then
    aur "google-chrome"
fi


## pCloud
[[ "$software_pcloud" == "true" ]] && aur "pcloud-drive"


## Extension manager
[[ "$system_desktop" == "gnome" ]] && aur "extension-manager"



### --- BOOTLOADER ---

## mkinitcpio
print "------ Modifying mkinitcpio"

# Filesystem
sed -i "7s/.*/MODULES=($partition_root_format)/" /etc/mkinitcpio.conf

# Encrypted
[[ "$crypt" == "true" ]] && sed -i "52s/.*/HOOKS=(base udev autodetect keyboard keymap modconf block encrypt lvm2 filesystems fsck)/" /etc/mkinitcpio.conf

# Rebuild kernel
mkinitcpio -P


## Bootloader
print "------ Installing bootloader"

## systemd-boot
if [[ "$system_bootloader" == "systemd-boot" ]]; then

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
    if [[ "$crypt" == "true" ]]; then
        echo "options cryptdevice=${uuid}:${crypt_name} root=${crypt_partition} rw quiet splash" >> /boot/loader/entries/arch.conf

        # SSD TRIM support
        [[ "$disk_speed" == "ssd" ]] && sed -i "s/${crypt_name}/${crypt_name}:allow-discards/" /boot/loader/entries/arch.conf

    else
        echo "options root=UUID=$uuid rw quiet splash" >> /boot/loader/entries/arch.conf
    fi

## GRUB
elif [[ "$system_bootloader" == "grub" ]]; then

    # Enable os-prober
    sed -i "63s/#//" /etc/default/grub

    # Toggle delay
    [[ $system_grub_delay ]] && sed -i "4s/5/0/" /etc/default/grub

    # EFI
    [[ "$partition_layout" == "efi" ]] && grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB || grub-install --target=i386-pc $disk_dir

    # Config
    grub-mkconfig -o /boot/grub/grub.cfg
fi