########
# INIT #
########


Init ()
{
    ## BASE
    PRODUCT_NAME=gnos
    PRODUCT_VERSION=19.06.2
    INSTALL_VERSION=$PRODUCT_VERSION
    INSTALL_DATE=$( date +%Y%m%d )
    TARGET=/mnt/target

    ## BOOTCLONE
    BOOTCLONE_ROOT=/bootclone-root          # DOC DSET root-repo, relative to ZFS_POOL_NAME
    BOOTCLONE_GRUB=/bootclone-boot          # DOC [zfs-only] DSET grub-boot, relative to ZFS_POOL_NAME
    BOOTCLONE_BOOT=/repo                    # DOC [ext-only] PATH boot-repo, relative to BOOTCLONE_MNTP
    BOOTCLONE_MNTP=/mnt$BOOTCLONE_GRUB      # DOC PATH grub-boot mountpoint
    BOOTCLONE_HEAD=/grub/bootclone-head.cfg # DOC PATH relative to BOOTCLONE_MNTP
    BOOTCLONE_FOOT=/grub/bootclone-foot.cfg # DOC PATH relative to BOOTCLONE_MNTP

    ## NTP
    NTP_SERVERS="pool.ntp.org" # ALT ntp.ubuntu.com ntp.neel.ch

    ## FS types
    BOOT_FS=ext4

    ## LUKS names
    LUKS_BOOT_NAME=crypto-boot
    LUKS_SWAP_NAME=crypto-swap
    LUKS_POOL_NAME=crypto-root

    ## MD names
    UEFI_MD=/dev/md/uefi
    BOOT_MD=/dev/md/boot
    SWAP_MD=/dev/md/swap
    POOL_MD=/dev/md/root

    ## UEFI names
    UEFI_NAME=$PRODUCT_NAME

    ## Topologies
    ZFS_TOPOLOGY_WORDS='mirror|raidz|raidz1|raidz2|raidz3|logs|spares|spare'
    MD_TOPOLOGY_WORDS='linear|stripe|mirror|raid0|raid1|raid4|raid4|raid5|raid6|raid10|0|1|4|5|6|10'

    ## Menu defaults
    DEFAULTS_UBUNTU_RELEASE="bionic"
    DEFAULTS_HOST_HOSTNAME="${PRODUCT_NAME}demo"
    DEFAULTS_USER_USERNAME="user"
    DEFAULTS_LUKS_FORMAT_OPTS="--cipher aes-xts-plain64 --key-size 512 --hash sha512 --iter-time 2000"
    DEFAULTS_ZFS_POOL_NAME="pool"
    DEFAULTS_ZFS_POOL_OPTS="-o ashift=13 -o autoexpand=on -O atime=off -O compression=lz4 -O normalization=formD"
    DEFAULTS_ZFS_ROOT_DSET="root/$PRODUCT_NAME"
    DEFAULTS_ZFS_DATA_DSET="data"

    ## UI
    UI_OPTS="--nocancel --yes-button Next --ok-button Next"
    UI_TEXT="$PRODUCT_NAME v$PRODUCT_VERSION"

    ## Prefs

    # Installer prefs
    INST_PREF="
        INSTALL_MODE
        INSTALL_VERSION
        INSTALL_DATE
        "

    # Zfs prefs
    ZFS_PREF="
        ZFS_POOL_NAME
        ZFS_ROOT_DSET
        ZFS_DATA_DSET
        ZFS_POOL_OPTS
        "

    # Storage prefs
    STOR_PREF="
        STORAGE_OPTIONS
        UEFI_PARTITION
        BOOT_PARTITION
        SWAP_PARTITION
        POOL_TOPOLOGY
        GRUB_DEVICE
        LUKS_FORMAT_OPTS
        $ZFS_PREF
        IRFS_IP
        "

    # Distro prefs
    DISTRO_PREF="
        UBUNTU_RELEASE
        KEYBOARD_MODEL
        KEYBOARD_LAYOUT
        KEYBOARD_VARIANT
        HOST_TIMEZONE
        HOST_HOSTNAME
        USER_USERNAME
        "

    # Security
    SEC_PREF="
        LUKS_PASSWORD
        USER_PASSWORD
        "

    # Generated
    AUTO_PREF="
        BOOT_DEVICE
        SWAP_DEVICE
        POOL_DEVICE
        POOL_PARTITION
        BOOTCLONE_TYPE
        LUKS_KEY
        "

    # Config file prefs
    CORE_PREF="
        $INST_PREF
        $STOR_PREF
        $DISTRO_PREF
        "

    # Mandatory prefs
    CORE_MANDATORY="
        INSTALL_MODE
        ""
        POOL_TOPOLOGY
        ""
        UBUNTU_RELEASE
        KEYBOARD_MODEL
        KEYBOARD_LAYOUT
        HOST_HOSTNAME
        HOST_TIMEZONE
        USER_USERNAME
        "

}



            ###############################
            # !!! DO NOT EDIT BELOW !!! ###
            ###############################
