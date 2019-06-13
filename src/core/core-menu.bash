########
# FUNC #  MENU::COMMON
########


Menu ()
{
    INSTALL_MODE=$(
        ui::Menu "Operation mode" "" \
            MenuInstall  "Install a complete system" \
            MenuExtend   "Extend an existing system" \
            MenuRepair   "Repair an existing system" \
            MenuConfig   "Generate a config file"    \
            ""           "Exit"
        )

    $INSTALL_MODE
}


MenuHardware ()
{

    # Keyboard defaults from Xorg
    [[ -z ${KEYBOARD_MODEL+unset} ]]   && KEYBOARD_MODEL=$(   xorg::GetCurrentKeyboardProperty model )
    [[ -z ${KEYBOARD_LAYOUT+unset} ]]  && KEYBOARD_LAYOUT=$(  xorg::GetCurrentKeyboardProperty layout )
    [[ -z ${KEYBOARD_VARIANT+unset} ]] && KEYBOARD_VARIANT=$( xorg::GetCurrentKeyboardProperty variant )

    # Keyboard layout
    KEYBOARD_MODEL=$(   ui::Required UiPickKeyboardModel   "Keyboard model: $KEYBOARD_MODEL"     "$KEYBOARD_MODEL"  )
    KEYBOARD_LAYOUT=$(  ui::Required UiPickKeyboardLayout  "Keyboard layout: $KEYBOARD_LAYOUT"   "$KEYBOARD_LAYOUT" )
    KEYBOARD_VARIANT=$(              UiPickKeyboardVariant "Keyboard variant: $KEYBOARD_VARIANT" "$KEYBOARD_LAYOUT" "$KEYBOARD_VARIANT" )

}


MenuStorageOptions ()
{
    local autofix first=1 depsContinue=0
    local stateUEFI stateAPPLE stateZFS stateBOOTCLONE stateCRYPTO_ROOT stateRANDOM stateCRYPTO_BOOT statePLAIN_BOOT stateSSH_UNLOCK

    while true ; do

        stateUEFI=off
        stateAPPLE=off
        stateZFS=off
        stateBOOTCLONE=off
        stateCRYPTO_ROOT=off
        stateRANDOM=off
        stateCRYPTO_BOOT=off
        statePLAIN_BOOT=off
        stateSSH_UNLOCK=off

        if [[ -z ${STORAGE_OPTIONS+unset} ]] && [[ $first -eq 1 ]] ; then
            first=0
        else
            str::InList UEFI        $STORAGE_OPTIONS && stateUEFI=on
            str::InList APPLE       $STORAGE_OPTIONS && stateAPPLE=on
            str::InList ZFS         $STORAGE_OPTIONS && stateZFS=on
            str::InList BOOTCLONE   $STORAGE_OPTIONS && stateBOOTCLONE=on
            str::InList CRYPTO_ROOT $STORAGE_OPTIONS && stateCRYPTO_ROOT=on
            str::InList RANDOM      $STORAGE_OPTIONS && stateRANDOM=on
            str::InList CRYPTO_BOOT $STORAGE_OPTIONS && stateCRYPTO_BOOT=on
            str::InList PLAIN_BOOT  $STORAGE_OPTIONS && statePLAIN_BOOT=on
            str::InList SSH_UNLOCK  $STORAGE_OPTIONS && stateSSH_UNLOCK=on
        fi

        STORAGE_OPTIONS=$(
            ui::SelectList "${autofix}Storage options" \
                UEFI         "┬─ UEFI boot"                              $stateUEFI           \
                APPLE        "└── Apple EFI on hfs+"                     $stateAPPLE          \
                ZFS          "┬─ ZFS root partition(s)"                  $stateZFS            \
                BOOTCLONE    "└── Bootable root snapshots"               $stateBOOTCLONE       \
                CRYPTO_ROOT  "┬─ Encrypted root partition(s)"            $stateCRYPTO_ROOT    \
                RANDOM       "├── Randomized encrypted partition(s)"     $stateRANDOM         \
                CRYPTO_BOOT  "├── Encrypted boot partition(s)"           $stateCRYPTO_BOOT    \
                PLAIN_BOOT   "└┬─ Clear-text boot partition(s)"          $statePLAIN_BOOT     \
                SSH_UNLOCK   " └── Remote unlock over SSH"               $stateSSH_UNLOCK

        )

        # Autofix dependencies
        depsContinue=0

        if   str::InList APPLE $STORAGE_OPTIONS \
        && ! str::InList UEFI $STORAGE_OPTIONS; then
            STORAGE_OPTIONS="$STORAGE_OPTIONS "UEFI
            depsContinue=1
        fi

        if   str::InList BOOTCLONE $STORAGE_OPTIONS \
        && ! str::InList ZFS $STORAGE_OPTIONS; then
            STORAGE_OPTIONS="$STORAGE_OPTIONS "ZFS
            depsContinue=1
        fi

        if str::InList SSH_UNLOCK $STORAGE_OPTIONS \
        || str::InList MANDOS $STORAGE_OPTIONS ; then
            if ! str::InList PLAIN_BOOT $STORAGE_OPTIONS ; then
                STORAGE_OPTIONS="$STORAGE_OPTIONS "PLAIN_BOOT
                depsContinue=1
            fi
        fi
        if str::InList PLAIN_BOOT $STORAGE_OPTIONS \
        || str::InList CRYPTO_BOOT $STORAGE_OPTIONS \
        || str::InList RANDOM $STORAGE_OPTIONS ; then
            if ! str::InList CRYPTO_ROOT $STORAGE_OPTIONS ; then
                STORAGE_OPTIONS="$STORAGE_OPTIONS "CRYPTO_ROOT
                depsContinue=1
            fi
        fi
        if str::InList PLAIN_BOOT $STORAGE_OPTIONS && str::InList CRYPTO_BOOT $STORAGE_OPTIONS; then
            STORAGE_OPTIONS=$( str::RemoveWord CRYPTO_BOOT $STORAGE_OPTIONS )
            depsContinue=1
        fi
        if [[ $depsContinue -eq 1 ]] ; then
            depsContinue=0
            autofix='[AUTOFIX] '
            continue
        fi
        autofix=

        # Confirm RANDOM
        if str::InList RANDOM $STORAGE_OPTIONS ; then
            ui::Bool \
                "WARNING RANDOM\n───────
Randomizing encrypted space can spend hours depending on your storage size & performance." \
                "Next" "Back" \
            || continue
        fi

        break

    done
}


