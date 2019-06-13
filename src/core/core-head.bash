#!/bin/bash

#   ▞▀▖▙ ▌▞▀▖▞▀▖               ▜      ▌
#   ▌▄▖▌▌▌▌ ▌▚▄   ▞▀▌▛▀▖▞▀▖▌  ▌▐ ▞▀▖▞▀▌▞▀▌▞▀▖
#   ▌ ▌▌▝▌▌ ▌▖ ▌  ▚▄▌▌ ▌▌ ▌▐▐▐ ▐ ▛▀ ▌ ▌▚▄▌▛▀
#   ▝▀ ▘ ▘▝▀ ▝▀   ▗▄▘▘ ▘▝▀  ▘▘  ▘▝▀▘▝▀▘▗▄▘▝▀▘

# NAME  GNOS gnowledge Core
# DESC  Setup a minimal ubuntu with advanced storage options, notably ZFS root filesystem and Full Disk Encryption.
# LINK  https://gnos.in

# ARGS  MenuDeploy   Interactive: deploys a new system
# ARGS  MenuExtend   Interactive: appends a new ZFS root dataset to an existing deployment
# ARGS  MenuRescue   Interactive: mounts an existing deployment
# ARGS  Deploy       Silent deployment with configuration file

# FEAT  UEFI         UEFI 2 support
# FEAT  APPLE        Apple EFI 1.5 support

# FEAT  ZFS          ZFS root filesystem
# FEAT  BOOTCLONE    ZFS multirooting

# FEAT  CRYPTO_ROOT  LUKS Full Disk Encryption (except partition tables, and MBR/GRUB/UEFI)
# FEAT  RANDOM       Randomize encrypted space prior to deployment, disable TRIM
# FEAT  CRYPTO_BOOT  Additional LUKS-encrypted ext boot partition, enables unique password prompt for multiple vdevs ZFS pools
# FEAT  PLAIN_BOOT   Additional unencrypted ext boot partition, enables remote LUKS unlock
# FEAT  SSH_UNLOCK   Manual remote LUKS unlock using ssh to get the password prompt



    ##################################
    #                                #
    #   ▞▀▖▙ ▌▞▀▖▞▀▖  ▞▀▖            #
    #   ▌▄▖▌▌▌▌ ▌▚▄   ▌  ▞▀▖▙▀▖▞▀▖   #
    #   ▌ ▌▌▝▌▌ ▌▖ ▌  ▌ ▖▌ ▌▌  ▛▀    #
    #   ▝▀ ▘ ▘▝▀ ▝▀   ▝▀ ▝▀ ▘  ▝▀▘   #
    #                                #
    ##################################

########
# CONF #
########

