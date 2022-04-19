#!/bin/bash

# SYSTEM
system_vm=false
system_hostname=test

# DISK
disk_name=sda
disk_type=sata
disk_dir=/dev/sda

# ENCRYPTION
crypt=false
crypt_name="cryptsystem"
crypt_partition=/dev/mapper/$crypt_name
crypt_password=false

# PARTITIONS
partition_layout='efi'
partition_bios=false
partition_boot=/dev/sda1
partition_root=/dev/sda2
partition_root_format=btrfs