MenuStorageTopology ()
{

    local poolList poolCount retryZfs=1

    if str::InList ZFS $STORAGE_OPTIONS ; then

        # ZFS POOL_TOPOLOGY
        while [[ $retryZfs -eq 1 ]]; do

            local diskCount=$( lsblk -lno TYPE,KNAME | awk '$1=="disk"{c=c+1}END{print c}' )
            if [[ $diskCount -gt 1 ]] ; then
                # DEV: Several disks => show disks & partitions
                poolList=$(
                    ui::Required UiSelectStorageDevice \
                        "Pool disks/partition(s), multiple means ZFS vdev" \
                        "$( FilterPoolTopology $POOL_TOPOLOGY )"
                )
            else
                # DEV: Only one disk => only show partitions
                poolList=$(
                    ui::Required UiSelectStoragePartition \
                        "Pool partition(s), multiple means ZFS vdev" \
                        "$( FilterPoolTopology $POOL_TOPOLOGY )"
                )
            fi

            local preseedTopo
               [[ -n "$POOL_TOPOLOGY" ]] \
            && [[ "$( str::SortWords $poolList )" != "$( str::SortWords $poolList )" ]] \
            && preseedTopo=$POOL_TOPOLOGY

            poolCount=$( str::GetWordCount $poolList )

            local poolListUser=$( str::SortWords $poolList )
            local poolListPreseed=$( str::SortWords $( FilterPoolTopology "$POOL_TOPOLOGY" ) )

            local poolListChanged=0
            [[ "$poolListUser" != "$poolListPreseed" ]] && poolListChanged=1

            if [[ -z ${POOL_TOPOLOGY+unset} ]] || [[ $poolListChanged -eq 1 ]]; then
                local poolArray
                str::SplitStringByDelimiter " " "$poolList" poolArray

                case $poolCount in
                    # Promote RAID 10
                    4) POOL_TOPOLOGY="mirror ${poolArray[0]} ${poolArray[1]} mirror ${poolArray[2]} ${poolArray[3]}" ;;
                    6) POOL_TOPOLOGY="mirror ${poolArray[0]} ${poolArray[1]} mirror ${poolArray[2]} ${poolArray[3]} mirror ${poolArray[4]} ${poolArray[5]}" ;;
                    8) POOL_TOPOLOGY="mirror ${poolArray[0]} ${poolArray[1]} mirror ${poolArray[2]} ${poolArray[3]} mirror ${poolArray[4]} ${poolArray[5]} mirror ${poolArray[6]} ${poolArray[7]}" ;;
                    # Defaults
                    1) POOL_TOPOLOGY="$poolList"        ;;
                    2) POOL_TOPOLOGY="mirror $poolList" ;;
                    3) POOL_TOPOLOGY="raidz1 $poolList" ;;
                    5) POOL_TOPOLOGY="raidz2 $poolList" ;;
                    *) POOL_TOPOLOGY="raidz3 $poolList" ;;
                esac
            fi

            if [[ $poolCount -eq 1 ]] ;then
                POOL_TOPOLOGY=$poolList
                retryZfs=0
            else

                POOL_TOPOLOGY=$( ui::Required ui::AskSanitized \
                                    "ZFS topology"        \
                                    "$POOL_TOPOLOGY"      \
                                    '/ '
                )

                # Check POOL_TOPOLOGY devices
                poolList=$( str::SortWords $poolList )
                local poolListTopo=$( str::SortWords $( FilterPoolTopology "$POOL_TOPOLOGY" ) )

                if [[ "$poolListTopo" != "$poolList" ]] ; then
                    for dev in $poolListTopo ; do
                        [[ -b "$dev" ]] || ui::Say "Invalid block device: $dev"
                    done
                    ui::Say "Unexpected POOL_TOPOLOGY, please retry"
                else
                    retryZfs=0
                fi

                # Check swap derivation limit
                if   [[ -n "$SWAP_PARTITION" ]]               \
                &&   str::InList CRYPTO_ROOT $STORAGE_OPTIONS \
                && ! str::InList CRYPTO_BOOT $STORAGE_OPTIONS \
                &&   [[ $poolCount -gt 7 ]]                   ; then
                    ui::Bool \
                        "ERROR: Too many pool devices to derive crypto swap from (max=7), either go Back to select less devices or Exit and read the docs about CRYPTO_BOOT or PLAIN_BOOT storage options !" \
                        "Back" "Exit"
                    [[ $? -ne 0 ]] && exit

                    retryZfs=1
                fi

            fi

        done

    else # NOT ZFS

        # MD-RAID POOL_TOPOLOGY

        poolList=$(
            ui::Required UiSelectStoragePartition \
                "Root partition(s), multiple means MD-RAID members" \
                "$( FilterPoolTopology $POOL_TOPOLOGY )" # \
                # "$BOOT_PARTITION $SWAP_PARTITION"
        )

        poolCount=$( str::GetWordCount $poolList )

        if [[ $poolCount -eq 1 ]] ; then
            POOL_TOPOLOGY=$poolList
        else
            local stateRAIDL=off stateRAID0=off stateRAID1=off stateRAID4=off stateRAID5=off stateRAID6=off stateRAID10=off

            if [[ -z ${POOL_TOPOLOGY+unset} ]] ; then
                case $poolCount in
                    2)     stateRAID1=on  ;;
                    3)     stateRAID5=on  ;;
                    4|6|8|10) stateRAID10=on ;;
                    *)     stateRAID6=on  ;;
                esac
            else
                poolList=$POOL_TOPOLOGY
                case $( GetMdTopologyLevel $POOL_TOPOLOGY ) in
                    linear)         stateRAIDL=on  ;;
                    0|raid0|stripe) stateRAID0=on  ;;
                    1|raid1|mirror) stateRAID1=on  ;;
                    4|raid4)        stateRAID4=on  ;;
                    5|raid5)        stateRAID5=on  ;;
                    6|raid6)        stateRAID6=on  ;;
                    10|raid10)      stateRAID10=on ;;
                esac
            fi

            local raidLevel
            if [[ $poolCount -eq 2 ]] ; then
                raidLevel=$(
                    ui::Required ui::PickList "Pool RAID level" \
                        linear  "APPEND"   $stateRAIDL \
                        stripe  "RAID-0"   $stateRAID0 \
                        mirror  "RAID-1"   $stateRAID1
                )
            else
                raidLevel=$(
                    ui::Required ui::PickList "Pool RAID level" \
                        linear  "APPEND"   $stateRAIDL \
                        stripe  "RAID-0"   $stateRAID0 \
                        mirror  "RAID-1"   $stateRAID1 \
                        raid4   "RAID-4"   $stateRAID4 \
                        raid5   "RAID-5"   $stateRAID5 \
                        raid6   "RAID-6"   $stateRAID6 \
                        raid10  "RAID-10"  $stateRAID10
                )
            fi

            POOL_TOPOLOGY="$raidLevel $poolList"

        fi

    fi
}


