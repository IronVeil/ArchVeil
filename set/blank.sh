#!/bin/bash

# SYSTEM
system_vm=
system_hostname=
system_user=
system_pass=
system_root_pass=
system_kernel=
system_bootloader=

# DISK
disk_name=
disk_type=
disk_dir=

# ENCRYPTION
crypt=
crypt_name="cryptsystem"
crypt_partition=/dev/mapper/$crypt_name
crypt_password=

# PARTITIONS
partition_layout=
partition_bios=
partition_boot=
partition_root=
partition_root_format=

# PACKAGES
packages=