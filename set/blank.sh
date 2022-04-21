#!/bin/bash

# SYSTEM
system_vm=
system_cpu=
system_hostname=
system_user=
system_user_autologin=
system_pass=
system_root_pass=
system_kernel=
system_bootloader=
system_grub_delay=
system_desktop=
system_server=
system_vpn=

# DISK
disk_name=
disk_type=
disk_speed=
disk_dir="/dev/$disk_name"

# ENCRYPTION
crypt=
crypt_name=cryptroot
crypt_partition="/dev/mapper/$crypt_name"
crypt_password=

# PARTITIONS
partition_layout=
partition_bios="/dev/${disk_name}1"
partition_boot="/dev/${disk_name}1"
partition_root="/dev/${disk_name}2"
partition_root_format=

# PACKAGES
packages=

# SOFTWARE
software_browser=
software_vscode=
software_cloud=