MenuStorage ()
{
    # STORAGE_OPTIONS
    MenuStorageOptions
    SyncInternals


    # POOL_TOPOLOGY
    MenuStorageTopology
    SyncInternals # DEV: sync $POOL_DEVICE

    local poolExclude
    for dev in $POOL_DEVICE ; do
        if fs::isDeviceType disk $dev &>/dev/null ; then
            for part in $( fs::GetDisksPartitions "$dev" ); do
                poolExclude="$poolExclude /dev/$part"
            done
        fi
    done


    # UEFI_PARTITION
    if str::InList UEFI $STORAGE_OPTIONS ; then
        UEFI_PARTITION=$(
            ui::Required UiSelectStoragePartition                  \
                "UEFI partition(s), multiple means MD-RAID mirror" \
                "$UEFI_PARTITION"                                   \
                "$UEFI_PARTITION $POOL_PARTITION $poolExclude"
        )
    fi


    # BOOT_PARTITION
    if   str::InList CRYPTO_BOOT $STORAGE_OPTIONS \
      || str::InList PLAIN_BOOT  $STORAGE_OPTIONS ; then
        BOOT_PARTITION=$(
            ui::Required UiSelectStoragePartition                   \
                "Boot partition(s), multiple means MD-RAID mirror" \
                "$BOOT_PARTITION"                                   \
                "$UEFI_PARTITION $POOL_PARTITION $poolExclude"
        )
    elif str::InList CRYPTO_ROOT $STORAGE_OPTIONS ; then
        BOOT_PARTITION=
    else
        BOOT_PARTITION=$(
            UiSelectStoragePartition                                            \
                "[OPTIONAL] Boot partition(s), multiple means MD-RAID mirror"  \
                "$BOOT_PARTITION"                                               \
                "$UEFI_PARTITION $POOL_PARTITION $poolExclude"
        )
    fi


    # SWAP_PARTITION
    SWAP_PARTITION=$(
        UiSelectStoragePartition                                            \
            "[OPTIONAL] Swap partition(s), multiple means MD-RAID mirror"  \
            "$SWAP_PARTITION"                                               \
            "$UEFI_PARTITION $BOOT_PARTITION $POOL_PARTITION $poolExclude"
    )



    # GRUB_DEVICE
    if ! str::InList UEFI $STORAGE_OPTIONS ; then

        local partedOutput grubTarget grubTargets=$GRUB_DEVICE

        if [[ -z ${GRUB_DEVICE+unset} ]] ; then
            grubTargets=$(
                  for poolPartition in $POOL_PARTITION $BOOT_PARTITION ; do
                    echo $( fs::GetDeviceDisk $poolPartition )
                  done \
                | sort -u \
                | tr '\n' ' '
                )
        else
            grubTargets=$GRUB_DEVICE
        fi

        while true ; do
            GRUB_DEVICE=$( UiSelectStorageGrub \
                "Grub target(s), use disk(s), partition(s) are unreliable"                            \
                "$grubTargets"                              \
                "$UEFI_PARTITION $BOOT_PARTITION $SWAP_PARTITION $POOL_PARTITION $poolExclude"
            )
            [[ -n "$GRUB_DEVICE" ]] && break
            if ! ui::Bool "Installing NO bootloader" "Back" "I know what I'm doing" ; then
                break
            fi
        done

    fi


    # Keyboard required for LUKS_PASSWORD
    MenuHardware


    # LUKS_PASSWORD
    if str::InList CRYPTO_ROOT $STORAGE_OPTIONS ; then

        if str::InList PLAIN_BOOT $STORAGE_OPTIONS    \
        || [[ KEYBOARD_LAYOUT == "us" ]]              \
        || [[ -n "$LUKS_PASSWORD" ]] # PRESEED
        then
            LUKS_PASSWORD=$( ui::AskPasswordTwice "LUKS password" "$LUKS_PASSWORD" )
        else
            local usPassword
            LUKS_PASSWORD=init
            while [[ "$usPassword" != "$LUKS_PASSWORD" ]] ; do
                LUKS_PASSWORD=$( ui::AskPasswordTwice "LUKS password" )
                ui::Say "WARNING: This encrypted setup has NO BOOT partition.
Early Grub stage will NOT CONFIGURE KEYMAP, password prompt will use US KEYMAP.
Please confirm LUKS_PASSWORD using default US KEYMAP ..."
                xorg::SwitchKeyboardUs
                usPassword=$( ui::AskPassword "LUKS password [US keymap]" )
                xorg::SwitchKeyboardBack
                [[ "$usPassword" != "$LUKS_PASSWORD" ]] && ui::Say "Passwords do not match, please retry"
            done
        fi

        [[ -z ${LUKS_FORMAT_OPTS+unset} ]] && LUKS_FORMAT_OPTS=$DEFAULTS_LUKS_FORMAT_OPTS
        LUKS_FORMAT_OPTS=$( ui::Ask "LUKS options (expert)" "$LUKS_FORMAT_OPTS" )

        # SSH_UNLOCK
        if str::InList SSH_UNLOCK $STORAGE_OPTIONS ; then
            MenuDropbear
        fi
    fi



    # ZFS
    if str::InList ZFS $STORAGE_OPTIONS ; then

        # ZFS_POOL_OPTS
        [[ -z ${ZFS_POOL_OPTS+unset} ]] && ZFS_POOL_OPTS=$DEFAULTS_ZFS_POOL_OPTS
        ZFS_POOL_OPTS=$( ui::Ask "ZFS pool options (expert)" "$ZFS_POOL_OPTS" )

        # ZFS_POOL_NAME
        [[ -z ${ZFS_POOL_NAME+unset} ]] && ZFS_POOL_NAME=$DEFAULTS_ZFS_POOL_NAME
        ZFS_POOL_NAME=$( ui::Required ui::AskSanitized "ZFS pool name" "$ZFS_POOL_NAME" )

        # ZFS_ROOT_DSET
        [[ -z ${ZFS_ROOT_DSET+unset} ]] && ZFS_ROOT_DSET=$DEFAULTS_ZFS_ROOT_DSET
        ZFS_ROOT_DSET=$( ui::Required ui::AskSanitized "ZFS root dataset, relative to $ZFS_POOL_NAME/" "$ZFS_ROOT_DSET" '/' )

        # ZFS_DATA_DSET
        [[ -z ${ZFS_DATA_DSET+unset} ]] && ZFS_DATA_DSET=$DEFAULTS_ZFS_DATA_DSET
        ZFS_DATA_DSET=$( ui::AskSanitized "[OPTIONAL] ZFS data dataset, relative to $ZFS_POOL_NAME/"  "$ZFS_DATA_DSET" '/' )

    fi

}



MenuDropbear ()
{
    if [[ -z ${IRFS_IP+unset} ]] ; then

        # Pick Ethernet interface
        local device=$( ui::Required UiPickNetworkDevice --ethernet \
            "SSH_UNLOCK Ethernet interface" )

        # Choose DHCP / STATIC
        ui::Bool \
            "SSH_UNLOCK IP address assignment ($device)" \
            "DHCP" "Static"

        if [[ $? -eq 0 ]] ; then
            IRFS_IP=":::::$device:dhcp"
            return
        else
            IRFS_IP="192.168.1.68::192.168.1.1:255.255.255.0::$device:off"
        fi
    fi

    # IRFS $IP
    local status=1
    while [[ $status -ne 0 ]] ; do

        IRFS_IP=$( ui::Required ui::AskSanitized \
            "SSH_UNLOCK Static IP address configuration

host::gateway:netmask:hostname:device:'off'" \
            "$IRFS_IP" \
            ':._'
        )

        # TODO CHECK FORMAT # DOC: [host ip]::[gateway ip]:[netmask]:[hostname]:[device]:[autoconf]
        status=0 # STUB

    done
}



MenuVersion ()
{
    # UBUNTU_RELEASE
    [[ -z ${UBUNTU_RELEASE+unset} ]] && UBUNTU_RELEASE=$DEFAULTS_UBUNTU_RELEASE
    local stateBionic=off stateXenial=off
    [[ "$UBUNTU_RELEASE" == "xenial" ]] && stateXenial=on
    [[ "$UBUNTU_RELEASE" == "bionic" ]] && stateBionic=on
    UBUNTU_RELEASE=$(
        ui::Required ui::PickList "Ubuntu release" \
            xenial   "LEGACY      Ubuntu 16.04 LTS  <2021"     $stateXenial  \
            bionic   "RECOMMENDED Ubuntu 18.04 LTS  <2023"     $stateBionic
        )
}



MenuDistro ()
{
    # Timezone
    [[ -z ${HOST_TIMEZONE+unset} ]] && HOST_TIMEZONE=$( wget -O- --timeout=10 --waitretry=0 --tries=5 --retry-connrefused "http://ip-api.com/csv/" 2>/dev/null | cut -d, -f 10 )
    HOST_TIMEZONE=$( ui::Required UiPickTimezone "Timezone configuration" "$HOST_TIMEZONE" )

    # Hostname
    [[ -z ${HOST_HOSTNAME+unset} ]] && HOST_HOSTNAME=$DEFAULTS_HOST_HOSTNAME
    HOST_HOSTNAME=$( ui::Required ui::AskSanitized "Hostname" "$HOST_HOSTNAME" )

    # User
    [[ -z ${USER_USERNAME+unset} ]] && USER_USERNAME=$DEFAULTS_USER_USERNAME
    USER_USERNAME=$( ui::Required ui::AskSanitized "Username" "$USER_USERNAME" )
    USER_PASSWORD=$( ui::AskPasswordTwice "USER password" "$USER_PASSWORD" )
}


MenuReview ()
{
    ui::Text "Please review configuration:\n
$( sys::GetVarsDefinitions $( grep -Ev '^\s*INSTALL_.*$' <<<"$CORE_PREF" ) )"
}


MenuOpen ()
{

    MenuStorageOptions

    SyncInternals


    # ZFS
       str::InList ZFS $STORAGE_OPTIONS \
    && zfs::Install


    local status=1


    ## CRYPTO
    if str::InList CRYPTO_ROOT $STORAGE_OPTIONS ; then
        LUKS_PASSWORD=$( ui::AskPassword "LUKS password" "$LUKS_PASSWORD" )
    fi


    ## BOOT
    while [[ $status -ne 0 ]] ; do

        if   str::InList CRYPTO_BOOT $STORAGE_OPTIONS \
          || str::InList PLAIN_BOOT  $STORAGE_OPTIONS ; then
            BOOT_PARTITION=$(
                ui::Required UiSelectStoragePartition                   \
                    "Boot partition(s), multiple means MD-RAID mirror" \
                    "$BOOT_PARTITION"                                   \
                    "$UEFI_PARTITION"
            )
        elif str::InList CRYPTO_ROOT $STORAGE_OPTIONS ; then
            BOOT_PARTITION=
        else
            BOOT_PARTITION=$(
                UiSelectStoragePartition                                            \
                    "[OPTIONAL] Boot partition(s), multiple means MD-RAID mirror"  \
                    "$BOOT_PARTITION"                                               \
                    "$UEFI_PARTITION"
            )
        fi
        SyncInternals

        [[ -z "$BOOT_PARTITION" ]] && break
        # DEV $HOST_HOSTNAME used by mdadm
        local bootCount=$( str::GetWordCount $BOOT_PARTITION )
        if [[ $bootCount -gt 1 ]] \
        && [[ -z "$HOST_HOSTNAME" ]] \
        && ! str::InList CRYPTO_BOOT $STORAGE_OPTIONS ; then
            HOST_HOSTNAME=$( ui::Required ui::AskSanitized "Hostname" \
                "$(   mdadm --examine $BOOT_PARTITION \
                    | awk '$1=="Name" {idx=index($3,":"); if (idx) print substr($3,0,idx)}' \
                    | sort -u
                )"
            )
        fi
        OpenBoot

        if str::InList CRYPTO_BOOT $STORAGE_OPTIONS ; then
            ls -l /dev/mapper/$LUKS_BOOT_NAME ## [[ -e "/dev/mapper/$LUKS_BOOT_NAME" ]]
        else
            ls -l $BOOT_DEVICE
        fi
        status=$?

        [[ $status -ne 0 ]] && sys::MsgPause "OpenBoot failed"

    done


    ## UEFI
    status=1
    if str::InList UEFI $STORAGE_OPTIONS ; then

        while [[ $status -ne 0 ]] ; do

            UEFI_PARTITION=$(
                ui::Required UiSelectStoragePartition                   \
                    "UEFI partition(s), multiple means MD-RAID mirror" \
                    "$UEFI_PARTITION"
            )

            OpenUefi
            # TODO STUB: check
            status=0
        done
    fi



    ## SWAP
    status=1
    while [[ $status -ne 0 ]] ; do

        SWAP_PARTITION=$( UiSelectStoragePartition "[OPTIONAL] Swap partition(s), multiple means MD-RAID mirror" "$SWAP_PARTITION" "$BOOT_PARTITION" )
        SyncInternals

        [[ -z "$SWAP_PARTITION" ]] && break

        # DEV $HOST_HOSTNAME used by mdadm
        local swapCount=$( str::GetWordCount $SWAP_PARTITION )
        if [[ $swapCount -gt 1 ]] \
        && [[ -z "$HOST_HOSTNAME" ]] \
        && ! str::InList CRYPTO_ROOT $STORAGE_OPTIONS ; then
            HOST_HOSTNAME=$( ui::Required ui::AskSanitized "Hostname" "$HOST_HOSTNAME" )
        fi

        OpenSwap

        # TODO STUB
        status=0

        # if str::InList CRYPTO_ROOT $STORAGE_OPTIONS ; then
        #     ls -l /dev/mapper/$LUKS_SWAP_NAME
        # else
        #     ls -l $SWAP_DEVICE
        # fi
        # status=$?
        # [[ $status -ne 0 ]] && sys::MsgPause "OpenSwap failed"

    done


    ## POOL
    local poolListOld="$( str::SortWords $( FilterPoolTopology $POOL_TOPOLOGY ) )"
    status=1
    while [[ $status -ne 0 ]] ; do

# TODO: REFACTOR ?
# $POOL_PARTITION && OpenPool() NOT required if ZFS && !CRYPTO_ROOT

        local poolList poolSet
        poolList=$( ui::Required UiSelectStoragePartition "Pool partition(s)" "$poolListOld" "$BOOT_PARTITION $SWAP_PARTITION $UEFI_PARTITION" )
# local poolListSorted="$( str::SortWords $poolList )"
        # if [[ "$poolListSorted" != "$poolListOld" ]] ; then

        if [[ "$( str::SortWords $poolList )" != "$poolListOld" ]] ; then
            for dev in $poolListOld ; do
                if str::InList $dev $poolListOld ; then
                    sys::MsgPause "ERROR: Device $dev was mentioned in config file"
                    continue
                fi
            done
            poolSet=1
        fi

        local poolCount=$( str::GetWordCount $poolList )

        if [[ $poolSet -eq 1 ]] ; then

            if [[ $poolCount -gt 1 ]] ; then
                if ! str::InList ZFS         $STORAGE_OPTIONS \
                && ! str::InList CRYPTO_ROOT $STORAGE_OPTIONS \
                && [[ -z "$HOST_HOSTNAME" ]] ; then

                    # DEV: $POOL_TOPOLOGY required by mdadm
                    local raidLevel=$(
                        ui::Required ui::PickList "Pool RAID level" \
                            linear  "APPEND"   off \
                            stripe  "RAID-0"   off \
                            mirror  "RAID-1"   off \
                            raid4   "RAID-4"   off \
                            raid5   "RAID-5"   off \
                            raid6   "RAID-6"   off \
                            raid10  "RAID-10"  off
                    )
                    POOL_TOPOLOGY="$raidLevel $poolList"

                    # DEV: $HOST_HOSTNAME required by mdadm
                    HOST_HOSTNAME=$( ui::Required ui::AskSanitized "Hostname" "$HOST_HOSTNAME" )

                elif str::InList ZFS         $STORAGE_OPTIONS ; then

                    if [[ $poolCount -eq 1 ]] ;then
                        POOL_TOPOLOGY=$poolList
                        retryZfs=0
                    else

                        POOL_TOPOLOGY=$( ui::Required ui::AskSanitized \
                                            "ZFS topology"        \
                                            "$POOL_TOPOLOGY"      \
                                            '/ '
                        )

                        # Check POOL_TOPOLOGY devices
                        poolList=$( str::SortWords $poolList )
                        local poolListTopo=$( str::SortWords $( FilterPoolTopology "$POOL_TOPOLOGY" ) )

                        if [[ "$poolListTopo" != "$poolList" ]] ; then
                            for dev in $poolListTopo ; do
                                [[ -b "$dev" ]] || ui::Say "Invalid block device: $dev"
                            done
                            ui::Say "Unexpected POOL_TOPOLOGY, please retry"
                            continue
                        fi

                        # TODO Check swap derivation limit ?
                    fi

                fi
            else
                POOL_TOPOLOGY=$poolList
            fi
        fi

        SyncInternals

        OpenPool

        # Checks

        if str::InList CRYPTO_ROOT $STORAGE_OPTIONS ; then

            if [[ $poolCount -gt 1 ]] ; then
                status=0
                for (( i=0; i<$poolCount; i++ )) ; do
                    ls /dev/mapper/${LUKS_POOL_NAME}-$i || status=1
                done
            else
                ls /dev/mapper/$LUKS_POOL_NAME
                status=$?
            fi

        else
            ls -l $POOL_DEVICE
            status=$?
        fi
        [[ $status -ne 0 ]] && sys::MsgPause "OpenPool failed"

    done

    # Import zfs
    if str::InList ZFS $STORAGE_OPTIONS ; then

        status=1
        while [[ $status -ne 0 ]] ; do
            ZFS_POOL_NAME=$(
                ui::Required ui::PickList "ZFS pool name" \
                    $(
                        zpool list -H -o name | awk '{print $1, "IMPORTED", "off"}'
                        zpool import | awk '$1=="pool:"{p=$2}$1=="state:"{print p" "$2" off"}'
                    )
            )

            SyncInternals

            zpool list $ZFS_POOL_NAME && break

            ImportZfsPool && status=0

            # BUG: $POOL_TOPOLOGY not set if ZFS
            # TODO POOL_TOPOLOGY=$( detect from imported pool ??? )

        done

        # BUG ?
        # zfs set mountpoint=legacy "$ZFS_POOL_NAME/$ZFS_DATA_DSET"

    fi

}



########
# FUNC #  MENU::MAIN
########



MenuConfig ()
{
    INSTALLER_MENU=1

    MenuVersion
    MenuStorage
    MenuDistro
    MenuReview # TODO loop

    if [[ "$( type -t MenuAdditional 2>/dev/null )" == "function" ]] ; then
        MenuAdditional
        # TODO loop Review
    fi

    INSTALL_MODE=MenuInstall # TODO allow MenuExtend ?

    sys::GetVarsDefinitions $CORE_PREF \
        >./${HOST_HOSTNAME}_$(date +%Y%m%d%H%M%S).$PRODUCT_NAME.conf
}


MenuInstall ()
{
    INSTALL_MODE=MenuInstall

    MenuConfig

    Deploy
}


MenuExtend ()
{
    # TODO ONLY if ZFS && BS !!!

    INSTALLER_MENU=1
    INSTALL_MODE=MenuExtend

    MenuOpen

    status=1
    while [[ $status -ne 0 ]] ; do
        ZFS_ROOT_DSET=$( ui::Required ui::AskSanitized "[NEW] ZFS root dataset, relative to $ZFS_POOL_NAME/" "root/new" '/' )
        if zfs::IsDataset $ZFS_POOL_NAME/$ZFS_ROOT_DSET ; then
            ui::Say "ZFS dataset $ZFS_POOL_NAME/$ZFS_ROOT_DSET already exists"
        else
            status=0
        fi
    done


    ZFS_DATA_DSET=$(
        ui::PickList "[OPTIONAL] Existing ZFS data dataset" \
            ""       "NONE"       off \
            $(  zfs list -H -r -o name,used,mountpoint $ZFS_POOL_NAME \
              | grep -Ev "^$ZFS_POOL_NAME(\s|$BOOTCLONE_GRUB|$BOOTCLONE_ROOT)"  \
              | awk '$3!="legacy"{print substr($1,index($1,"/")+1), $2, "off"}'
            )
        )


    MenuVersion
    MenuHardware
    MenuDistro

    if [[ "$( type -t MenuAdditional 2>/dev/null )" == "function" ]] ; then
        MenuAdditional
    fi

    MenuReview

    sys::GetVarsDefinitions $CORE_PREF \
        >./${HOST_HOSTNAME}_$(date +%Y%m%d%H%M%S).$PRODUCT_NAME.conf

    # TODO confirmation !!! but not Accept()

    Deploy
}


MenuRepair ()
{
    INSTALLER_MENU=1

    MenuOpen

    # Mount
    status=1
    while [[ $status -ne 0 ]] ; do

        if str::InList ZFS $STORAGE_OPTIONS ; then

            # TODO Pick from list: $( zfs list ...
            ZFS_ROOT_DSET=$( ui::Required ui::AskSanitized "ZFS root dataset, relative to $ZFS_POOL_NAME/" "$ZFS_ROOT_DSET" '/' )
            SyncInternals

            MountZfsRoot

            # TODO check
            status=0
        else
            # Mount ext
            mkdir -p $TARGET

            mount -t $BOOT_FS $POOL_DEVICE $TARGET

            status=$?

        fi
        [[ $status -ne 0 ]] && sys::MsgPause "mount failed"

    done

    MountChroot

    # Fix udev links
        [[ -x "/$TARGET/usr/local/sbin/gnowledge" ]] \
    && chroot  $TARGET /usr/local/sbin/gnowledge Internal ConfigureUdev --temp

    sys::Msg "RECOVERY SHELL: all devices will be closed once this shell exit with 0"

    # Shell
    local ret=1
    while [[ $ret -ne 0 ]] ; do
        chroot $TARGET
        ret=$?
    done

    CloseAll

}
