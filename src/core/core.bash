########
# FUNC #  UI::BUNDLE
########


# Meta () { : ; }
Meta () # [--KEY VALUE] ...
{
       [[ $(($#%2)) -eq 0 ]] \
    || sys::Die "Invalid Meta args count ($#): $@"
}

GetFuncMetaByKey () # $1:FUNC $2:KEY
{
    CheckFuncMeta () # $1:FUNC
    {
        # Check function's first instruction is Meta
          declare -f $1 \
        | head -3 \
        | tail -1 \
        | grep -E '^ *Meta ' &>/dev/null
    }

    CheckFuncMeta $1 || return 1

    ( # DEV: Subshell

        set +x
        Meta () # DEV Overriden to output --$metaKey values
        {
               [[ $(($#%2)) -eq 0 ]] \
            || sys::Die "Invalid $FUNCNAME() call in $metaFunc(): even args count ($#), args:\n$@"

            local state=k # key, value (not matching), matched (value)
            for i in "$@" ; do
                case $state in
                k)  state=v
                    [[ "$i" == "--$metaKey" ]] && state=m ;;
                m)  state=k
                    echo "$i" ;;
                v)  state=k
                esac
            done

            exit # DEV: Exit subshell
        }

        # Run func with 'meta*' env
        metaFunc="$1" metaKey="$2" $1
    )
}




########
# FUNC #  CMD::STORAGE::UEFI
########



OpenUefi ()
{
    local cnt=$( str::GetWordCount $BOOT_PARTITION )

    # mdraid
    if [[ $cnt -gt 1 ]] && [[ ! -b $BOOT_MD ]]  ; then
        apt::AddPackages mdadm
        service mdadm stop
        mdadm --assemble --verbose --no-degraded --homehost=$HOST_HOSTNAME --name=uefi $UEFI_MD $UEFI_PARTITION
        sys::Chk
        mdadm --detail $UEFI_MD # DEBUG
    fi
}

FormatUefi ()
{
    [[ -z "$UEFI_PARTITION" ]] && return

    local cnt=$( str::GetWordCount $UEFI_PARTITION )

    # mdraid
    if [[ $cnt -gt 1 ]] ; then
        apt::AddPackages mdadm
        service mdadm stop
        mdadm --verbose \
            --create --run \
            --level=mirror --raid-devices=$cnt \
            --homehost=$HOST_HOSTNAME --name=uefi \
            $UEFI_MD $UEFI_PARTITION
        sys::Chk
        mdadm --detail $UEFI_MD # DEBUG
    fi

    if str::InList APPLE $STORAGE_OPTIONS ; then
        add-apt-repository universe
        sys::Chk
        apt::Update
        apt::AddPackages hfsprogs
    fi

    umount -f $UEFI_DEVICE

    local efi_type=$( fs::GetPartitionType $UEFI_DEVICE )

    if str::InList APPLE $STORAGE_OPTIONS \
    && [[ "$efi_type" != "AF00" ]] \
    && [[ "$efi_type" != "EF00" ]] ; then

        # NEW APPLE EFI 1.5
        sgdisk -t $( fs::GetPartitionNumber $UEFI_DEVICE ):af00 \
            $( fs::GetDeviceDisk $UEFI_DEVICE )
        mkfs.hfsplus $UEFI_DEVICE -v efi
        sys::Chk

    elif str::InList APPLE $STORAGE_OPTIONS && [[ "$efi_type" == "AF00" ]] ; then

        local fstype=$( fs::GetPartitionFormat $UEFI_DEVICE )
        [[ "$fstype" == "hfsplus" ]] && return

        # FORMAT APPLE EFI 1.5
        mkfs.hfsplus $UEFI_DEVICE -v efi
        sys::Chk

    else
        sgdisk -t $( fs::GetPartitionNumber $UEFI_DEVICE ):ef00 \
            $( fs::GetDeviceDisk $UEFI_DEVICE )

        local fstype=$( fs::GetPartitionFormat $UEFI_DEVICE )
        [[ "$fstype" == "vfat" ]] && return

        mkfs.vfat -F32 $UEFI_DEVICE
        sys::Chk
        dosfslabel $UEFI_DEVICE UEFI
        sys::Chk
    fi
}



########
# FUNC #  CMD::STORAGE::BOOT
########



FormatBoot ()
{
    [[ -z "$BOOT_PARTITION" ]] && return

    local cnt=$( str::GetWordCount $BOOT_PARTITION )

    # mdraid
    if [[ $cnt -gt 1 ]] ; then
        apt::AddPackages mdadm
        service mdadm stop
        mdadm --verbose \
            --create --run \
            --level=mirror --raid-devices=$cnt \
            --homehost=$HOST_HOSTNAME --name=boot \
            $BOOT_MD $BOOT_PARTITION
        sys::Chk
        mdadm --detail $BOOT_MD # DEBUG
    fi


    if str::InList CRYPTO_BOOT $STORAGE_OPTIONS ; then

        # rand
        str::InList RANDOM $STORAGE_OPTIONS && fs::RandomizeDevices $BOOT_PARTITION

        # luks
        local device=$BOOT_PARTITION
        [[ $cnt -gt 1 ]] && device=$BOOT_MD
          tr -d '\n' <<<"$LUKS_PASSWORD" \
        | cryptsetup -v luksFormat $device $LUKS_FORMAT_OPTS
        sys::Chk
          tr -d '\n' <<<"$LUKS_PASSWORD" \
        | cryptsetup -v luksOpen $device $LUKS_BOOT_NAME
        sys::Chk
    fi

    mkfs.$BOOT_FS $BOOT_DEVICE
    sys::Chk

    tune2fs -L boot $BOOT_DEVICE
    sys::Chk

    # bootclone-ext
    if [[ "$BOOTCLONE_TYPE" == "ext" ]] ; then

        local tempdir=$( mktemp -d )
        local bootcloneName=$( str::SanitizeString "${ZFS_ROOT_DSET##*/}" )

        mount $BOOT_DEVICE $tempdir
        sys::Chk

        mkdir -p \
            $tempdir/grub \
            $tempdir$BOOTCLONE_BOOT/$bootcloneName/grub

        umount $tempdir
        sys::Chk

        rm -rf $tempdir

    fi
}


OpenBoot ()
{
    local cnt=$( str::GetWordCount $BOOT_PARTITION )

    # mdraid
    if [[ $cnt -gt 1 ]] && [[ ! -b $BOOT_MD ]]  ; then
        apt::AddPackages mdadm
        service mdadm stop
        mdadm --assemble --verbose --no-degraded --homehost=$HOST_HOSTNAME --name=boot $BOOT_MD $BOOT_PARTITION
        sys::Chk
        mdadm --detail $BOOT_MD # DEBUG
    fi

    # luks
    local device=$BOOT_PARTITION
    [[ $cnt -gt 1 ]] && device=$BOOT_MD
    if str::InList CRYPTO_BOOT $STORAGE_OPTIONS ; then
        [[ -b "/dev/mapper/$LUKS_BOOT_NAME" ]] && return
          tr -d '\n' <<<"$LUKS_PASSWORD" \
        | cryptsetup -v luksOpen $device $LUKS_BOOT_NAME
        sys::Chk
    fi
}


CloseBoot ()
{
    # luks
    if [[ -b "/dev/mapper/$LUKS_BOOT_NAME" ]] ; then
        cryptsetup -v luksClose $LUKS_BOOT_NAME
        sys::Chk
    fi

    # mdraid
    [[ -b $BOOT_MD ]] && mdadm --stop $BOOT_MD
}



########
# FUNC #  CMD::STORAGE::POOL
########



FormatPool ()
{
    local cnt=$( str::GetWordCount $POOL_PARTITION )


    if   str::InList ZFS         $STORAGE_OPTIONS \
      && str::InList CRYPTO_ROOT $STORAGE_OPTIONS
    then

           str::InList RANDOM $STORAGE_OPTIONS \
        && fs::RandomizeDevices $POOL_PARTITION

        local suffix idx=0
        for partition in $POOL_PARTITION ; do
            [[ $cnt -gt 1 ]] && suffix="-$idx"
            ((idx++))
              tr -d '\n' <<<"$LUKS_PASSWORD" \
            | cryptsetup -v luksFormat $partition $LUKS_FORMAT_OPTS
            sys::Chk
              tr -d '\n' <<<"$LUKS_PASSWORD" \
            | cryptsetup -v luksOpen $partition $LUKS_POOL_NAME$suffix
            sys::Chk
        done

        # ONE_PROMPT: Derive pool devices from 1st (-0)
        if str::InList PLAIN_BOOT $STORAGE_OPTIONS && [[ $cnt -gt 7 ]] ; then

            local tempkey=$( mktemp )
            /lib/cryptsetup/scripts/decrypt_derived $LUKS_POOL_NAME-0 >$tempkey

            for partition in $POOL_PARTITION ; do
                [[ $idx -eq 0 ]] && continue
                  tr -d '\n' <<<"$LUKS_PASSWORD" \
                | cryptsetup luksAddKey $partition $tempkey --key-slot 7
                sys::Chk
            done

            rm $tempkey

        # FAULT TOLERANT ONE_PROMPT: Derive pool devices from each other
        elif str::InList PLAIN_BOOT $STORAGE_OPTIONS && [[ $cnt -gt 1 ]] ; then

            local slot tempkey=$( mktemp )

            for partitionDst in $POOL_PARTITION ; do

                slot=7
                idx=0
                for partitionSrc in $POOL_PARTITION ; do

                    [[ $slot -eq 0 ]] && { sys::Msg "PLAIN_BOOT: pool cannot derive from more that 7 crypto pool devices" ; break ; }

                    [[ "$partitionDst" == "$partitionSrc" ]] && { ((idx++)) ; continue ; }

                    /lib/cryptsetup/scripts/decrypt_derived $LUKS_POOL_NAME-$idx >$tempkey

                      tr -d '\n' <<<"$LUKS_PASSWORD" \
                    | cryptsetup luksAddKey $partitionDst $tempkey --key-slot $slot
                    sys::Chk

                    ((slot--))
                    ((idx++))

                done

            done

            rm $tempkey
        fi


    elif ! str::InList ZFS $STORAGE_OPTIONS ; then

        local device

        if [[ $cnt -gt 1 ]] ; then
            apt::AddPackages mdadm
            service mdadm stop
            mdadm --verbose \
                --create --run \
                --level=$( GetMdTopologyLevel $POOL_TOPOLOGY ) --raid-devices=$cnt \
                --homehost=$HOST_HOSTNAME --name=pool \
                $POOL_MD $POOL_PARTITION
            sys::Chk
            mdadm --detail $POOL_MD # DEBUG
            device=$POOL_MD
        else
            device=$POOL_PARTITION
        fi

        if str::InList CRYPTO_ROOT $STORAGE_OPTIONS ; then

            str::InList RANDOM $STORAGE_OPTIONS && fs::RandomizeDevices $device

              tr -d '\n' <<<"$LUKS_PASSWORD" \
            | cryptsetup -v luksFormat $device $LUKS_FORMAT_OPTS
            sys::Chk
              tr -d '\n' <<<"$LUKS_PASSWORD" \
            | cryptsetup -v luksOpen $device $LUKS_POOL_NAME
            sys::Chk

        fi
    fi

    # zfs
    if str::InList ZFS $STORAGE_OPTIONS ; then

        CreateZfsPool
        CreateZfsRoot
        CreateZfsData
        ExportZfsPool
        WipefsZfsPool
        ImportZfsPool
        MountZfsRoot

    # ext mkfs
    else
        if [[ "$BOOT_FS" =~ ^ext ]] ; then
            mkfs.$BOOT_FS -F $POOL_DEVICE
            sys::Chk
            tune2fs -L root $POOL_DEVICE
            sys::Chk
        else
            mkfs.$BOOT_FS $POOL_DEVICE
            sys::Chk
        fi

        mkdir -p $TARGET
        mount -t $BOOT_FS $POOL_DEVICE $TARGET
        sys::Chk
    fi
}


OpenPool ()
{
    local cnt=$( str::GetWordCount $POOL_PARTITION )

    # mdraid
    if ! str::InList ZFS $STORAGE_OPTIONS \
    && [[ $cnt -gt 1 ]] \
    && [[ ! -b $POOL_MD ]]  ; then
        apt::AddPackages mdadm
        service mdadm stop
        mdadm --verbose \
            --assemble --no-degraded \
            --homehost=$HOST_HOSTNAME --name=boot \
            $POOL_MD $POOL_PARTITION
        sys::Chk
        mdadm --detail $POOL_MD # DEBUG
    fi

    # luks
    local suffix idx=0
    if str::InList CRYPTO_ROOT $STORAGE_OPTIONS ; then
        for partition in $POOL_PARTITION ; do
            [[ $cnt -gt 1 ]] && suffix="-$idx"
            ((idx++))
            [[ -b "/dev/mapper/$LUKS_POOL_NAME$suffix" ]] && continue
              tr -d '\n' <<<"$LUKS_PASSWORD" \
            | cryptsetup -v luksOpen $partition $LUKS_POOL_NAME$suffix
            sys::Chk
        done
    fi

}


ClosePool ()
{

    which zpool &>/dev/null && zpool status $ZFS_POOL_NAME && ExportZfsPool

    # luks
    local suffix idx=0 cnt=$( str::GetWordCount $POOL_PARTITION )
    for partition in $POOL_PARTITION ; do
        [[ $cnt -gt 1 ]] && suffix="-$idx"
        [[ -b "/dev/mapper/$LUKS_POOL_NAME$suffix" ]] || continue
        ((idx++))
        cryptsetup -v luksClose $LUKS_POOL_NAME$suffix
        sys::Chk
    done

    # mdraid
    [[ -b $POOL_MD ]] && mdadm --stop $POOL_MD
}



########
# FUNC #  CMD::STORAGE::SWAP
########



FormatSwap ()
{
    [[ -z "$SWAP_PARTITION" ]] && return

    local cnt=$( str::GetWordCount $SWAP_PARTITION )

    # mdraid
    if [[ $cnt -gt 1 ]] ; then
        apt::AddPackages mdadm
        service mdadm stop
        mdadm --verbose \
            --create --run \
            --level=mirror --raid-devices=$cnt \
            --homehost=$HOST_HOSTNAME --name=swap \
            $SWAP_MD $SWAP_PARTITION
        sys::Chk
        mdadm --detail $SWAP_MD # DEBUG
    fi

    # luks
    if str::InList CRYPTO_ROOT $STORAGE_OPTIONS ; then

        local swapDevice
        [[ $cnt -gt 1 ]] && swapDevice=$SWAP_MD || swapDevice=$SWAP_PARTITION

        str::InList RANDOM $STORAGE_OPTIONS && fs::RandomizeDevices $swapDevice

        local tempkey=$( mktemp )
        dd 'if=/dev/urandom' of=$tempkey bs=1 count=512


        if str::InList CRYPTO_BOOT $STORAGE_OPTIONS ; then

            # No derivation, password used temporary, removed later

              tr -d '\n' <<<"$LUKS_PASSWORD" \
            | cryptsetup -v luksFormat $swapDevice $LUKS_FORMAT_OPTS
            sys::Chk
              tr -d '\n' <<<"$LUKS_PASSWORD" \
            | cryptsetup -v luksOpen $swapDevice $LUKS_SWAP_NAME
            sys::Chk

        else

            # Pool key derivation

            cryptsetup -q -v luksFormat $swapDevice $LUKS_FORMAT_OPTS --key-file $tempkey
            sys::Chk

            cryptsetup luksOpen $swapDevice $LUKS_SWAP_NAME --key-file $tempkey
            sys::Chk

            # luksAddKey
            if str::InList ZFS $STORAGE_OPTIONS ; then

                local suffix idx=0 slot=7
                for partition in $POOL_PARTITION ; do

                    [[ $slot -eq 0 ]] && { sys::Msg "ZFS CRYPTO_ROOT: swap cannot derive from more that 7 crypto pool devices" ; break ; }

                    [[ $( str::GetWordCount $POOL_PARTITION ) -gt 1 ]] && suffix="-$idx"
                    ((idx++))

                      /lib/cryptsetup/scripts/decrypt_derived $LUKS_POOL_NAME$suffix \
                    | cryptsetup luksAddKey $swapDevice - --key-slot $slot --key-file $tempkey
                    sys::Chk

                    ((slot--))
                done

            else
                  /lib/cryptsetup/scripts/decrypt_derived $LUKS_POOL_NAME \
                | cryptsetup luksAddKey $swapDevice - --key-slot 7 --key-file $tempkey
                sys::Chk
            fi

            cryptsetup luksRemoveKey $swapDevice --key-slot 0 --key-file $tempkey
            sys::Chk

            rm -f $tempkey

        fi

    fi

    # mkfs
    mkswap -f $SWAP_DEVICE
    sys::Chk
}


OpenSwap ()
{
    local cnt=$( str::GetWordCount $SWAP_PARTITION )

    if [[ $cnt -gt 1 ]] && [[ ! -b $SWAP_MD ]] ; then
        apt::AddPackages mdadm
        service mdadm stop
        mdadm --verbose \
            --assemble --no-degraded \
            --homehost=$HOST_HOSTNAME --name=swap \
            $SWAP_MD $SWAP_PARTITION
        sys::Chk
        mdadm --detail $SWAP_MD # DEBUG
    fi


    # luks useless as we won't use swap during install
    local device=$SWAP_PARTITION
    [[ $cnt -gt 1 ]] && device=$SWAP_MD
    if str::InList CRYPTO_ROOT $STORAGE_OPTIONS ; then
        [[ -b "/dev/mapper/$LUKS_SWAP_NAME" ]] && return

        # TODO HERE detect if SWAP is derived OR not before opening:
        # echo -n "$LUKS_PASSWORD" | cryptsetup -v luksOpen $device $LUKS_SWAP_NAME
        # sys::Chk

    fi

}


CloseSwap ()
{
    # luks
    if [[ -b "/dev/mapper/$LUKS_SWAP_NAME" ]] ; then
        cryptsetup -v luksClose $LUKS_SWAP_NAME
        sys::Chk
    fi

    # mdraid
    [[ -b $SWAP_MD ]] && mdadm --stop $SWAP_MD
}



########
# FUNC #  CMD::ZFS
########




ReplaceDeviceById () # $*:POOL_TOPOLOGY
{
    local sentence

    for word in $* ; do

        if [[ "$word" =~ ^/dev/ ]] ; then

            local id=$( fs::GetDeviceId $word )

               [[ -b "$id" ]] \
            && sentence="$sentence $( basename "$id" )" \
            || sentence="$sentence $word" # DEV: failed ID resolution => keep original

        else
            sentence="$sentence $word"
        fi

    done

    echo $sentence
}


ReplaceDeviceByLuksName () # $*:POOL_TOPOLOGY
{

    local suffix
    local ret=$*
    local cnt=$( str::GetWordCount $POOL_PARTITION )

    for partition in $POOL_PARTITION ; do

        [[ $cnt -gt 1 ]] && suffix="-"$( str::GetWordIndex $partition $POOL_PARTITION )

        regex="s#^(.*\\s)?$partition(\\s.*)?\$#\\1/dev/mapper/$LUKS_POOL_NAME$suffix\2#"

        ret=$( sed -E $regex <<<$ret )

    done

    echo $ret
}

CreateZfsPool ()
{
    zfs::Install

    # Check ZfsPool exists
    zfs::IsDataset $ZFS_POOL_NAME && return

    local poolTopology=$POOL_TOPOLOGY

    if str::InList CRYPTO_ROOT $STORAGE_OPTIONS ; then
        poolTopology=$( ReplaceDeviceByLuksName $POOL_TOPOLOGY )
    else
        poolTopology=$( ReplaceDeviceById $POOL_TOPOLOGY )
    fi

    zpool create -f \
        $ZFS_POOL_OPTS -m none  \
        $ZFS_POOL_NAME $poolTopology
    sys::Chk
        # OLD $ZFS_POOL_OPTS $preventHoleBirth -m none  \

}


ImportZfsPool ()
{
    zfs::Install

    # Check ZfsPool exists
    zfs::IsDataset $ZFS_POOL_NAME && return

    zpool import # DEBUG

    # DOC: zpool import
    # -N            Import the pool without mounting any file systems.
    # -c cachefile  Reads configuration from the given cachefile that was created with the "cachefile" pool property.
    # -f            Forces import, even if the pool appears to be potentially active.
    # -R root       Sets the "cachefile" property to "none" and the "altroot" property to "root".

    zpool import -f -N $ZFS_POOL_NAME
    sys::Chk && return 0

    return 1
}


MountZfsRoot ()
{
    zfs list # DEBUG

    mkdir -p $TARGET

    zfs set mountpoint=legacy $ZFS_POOL_NAME/$ZFS_ROOT_DSET
    sys::Chk

    mount -t zfs $ZFS_POOL_NAME/$ZFS_ROOT_DSET $TARGET
    sys::Chk

    zfs list # DEBUG

    mkdir -p \
        $TARGET/home      \
        $TARGET/var/cache \
        $TARGET/var/log   \
        $TARGET/var/spool \
        $TARGET/var/tmp

    mount -t zfs $ZFS_POOL_NAME/$ZFS_ROOT_DSET/home      $TARGET/home      ; sys::Chk
    mount -t zfs $ZFS_POOL_NAME/$ZFS_ROOT_DSET/var/cache $TARGET/var/cache ; sys::Chk
    mount -t zfs $ZFS_POOL_NAME/$ZFS_ROOT_DSET/var/log   $TARGET/var/log   ; sys::Chk
    mount -t zfs $ZFS_POOL_NAME/$ZFS_ROOT_DSET/var/spool $TARGET/var/spool ; sys::Chk
    mount -t zfs $ZFS_POOL_NAME/$ZFS_ROOT_DSET/var/tmp   $TARGET/var/tmp   ; sys::Chk

    chmod 1700    $TARGET/var/tmp
    chown :syslog $TARGET/var/log

    if [[ -n "$ZFS_DATA_DSET" ]] ; then
        local data=$TARGET/$( basename $ZFS_DATA_DSET )
        mkdir -p $data
        zfs set mountpoint=legacy $ZFS_POOL_NAME/$ZFS_DATA_DSET
        sys::Chk
        mount -t zfs \
            $ZFS_POOL_NAME/$ZFS_DATA_DSET \
            $data
        sys::Chk
        chown 1000:1000 $data
        mkdir -p $data/$USER_USERNAME
        if [[ "$INSTALL_MODE" == "MenuExtend" ]] ; then
            zfs set mountpoint=legacy "$ZFS_POOL_NAME/$ZFS_DATA_DSET/$USER_USERNAME"
        fi
        mount -t zfs \
            $ZFS_POOL_NAME/$ZFS_DATA_DSET/$USER_USERNAME \
            $data/$USER_USERNAME
        sys::Chk

        chown 1000:1000 $data/$USER_USERNAME
    fi

    zfs get mounted # DEBUG
}


WipefsZfsPool ()
{
    for dev in $POOL_PARTITION ; do
        if fs::isDeviceType partition $dev &>/dev/null ; then
            wipefs --all --force --types zfs_member $( fs::GetDeviceDisk $dev )
            sys::Chk
        fi
    done
}


ExportZfsPool ()
{
    # Check ZfsPool not exists
    zfs::IsDataset $ZFS_POOL_NAME || return

    zpool export -f $ZFS_POOL_NAME
    sys::Chk

    zpool list # DEBUG
}


CreateZfsRoot ()
{
    zfs::CreateDataset $ZFS_POOL_NAME/$ZFS_ROOT_DSET -o mountpoint=legacy

    # DOC https://github.com/zfsonlinux/zfs/wiki/Ubuntu-16.10-Root-on-ZFS#step-3-system-installation

    # user datasets
    zfs::CreateDataset $ZFS_POOL_NAME/$ZFS_ROOT_DSET/home       -o setuid=off
    zfs::CreateDataset $ZFS_POOL_NAME/$ZFS_ROOT_DSET/var        -o canmount=off -o setuid=off -o exec=off
    zfs::CreateDataset $ZFS_POOL_NAME/$ZFS_ROOT_DSET/var/cache  -o com.sun:auto-snapshot=false
    zfs::CreateDataset $ZFS_POOL_NAME/$ZFS_ROOT_DSET/var/log    -o acltype=posixacl # https://askubuntu.com/a/970887
    zfs::CreateDataset $ZFS_POOL_NAME/$ZFS_ROOT_DSET/var/spool
    zfs::CreateDataset $ZFS_POOL_NAME/$ZFS_ROOT_DSET/var/tmp    -o com.sun:auto-snapshot=false -o exec=on

    # bootclone
    if str::InList BOOTCLONE $STORAGE_OPTIONS \
    && [[ "$INSTALL_MODE" == "MenuInstall" ]] ; then

        zfs::CreateDataset $ZFS_POOL_NAME$BOOTCLONE_ROOT -o mountpoint=legacy

          [[ "$BOOTCLONE_TYPE" == "zfs" ]] \
        && zfs::CreateDataset $ZFS_POOL_NAME$BOOTCLONE_GRUB -o mountpoint=legacy

    fi

    zfs list # DEBUG
}


CreateZfsData ()
{
    [[ -n "$ZFS_DATA_DSET" ]] || return # DEV OPTIONAL

    if [[ "$INSTALL_MODE" == "MenuInstall" ]] ; then
        zfs::CreateDataset $ZFS_POOL_NAME/$ZFS_DATA_DSET -o mountpoint=legacy
        zfs::CreateDataset $ZFS_POOL_NAME/$ZFS_DATA_DSET/$USER_USERNAME
    fi
}



########
# FUNC #  CMD::UBUNTU
########



Installer ()
{
    # Sync time
    apt::AddPackages ntpdate
       ntpdate -uv $NTP_SERVERS \
    || ntpdate -uv $NTP_SERVERS # DEV can fail: no server suitable for synchronization found
    sys::Chk


    # FIX Virtualbox RTC causing fsck after reboot: init > mountall > fsck > "future last-mount-time"
    hwclock -w
    sys::Chk
    hwclock --show  # DEBUG


    ## Debootstrap
    add-apt-repository universe
    apt-get update
    apt::AddPackages debootstrap
    mkdir -p $TARGET
    local additionalDebootstrap="patch,bsdmainutils,curl,wget,unzip,software-properties-common,busybox-static,cryptsetup,lshw"
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        additionalDebootstrap="$additionalDebootstrap,apt-transport-https"
    else
        additionalDebootstrap="$additionalDebootstrap,dirmngr,gpg-agent"
    fi
    debootstrap                                 \
        --include=$additionalDebootstrap        \
        $UBUNTU_RELEASE                         \
        $TARGET
    sys::Chk

    ## apt sources
    apt::GenerateSources $TARGET $UBUNTU_RELEASE
        # "https://mirrors.edge.kernel.org/ubuntu/"
        # "mirror://mirrors.ubuntu.com/mirrors.txt"
        # "http://archive.ubuntu.com/ubuntu/"
    apt::Update

    ## fstab
    GenerateFstab >$TARGET/etc/fstab
    cat $TARGET/etc/fstab # DEBUG


    ## bootclone mountpoint
       str::InList BOOTCLONE $STORAGE_OPTIONS \
    && sys::Mkdir $TARGET$BOOTCLONE_MNTP 0:0 750

    # mount all
    MountChroot


    ## Generate decryption key, add to devices & stuff into initrd
    if  [[ "$INSTALL_MODE" == "MenuInstall" ]]          \
    &&  {      str::InList CRYPTO_BOOT $STORAGE_OPTIONS \
        ||  {  str::InList CRYPTO_ROOT $STORAGE_OPTIONS \
            && [[ -z "$BOOT_PARTITION" ]]
            }
        }
    then

        # Generate key
        mkdir -p $( dirname $TARGET$LUKS_KEY )
        dd 'if=/dev/urandom' of=$TARGET$LUKS_KEY bs=1 count=512

        # DEV /boot will hold luks key at $LUKS_KEY, ALSO in *initrd*
        chmod 0700 $TARGET/boot
        chmod 0400 $TARGET$LUKS_KEY $( dirname $TARGET$LUKS_KEY )
        chattr +i  $TARGET$LUKS_KEY $( dirname $TARGET$LUKS_KEY )

        # Add key to boot array
        if [[ -n "$BOOT_PARTITION" ]] ; then

            local bootDevice=$BOOT_PARTITION
            [[ $( str::GetWordCount $BOOT_PARTITION ) -gt 1 ]] && bootDevice=$BOOT_MD

              tr -d '\n' <<<"$LUKS_PASSWORD" \
            | cryptsetup luksAddKey $bootDevice --key-slot 7 $TARGET$LUKS_KEY

            sys::Chk
        fi

        # Add key to swap array
        if [[ -n "$SWAP_PARTITION" ]] && str::InList CRYPTO_BOOT $STORAGE_OPTIONS  ; then

            local swapDevice=$SWAP_PARTITION
            [[ $( str::GetWordCount $SWAP_PARTITION ) -gt 1 ]]  && swapDevice=$SWAP_MD

              tr -d '\n' <<<"$LUKS_PASSWORD" \
            | cryptsetup luksAddKey $swapDevice --key-slot 7 $TARGET$LUKS_KEY
            sys::Chk

              tr -d '\n' <<<"$LUKS_PASSWORD" \
            | cryptsetup luksRemoveKey $swapDevice --key-slot 0
            sys::Chk
        fi

        # Add key to pool partitions
        if str::InList ZFS $STORAGE_OPTIONS ; then
            for poolPartition in $POOL_PARTITION ; do
                  tr -d '\n' <<<"$LUKS_PASSWORD" \
                | cryptsetup luksAddKey $poolPartition --key-slot 7 $TARGET$LUKS_KEY
                sys::Chk
            done
        else
            local poolDevice=$POOL_PARTITION
            [[ $( str::GetWordCount $POOL_PARTITION ) -gt 1 ]] && poolDevice=$POOL_MD

              tr -d '\n' <<<"$LUKS_PASSWORD" \
            | cryptsetup luksAddKey $poolDevice --key-slot 7 $TARGET$LUKS_KEY
            sys::Chk
        fi

    fi


    ## bootclone install
    str::InList BOOTCLONE $STORAGE_OPTIONS && InstallBootclone


    ## Run ChrootedInstaller

    export HOME=/home/$USER_USERNAME

    local scriptClone=/usr/local/sbin/gnowledge
    cp $(readlink -f $0) $TARGET$scriptClone
    sys::GetVarsDefinitions $CORE_PREF >$TARGET/etc/$PRODUCT_NAME.conf
    chmod 744 $TARGET$scriptClone

    # pivot logs
    sys::UnLogOutput
    local logOutputFileChrooted="$TARGET/root/$( basename "$logOutputFile" )"
    mv $logOutputFile $logOutputFileChrooted
    logOutputFile=$logOutputFileChrooted
    unset logOutputFileChrooted

    logOutputFile=${logOutputFile##$TARGET} \
        chroot $TARGET \
            /bin/bash $scriptClone --config /etc/$PRODUCT_NAME.conf \
                Internal ChrootedInstaller
            # /bin/bash $scriptClone --config /etc/$PRODUCT_NAME.conf \
    sys::LogOutput


    # WORKAROUND: NO PASSWORDS in ChrootedInstaller
    chroot $TARGET chpasswd <<<"$USER_USERNAME:$USER_PASSWORD"
    # chpasswd --root $TARGET <<<"$USER_USERNAME:$USER_PASSWORD"
    sys::Chk


    ## bootclone
    if str::InList BOOTCLONE $STORAGE_OPTIONS ; then

        if [[ "$INSTALL_MODE" == "MenuInstall" ]] ; then

            sys::Copy $TARGET/boot/grub/$KEYBOARD_LAYOUT.gkb $TARGET$BOOTCLONE_MNTP/grub/
        fi

    fi


    # ZFS snapshot: factory-core
    if str::InList ZFS $STORAGE_OPTIONS ; then

        zfs::CreateSnapshot $ZFS_POOL_NAME/$ZFS_ROOT_DSET factory-core

        # ZFS bootclone
        if str::InList BOOTCLONE $STORAGE_OPTIONS \
        && [[ "$INSTALL_MODE" == "MenuInstall" ]] ; then

            chroot $TARGET bootclone create $( basename $ZFS_ROOT_DSET )-factory-core \
                $ZFS_POOL_NAME/$ZFS_ROOT_DSET@factory-core
            sys::Chk
        fi
    fi

    ## Chroot InstallAdditional
    if   [[ "$( type -t InstallAdditional 2>/dev/null )" == "function" ]] ; then

        sys::UnLogOutput

        # OLD logOutputFile=$logOutputFile chroot $TARGET \
        logOutputFile=${logOutputFile##$TARGET} chroot $TARGET \
            /bin/bash $scriptClone \
                --config /etc/$PRODUCT_NAME.conf \
                Internal InstallAdditional

        sys::LogOutput # ?????

    fi

}


Clean ()
{
    apt::Upgrade
    apt::AutoRemovePackages
    apt-get clean
    sys::Chk

    find /var/log -type f -delete

    rm -rf \
        /var/cache/apt/archives/* \
        /var/cache/apt/*.bin \
        /var/lib/apt/lists/* \
        /var/tmp/* \
        /tmp/* \
        $HOME/.cache/* \
        $HOME/.bash_history \
        $HOME/.lesshst \
        $HOME/.viminfo \
        $HOME/.gnupg

    sys::Touch $HOME/.bash_history
}


MountChroot ()
{

    mount --bind    /dev    $TARGET/dev     ; sys::Chk
    mount -t devpts devpts  $TARGET/dev/pts ; sys::Chk
    mount -t proc   proc    $TARGET/proc    ; sys::Chk
    mount -t sysfs  sys     $TARGET/sys     ; sys::Chk

    local bootCount=$( str::GetWordCount $BOOT_PARTITION )


    # no bootclone
    if [[ -n "$BOOT_PARTITION" ]] && ! str::InList BOOTCLONE $STORAGE_OPTIONS ; then

        mount $BOOT_DEVICE $TARGET/boot

    # bootclone-ext
    elif str::InList BOOTCLONE $STORAGE_OPTIONS \
      && [[ "$BOOTCLONE_TYPE" == "ext" ]]
    then

        if [[ -n "$BOOT_PARTITION" ]] ; then
            mount $BOOT_DEVICE $TARGET$BOOTCLONE_MNTP
            sys::Chk
        fi

        local bootcloneName=$( str::SanitizeString "${ZFS_ROOT_DSET##*/}" )
        mount --bind $TARGET$BOOTCLONE_MNTP$BOOTCLONE_BOOT/$bootcloneName $TARGET/boot

    # bootclone-zfs
    elif str::InList BOOTCLONE $STORAGE_OPTIONS ; then
        mount -t zfs $ZFS_POOL_NAME$BOOTCLONE_GRUB $TARGET$BOOTCLONE_MNTP

    fi
    sys::Chk

    # UEFI
    if str::InList UEFI $STORAGE_OPTIONS ; then
        mkdir -p $TARGET/boot/efi
        for p in $UEFI_PARTITION ; do umount -f $p ; done

        if str::InList APPLE $STORAGE_OPTIONS \
        && [[ "$( fs::GetPartitionType $UEFI_DEVICE )" == "AF00" ]] ; then
            fsck.hfsplus -f $UEFI_PARTITION
            mount -t hfsplus -o force,rw $UEFI_PARTITION $TARGET/boot/efi
            sys::Chk
        else
            mount $UEFI_PARTITION $TARGET/boot/efi
            sys::Chk
        fi
    fi

    # WORKAROUND zpool needs mtab: update-grub -> grub-mkconfig -> grub-probe -> zpool
    ln -s /proc/mounts $TARGET/etc/mtab

    cat /proc/mounts # DEBUG
}


UnmountChroot ()
{
    rm -f $TARGET/etc/mtab

    # uefi
    if awk -v p="$TARGET/boot/efi" '$2==p{ok=1;exit} END{exit !ok}' /proc/mounts ; then
        umount -f "$TARGET/boot/efi"
        sys::Chk
    fi

    # bootclone ext + bootclone  zfs
    for bootcloneMount in $TARGET/boot $TARGET$BOOTCLONE_MNTP ; do
        if awk -v p="$bootcloneMount" '$2==p{ok=1;exit} END{exit !ok}' /proc/mounts ; then
            umount -f "$bootcloneMount"
            sys::Chk
        fi
    done

    # umount known lockers
    for i in /sys/kernel/security /proc/sys/fs/binfmt_misc ; do
        if grep -E "^[^ ]+ $TARGET$i " /proc/mounts ; then
            umount -f $TARGET$i
            sys::Chk
        fi
    done

    # unmount ZFS children
    if str::InList ZFS $STORAGE_OPTIONS ; then

        while IFS= read -r i || [[ -n $i ]] ; do
            umount -f "$i"
            sys::Chk
        done <  <( zfs mount | awk 'NR>1{print $2}' | sort | tac )

        # # DATA
        # if [[ -n "$ZFS_DATA_DSET" ]] ; then

        #     while IFS= read -r i || [[ -n $i ]] ; do

        #            zfs get -H mounted "$i" \
        #         |  awk '$3=="yes"{ok=1} END{exit !ok}' \
        #         || continue

        #         umount -f "$i"
        #         sys::Chk

        #     done <  <(    zfs get -r -t filesystem -H mountpoint $ZFS_POOL_NAME/$ZFS_DATA_DSET \
        #                 | awk '(NR>1)&&($3!="legacy")&&($3!="none") {print $1}' \
        #                 | tac
        #              )

        #     umount -f "$TARGET/$( basename $ZFS_DATA_DSET )/$USER_USERNAME"
        #     sys::Chk
        #     umount -f "$TARGET/$( basename $ZFS_DATA_DSET )"
        #     sys::Chk
        # fi

        # while IFS= read -r i || [[ -n $i ]] ; do
        #        zfs get -H mounted "$i" \
        #     |  awk '$3=="yes"{ok=1} END{exit !ok}' \
        #     || continue

        #     umount -f "$i"
        #     sys::Chk
        # done <  <(    zfs get -r -t filesystem -H mountpoint $ZFS_POOL_NAME/$ZFS_ROOT_DSET \
        #             | awk 'NR>1 {print $1}' \
        #             | tac
        #          )

        zfs mount # DEBUG
    fi


    umount -f $TARGET/proc     ; sys::Chk
    umount -f $TARGET/sys      ; sys::Chk
    umount -f $TARGET/dev/pts  ; sys::Chk
    umount -f $TARGET/dev      ; sys::Chk

    local ret=1
    for i in $( seq 0 16 ) ; do
        umount -f $TARGET
        ret=$?
        [[ $ret -eq 0 ]] && break
        sleep 2
    done
    [[ $ret -ne 0 ]] && sys::Die "Failed to unmount TARGET $TARGET"

    cat /proc/mounts # DEBUG
}


ChrootedInstaller ()
{
    sys::LogOutput

    ## DEBUG
    sys::GetVarsDefinitions $CORE_PREF $AUTO_PREF


    ## Hostname
    hostname "$HOST_HOSTNAME"
    echo "$HOST_HOSTNAME" >/etc/hostname
    echo "127.0.0.1       localhost $HOST_HOSTNAME $HOST_HOSTNAME.local" >>/etc/hosts


    ## LOCALE
    locale-gen en_US en_US.UTF-8 en_AU.UTF-8 en_DK.UTF-8
    sys::Chk
    sys::Write <<EOF  /etc/default/locale
LANG=en_US.UTF-8
LANGUAGE=en_US:en
LC_COLLATE=C
LC_NUMERIC=C
LC_MEASUREMENT=en_DK.utf8
LC_PAPER=en_DK.utf8
LC_TIME=en_DK.utf8
EOF


    ## TIMEZONE
    ln -sf /usr/share/zoneinfo/$HOST_TIMEZONE /etc/localtime
    sys::Chk
    echo "$HOST_TIMEZONE" > /etc/timezone
    dpkg-reconfigure -f noninteractive tzdata
    sys::Chk


    ## KEYBOARD
    sed -i -E \
        -e 's#^(\s*XKBMODEL=).*#\1"'"$KEYBOARD_MODEL"'"#' \
        -e 's#^(\s*XKBLAYOUT=).*#\1"'"$KEYBOARD_LAYOUT"'"#' \
        -e 's#^(\s*XKBVARIANT=).*#\1"'"$KEYBOARD_VARIANT"'"#' \
        /etc/default/keyboard
    cat /etc/default/keyboard # DEBUG
    dpkg-reconfigure -f noninteractive keyboard-configuration
    sys::Chk


    ## USER
    adduser \
        --disabled-password \
        --shell /bin/bash \
        --gecos "" \
        $USER_USERNAME
    sys::Chk
    adduser $USER_USERNAME sudo
    sys::Chk
    adduser $USER_USERNAME users
    sys::Chk
    adduser $USER_USERNAME video
    sys::Chk
    adduser $USER_USERNAME audio
    sys::Chk
    # TOCHECK lpadmin power adm audio dialout cdrom floppy input plugdev scanner


    ## APT
    apt::Update
    apt::Upgrade


    # BUG: broken display in VirtualBox
    # TIP: console-setup-linux:setupcon
    # WORKAROUND: change tty
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        sleep 1
        chvt 1
        sleep 1
        chvt 7
    fi


    ## KERNEL
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPackages linux-generic-hwe-16.04-edge
    else
        apt::AddPackages linux-generic
    fi


    ## MD
    local bootCount=$( str::GetWordCount $BOOT_PARTITION )
    local swapCount=$( str::GetWordCount $SWAP_PARTITION )
    local poolMdCount=0
    str::InList ZFS $STORAGE_OPTIONS || poolMdCount=$( str::GetWordCount $POOL_PARTITION )

    if [[ $bootCount   -gt 1 ]] \
    || [[ $swapCount   -gt 1 ]] \
    || [[ $poolMdCount -gt 1 ]]
    then
        apt::AddPackages mdadm
        service mdadm stop
        # DOC: MD monitoring
        # MAILADDR  The mailaddr line gives an E-mail address that alerts should be sent to when mdadm is running in --monitor mode (and was given the --scan option). There should only be one MAILADDR line and it should have only one address.
        # MAILFROM  The mailfrom line (which can only be abbreviated to at least 5 characters) gives an address to appear in the "From" address for alert mails. This can be useful if you want to explicitly set a domain, as the default from address is "root" with no domain. All words on this line are catenated with spaces to form the address.
        # PROGRAM   The program line gives the name of a program to be run when mdadm --monitor detects potentially interesting events on any of the arrays that it is monitoring. This program gets run with two or three arguments, they being the Event, the md device, and possibly the related component device.
    fi


    ## ZFS
    if str::InList ZFS $STORAGE_OPTIONS ; then

        zfs::Install

        if [[ -n "$ZFS_DATA_DSET" ]] ; then
            chown $USER_USERNAME:$USER_USERNAME \
                /$( basename $ZFS_DATA_DSET ) \
                /$( basename $ZFS_DATA_DSET )/$USER_USERNAME
        fi

        # Scrub FROM https://github.com/lnicola/systemd-zpool-scrub
        sys::Write <<EOF /etc/systemd/system/zpool-scrub@.service
[Unit]
Description=Scrub ZFS Pool
Requires=zfs.target
After=zfs.target

[Service]
Type=oneshot
ExecStartPre=-/usr/bin/zpool scrub -s %i
ExecStart=/usr/bin/zpool scrub %i
EOF
        sys::Write <<EOF /etc/systemd/system/zpool-scrub@.timer
[Unit]
Description=Scrub ZFS pool weekly

[Timer]
OnCalendar=monthly
Persistent=true

[Install]
WantedBy=timers.target
EOF
        systemctl enable zpool-scrub@$ZFS_POOL_NAME.timer
    fi


    ## INITRAMFS CRYPTO_ROOT
    ConfigureInitramfs


    ## UDEV
    ConfigureUdev


    ## SSH_UNLOCK
       str::InList SSH_UNLOCK $STORAGE_OPTIONS \
    && InstallDropbear


    ## GRUB
    ConfigureGrub


    # Install bootloader
    if [[ "$INSTALL_MODE" == "MenuInstall" ]] ; then

        local grubBootDirectory=/boot
        str::InList BOOTCLONE $STORAGE_OPTIONS && grubBootDirectory=$BOOTCLONE_MNTP

        # grub-script-check "$grubBootDirectory/grub.cfg"
        # sys::Chk

        if str::InList UEFI $STORAGE_OPTIONS ; then

            mkdir -p /boot/efi/EFI/$UEFI_NAME/

            modprobe efivars

            # DBG
            efibootmgr -v

            grub-install \
                --target=x86_64-efi \
                --efi-directory=/boot/efi \
                --bootloader-id=$UEFI_NAME \
                --product-version="" \
                --boot-directory=$grubBootDirectory # TOCHECK: --no-floppy
            sys::Chk


            # DEBUG /boot/efi RO
            find /boot/efi/EFI/$UEFI_NAME # DEBUG boot.efi + grubx64.efi
            efibootmgr -v


            if str::InList APPLE $STORAGE_OPTIONS \
            && [[ -d "/boot/efi/EFI/$UEFI_NAME/System/Library/CoreServices" ]] ; then

                if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
                    apt::AddPpaPackages detly/mactel-utils mactel-boot
                else
                    apt::AddPpaPackages --release xenial \
                        detly/mactel-utils mactel-boot
                fi

                hfs-bless /boot/efi/EFI/$UEFI_NAME/System/Library/CoreServices/boot.efi
                sys::Chk

                cp /boot/efi/EFI/$UEFI_NAME/{System/Library/CoreServices/boot.efi,}
                sys::Chk

                touch /boot/efi/EFI/$UEFI_NAME/mach_kernel

                sys::XmlstarletInline \
                    /boot/efi/EFI/$UEFI_NAME/System/Library/CoreServices/SystemVersion.plist \
                    --update '(/plist/dict/string)[3]' \
                    --value "$PRODUCT_VERSION" \

            fi

            # Volume icon (Apple EFI1.5 & UEFI2)
            base64 -d >"/boot/efi/EFI/$UEFI_NAME/.VolumeIcon.icns" \
                <<<"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b8T+/////////////////////////////////////////////////9WAJAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAdVu/7/////////////////////////////////////////////////////////zGYKAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABuI7f///////////////////////////////////////////////////////////////+2GGQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACah+f/////////////////////////////////////////////////////////////////////5niMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACCf+///////////////////////////////////////////////////////////////////////////+pseAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAVv9P////////////////////////////////////////////////////////////////////////////////aABwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABB1v/////////////////////////////////////////////////////////////////////////////////////bRwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAaov//////////////////////////////////////////////////////////////////////////////////////////sx4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAV/H/////////////////////////////////////////////////////////////////////////////////////////////8FQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACJH//////////////////////////////////////////////////////////////////////////////////////////////////6IJAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACbP/////////////////////////////////////////////////////////////////////////////////////////////////////84kAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABX8v////////////////////////////////////////////////////////////////////////////////////////////////////////FUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAb/3///////////////////////////////////////////////////////////////////////////////////////////////////////////51AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAYj///////////////////////////////////////////////////////////////////////////////////////////////////////////////+RAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAOc//////////////////////////////////////////////////////////////////////////////////////////////////////////////////+iBQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKtP////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+yCQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA6////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+0BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGe//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+jAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAi/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+IAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHb///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////9zAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABX/v////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////5UAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJPH///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////MnAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAjO/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////9EJAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAmP///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////5MAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAFb//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////1kAAAAAAAAAAAAAAAAAAAAAAAAAAAAc8f//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////8BoAAAAAAAAAAAAAAAAAAAAAAAAAAKv/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////pgAAAAAAAAAAAAAAAAAAAAAAAABG////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////QwAAAAAAAAAAAAAAAAAAAAAAB9j////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////aBwAAAAAAAAAAAAAAAAAAAAB///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////96AAAAAAAAAAAAAAAAAAAAIPf///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////UeAAAAAAAAAAAAAAAAAACf/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////5oAAAAAAAAAAAAAAAAAJfv/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+iMAAAAAAAAAAAAAAACh////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////nQAAAAAAAAAAAAAAG/n////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////4GQAAAAAAAAAAAACJ//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+FAAAAAAAAAAAACO3//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+wHAAAAAAAAAABd/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////1gAAAAAAAAAAML/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////vAAAAAAAAAAh/v/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+HQAAAAAAAHj///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////9yAAAAAAAAzf///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////8gAAAAAABz//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////hoAAAAAZv//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////YQAAAACu//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+pAAAAAu7//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+sBAAAs/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////ygAAGf/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////YwAAm/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+ZAADK/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////8cAA/X/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////9AIj////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////H0T///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////9AZP///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////2CC////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////gJf///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+Uq////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////6i9////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////u8b////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////EzP///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////8vS////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////0tL////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////SzP///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////8vG////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////xL3///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+7qv///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////6eW////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////k4H///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////9/ZP///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////2BD////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////PyL///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////8eAvT/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////8gEAyf/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////FAACb/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////5gAAGX/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////YgAAKv////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////8mAAAB7f//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////6gEAAACt//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+oAAAAAGT//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////18AAAAAHP7////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+GQAAAAAAy////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////8YAAAAAAAB1////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////bwAAAAAAACD+//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////0cAAAAAAAAAMD/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////ugAAAAAAAAAAW/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////9XAAAAAAAAAAAI7P//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////6wcAAAAAAAAAAACG//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+CAAAAAAAAAAAAABf3////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+BgAAAAAAAAAAAAAAJ7///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+aAAAAAAAAAAAAAAAAI/r/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+iIAAAAAAAAAAAAAAAAAnP////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+XAAAAAAAAAAAAAAAAAAAe9f//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////9BwAAAAAAAAAAAAAAAAAAAB7//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////92AAAAAAAAAAAAAAAAAAAAAAbX////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////1QUAAAAAAAAAAAAAAAAAAAAAAET///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////9CAAAAAAAAAAAAAAAAAAAAAAAAAKj/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////owAAAAAAAAAAAAAAAAAAAAAAAAAAGvD//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+4YAAAAAAAAAAAAAAAAAAAAAAAAAAAAVP/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+UQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAlP///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////48AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHzf/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////LBgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAj8P//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////7yIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABU/v////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////1QAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABq////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////cAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACI/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////4MAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGc//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+iAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAOt////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////swQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAmy/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////7EJAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAOa//////////////////////////////////////////////////////////////////////////////////////////////////////////////////+hBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGA////////////////////////////////////////////////////////////////////////////////////////////////////////////////kQEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABt/f///////////////////////////////////////////////////////////////////////////////////////////////////////////nMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABU8f///////////////////////////////////////////////////////////////////////////////////////////////////////+9QAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAfyP/////////////////////////////////////////////////////////////////////////////////////////////////////MIwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHkf7/////////////////////////////////////////////////////////////////////////////////////////////////mQYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAVPD/////////////////////////////////////////////////////////////////////////////////////////////7lAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGaL+/////////////////////////////////////////////////////////////////////////////////////////7McAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/V/////////////////////////////////////////////////////////////////////////////////////9pGAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAVv8/////////////////////////////////////////////////////////////////////////////////WABwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAemvr///////////////////////////////////////////////////////////////////////////mXHAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAI534//////////////////////////////////////////////////////////////////////iaIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABmG7P///////////////////////////////////////////////////////////////+uEFwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHWb3+/////////////////////////////////////////////////////////btXBwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB1yyP7////////////////////////////////////////////////+xnAcAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGWGp6////////////////////////////////////////+qoYBgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABKGOZx/P///////////////////////////LGmWIoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAR9AYYGUp7rGzM7OzMa6p5SAYD8fAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
            # TIP: create icns
            #             apt::AddPackages librsvg2-bin icnsutils # PULLS HELL
            #             rsvg-convert -w 128 -h 128 -o $tmppng $tmpsvg
            #             png2icns /boot/efi/EFI/$UEFI_NAME/.VolumeIcon.icns $tmppng


            # Fix VirtualBox: only boots /EFI/BOOT/BOOTX64.EFI
            if grep -q VirtualBox /proc/bus/input/devices ; then
                mkdir -p /boot/efi/EFI/BOOT
                cp /boot/efi/EFI/$UEFI_NAME/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI
                rm -rf /boot/efi/EFI/$UEFI_NAME/grubx64.efi
                [[ "$UEFI_NAME" != "BOOT" ]] && rm -rf /boot/efi/EFI/$UEFI_NAME
            fi

        else # NOT UEFI

            for grubDevice in $GRUB_DEVICE; do

                # PATH=$path grub-install \
                grub-install \
                    --target=i386-pc \
                    --boot-directory=$grubBootDirectory \
                    $grubDevice
                sys::Chk

            done

        fi

    else # MenuExtend

        # BOOTCLONE
        local bootcloneName=$( str::SanitizeString "${ZFS_ROOT_DSET##*/}" )
        local bootcloneMain bootcloneBoot

        if [[ "$BOOTCLONE_TYPE" == "ext" ]] ; then
            bootcloneMain="$BOOTCLONE_BOOT/$bootcloneName"
        else
            bootcloneMain="/$ZFS_ROOT_DSET@/boot"
        fi

        sys::Write --append <<EOF $BOOTCLONE_MNTP$BOOTCLONE_HEAD
menuentry '[extend ] $bootcloneName' --unrestricted {
  configfile $bootcloneMain/grub/grub.cfg
}

EOF

    fi



    ## MISC FIXES
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        # Disable ureadahead
        echo manual >/etc/init/ureadahead.override       # FIX ureadahead: Error while tracing: No such file or directory
        echo manual >/etc/init/ureadahead-other.override # FIX ureadahead:/var/lib/ureadahead/*.pack: No such file or directory
    fi

    ## HOOK HookInChroot
       [[ "$( type -t HookInChroot 2>/dev/null )" == "function" ]] \
    && HookInChroot


    ## SYNC
    update-initramfs -c -k all
    sys::Chk

    update-grub
    sys::Chk

    if str::InList BOOTCLONE $STORAGE_OPTIONS ; then
        bootclone update
        sys::Chk
    fi


    ## CLEAN
    Clean

    sys::UnLogOutput
}


GenerateFstab ()
{
    {
        echo "#DEVICE MOUNTPOINT TYPE OPTIONS DUMP PASS"

        # pool
        if str::InList ZFS $STORAGE_OPTIONS ; then
            # zfs
            echo "$ZFS_POOL_NAME/$ZFS_ROOT_DSET / zfs defaults,noatime 0 0"
        elif [[ "$POOL_DEVICE" == "$POOL_PARTITION" ]]; then
            # single
            echo "UUID=$( fs::GetPartitionUuid $POOL_DEVICE ) / $BOOT_FS defaults,noatime 0 1"
        else
            # mdraid
            echo "$POOL_DEVICE / $BOOT_FS defaults,noatime 0 1"
        fi

        # boot
        if [[ -n "$BOOT_PARTITION" ]] ; then

            if   str::InList BOOTCLONE $STORAGE_OPTIONS \
              && [[ "$BOOTCLONE_TYPE" == "ext" ]]
            then
                # bootclone-ext
                echo "$BOOT_DEVICE $BOOTCLONE_MNTP $BOOT_FS defaults,noatime 0 2"
                echo "$BOOTCLONE_MNTP$BOOTCLONE_BOOT/$( str::SanitizeString "${ZFS_ROOT_DSET##*/}" ) /boot none bind 0 4"
            elif ! str::InList CRYPTO_BOOT $STORAGE_OPTIONS \
              && [[ $( str::GetWordCount $BOOT_PARTITION ) -eq 1 ]]
            then
                # single
                echo "UUID=$( fs::GetPartitionUuid $BOOT_DEVICE ) /boot $BOOT_FS defaults,noatime 0 2"
            else
                # mdraid
                echo "$BOOT_DEVICE /boot $BOOT_FS defaults,noatime 0 2"
            fi
        fi

        if   str::InList BOOTCLONE $STORAGE_OPTIONS \
          && [[ "$BOOTCLONE_TYPE" == "zfs" ]]
        then
            # bootclone-zfs
            echo "$ZFS_POOL_NAME$BOOTCLONE_GRUB $BOOTCLONE_MNTP zfs defaults,noatime,noauto 0 0"
        fi

        # uefi
        if str::InList UEFI $STORAGE_OPTIONS ; then
            local efi_type=vfat
            [[ "$( fs::GetPartitionType $UEFI_DEVICE )" == "AF00" ]] && efi_type=hfsplus
            echo "UUID=$( fs::GetPartitionUuid $UEFI_DEVICE ) /boot/efi $efi_type defaults,noatime 0 0"
        fi

        # swap
        if [[ -n "$SWAP_PARTITION" ]] ; then

            if [[ "$SWAP_DEVICE" == "$SWAP_PARTITION" ]]; then
                # single
                echo "UUID=$( fs::GetPartitionUuid $SWAP_DEVICE ) swap swap sw 0 0"
            else
                # mdraid
                echo "$SWAP_DEVICE swap swap sw 0 0"
            fi

        fi

    } | column -t
}


ConfigureInitramfs ()
{

    # VirtFS/9P support
    sys::Write --append <<'EOF' /usr/share/initramfs-tools/modules
9p
9pnet
9pnet_virtio
EOF

    if [[ "$UBUNTU_RELEASE" == "bionic" ]] \
    && str::InList ZFS $STORAGE_OPTIONS ; then

        # Hide useless error: Failed to start Import ZFS pools by cache file
        sed -i -E '#^([Unit])#\1\nConditionPathExists=/etc/zfs/zpool.cache#' \
            /lib/systemd/system/zfs-import-cache.service

        # WORKAROUND BIONIC ZFS irfs bug: https://github.com/zfsonlinux/pkg-zfs/issues/221
        # https://github.com/zfsonlinux/zfs/pull/6897/files
        cp /usr/share/initramfs-tools/scripts/zfs \
            /etc/initramfs-tools/scripts/zfs

        sys::PatchText <<'EOPATCH' /etc/initramfs-tools/scripts/zfs
@@ -337,9 +337,14 @@
            "$mountpoint" = "-" ]
        then
            if [ "$fs" != "${ZFS_BOOTFS}" ]; then
-               # We don't have a proper mountpoint and this
-               # isn't the root fs.
-               return 0
+               if [ "$fs" != "${fs#$ZFS_BOOTFS/}" ]; then
+                   # BOOTFS children inherit mountpoint
+                   mountpoint="${fs#$ZFS_BOOTFS}"
+               else
+                   # We don't have a proper mountpoint and this
+                   # isn't the root fs.
+                   return 0
+               fi
            else
                # Last hail-mary: Hope 'rootmnt' is set!
                mountpoint=""
EOPATCH

        chattr +i /etc/initramfs-tools/scripts/zfs

    fi


    # BOOTCLONE Fix multi-rooting init
    if str::InList BOOTCLONE $STORAGE_OPTIONS ; then

        sys::Write <<'EOF' /etc/initramfs-tools/scripts/local-premount/bootclone 0:0 755
#!/bin/sh -e
# DESC Set ZFS / mountpoints to legacy

[ "$1" = "prereqs" ] && exit

# DEV: EXTERNAL DEPS FOR zfs-initramfs
. /scripts/functions

zfs_test_import()
{
    ZFS_STDERR=$(zpool import -o readonly=on -N "$ZFS_RPOOL" 2>&1)
    ZFS_ERROR=$?
    if [ "$ZFS_ERROR" -eq 0 ]
    then
        ZFS_HEALTH=$(zpool list -H -o health "$ZFS_RPOOL" 2>/dev/null)
    fi
    zpool export "$ZFS_RPOOL" >/dev/null 2>&1
}

# DEV: EXTERNAL import CODE FROM zfs-initramfs

    # Wait for all of the /dev/{hd,sd}[a-z] device nodes to appear.
    wait_for_udev

    modprobe zfs zfs_autoimport_disable=1

    ZFS_BOOTFS=${ROOT#ZFS=}
    ZFS_RPOOL=$(echo "$ZFS_BOOTFS" | sed -e 's,/.*,,')

    delay=${ROOTDELAY:-0}

    if [ "$delay" -gt 0 ]
    then
        # Try to import the pool read-only.  If it does not import with
        # the ONLINE status, wait and try again.  The pool could be
        # DEGRADED because a drive is really missing, or it might just
        # be slow to be detected.
        zfs_test_import
        retry_nr=0
        while [ "$retry_nr" -lt "$delay" ] && [ "$ZFS_HEALTH" != "ONLINE" ]
        do
            /bin/sleep 1
            zfs_test_import
            retry_nr=$(( $retry_nr + 1 ))
        done
        unset retry_nr
        unset ZFS_HEALTH
    fi
    unset delay

    # At this point, the pool either imported cleanly, or we ran out of the
    # allowed time (rootdelay).  Perform the read-write import.
    zpool import -N "$ZFS_RPOOL" || exit

# DEV: MAIN CODE
# DOC: Set 'mountpoint=legacy' to all /-targeted ZFS datasets

  zfs get -r -t filesystem -H -o value -r mountpoint,name \
| (
    rstate=0
    while IFS= read -r i ; do
        case $rstate in
            0) rstate=1 ; [ "$i" = "/" ] && rstate=2 ;;
            1) rstate=0 ;;
            2) rstate=0 ;
               [ "$i" != "${ROOT#ZFS=}" ] \
            && zfs set mountpoint=legacy "$i" ;;
        esac
    done
)

# DEV: CLEAN so zfs script can import again

    zfs unmount -f -a  >/dev/null 2>&1
    zpool export "$ZFS_RPOOL" >/dev/null 2>&1

EOF
        sys::Write <<'EOF' /etc/initramfs-tools/scripts/local-bottom/bootclone 0:0 755
#!/bin/sh -e
# DESC Umount all zfs mounts except /

[ "$1" = "prereqs" ] && exit

  zfs get -r -t filesystem -H -o value -r mounted,mountpoint  \
| (
    rstate=0
    while IFS= read -r i ; do
        case $rstate in
            0) rstate=1 ; [ "$i" = "yes" ] && rstate=2 ;;
            1) rstate=0 ;;
            2) rstate=0 ; [ "$i" != "/" -a "$i" != "legacy" -a "$i" != "none"]  && echo "$i" ;;
        esac
    done
  ) \
| sort -r \
| while IFS= read -r j ; do
    umount -f "$j"
  done
EOF
    fi


    # CRYPTO
    str::InList CRYPTO_ROOT $STORAGE_OPTIONS || return

    # FIX cryptoroot detection
    if [[ -z "$BOOT_PARTITION" ]] || str::InList ZFS $STORAGE_OPTIONS ; then
        echo "export CRYPTSETUP=y" >/usr/share/initramfs-tools/conf-hooks.d/force-cryptsetup
    fi


    local luksKey="key=none" luksScript

    # hooks
    if ! str::InList PLAIN_BOOT $STORAGE_OPTIONS ; then

        # LUKS key into initramfs

        luksKey="key=/root/$(basename $LUKS_KEY),keyscript=/bin/cat"


        if   str::InList BOOTCLONE $STORAGE_OPTIONS \
          && [[ "$BOOTCLONE_TYPE" == "zfs" ]] ; then

            # BOOTCLONE zfs: /mnt/bootclone does not get automounted
            cat <<EOF >/etc/initramfs-tools/hooks/copy-luks-key.sh
#!/bin/sh -e

[ "\$1" = "prereqs" ] && exit
# PREREQS=""
# case \$1 in prereqs) echo "\$PREREQS"; exit 0;; esac
#. /usr/share/initramfs-tools/hook-functions

mkdir -p \$DESTDIR/root

bootcloneMount=\$( grep -E "^\S+ $BOOTCLONE_MNTP zfs" /proc/mounts || true )

   [ -z "\$bootcloneMount" ] \\
&& mount $BOOTCLONE_MNTP  \\
&& trap "umount $BOOTCLONE_MNTP" INT TERM EXIT QUIT \\
|| true

cp --remove-destination $LUKS_KEY \$DESTDIR/root
EOF

        else # NOT BOOTCLONE

            cat <<EOF >/etc/initramfs-tools/hooks/copy-luks-key.sh
#!/bin/sh -e

[ "\$1" = "prereqs" ] && exit
# PREREQS=""
# case \$1 in prereqs) echo "\$PREREQS"; exit 0;; esac
#. /usr/share/initramfs-tools/hook-functions

mkdir -p \$DESTDIR/root

cp --remove-destination $LUKS_KEY \$DESTDIR/root
EOF

        fi
        chmod +x /etc/initramfs-tools/hooks/copy-luks-key.sh


        # also /bin/cat into initramfs

        cat <<EOF >/etc/initramfs-tools/hooks/copy-cat.sh
#!/bin/sh -e
[ "\$1" = "prereqs" ] && exit
# PREREQS=""
# case \$1 in prereqs) echo "\$PREREQS"; exit 0;; esac
#. /usr/share/initramfs-tools/hook-functions
cp --remove-destination /bin/cat \$DESTDIR/bin
EOF
        chmod +x /etc/initramfs-tools/hooks/copy-cat.sh



    elif [[ $( str::GetWordCount $POOL_PARTITION ) -gt 1 ]] ; then

        # PLAIN_BOOT: decrypt_derived helper

        luksScript=/scripts/luks/decrypt_derived.auto

        mkdir -p $( dirname /etc/initramfs-tools$luksScript )

        cat <<EOF >/etc/initramfs-tools$luksScript
#!/bin/sh
[ "\$1" = "prereqs" ] && exit

# PATCH: pre-exec to force \$1 argument to derive from any unlocked pool device
if [ -z "\$1" ] ; then
    lastFound=\$( dmsetup table 2>/dev/null | grep -e "^$LUKS_POOL_NAME" | cut -d: -f1 | tail -1 )
    exec /bin/sh \$( readlink -f \$0 ) \$lastFound
fi

# ORIG /lib/cryptsetup/scripts/decrypt_derived follows:

EOF
        cat /lib/cryptsetup/scripts/decrypt_derived >>/etc/initramfs-tools$luksScript
        chmod +x /etc/initramfs-tools$luksScript
    fi


    # boot entry

    if str::InList CRYPTO_BOOT $STORAGE_OPTIONS ; then

        local bootPartitionUuid=$BOOT_MD
           [[ $( str::GetWordCount $BOOT_PARTITION ) -gt 1 ]] \
        || bootPartitionUuid="UUID="$( fs::GetPartitionUuid $BOOT_PARTITION )

        echo "$LUKS_BOOT_NAME $bootPartitionUuid none luks" \
            >>/etc/crypttab
# TODO TRIM allow-discards
        echo "target=$LUKS_BOOT_NAME,source=$bootPartitionUuid,$luksKey,rootdev" \
            >>/etc/initramfs-tools/conf.d/cryptroot

    fi


    # pool entry

    if   [[ $( str::GetWordCount $POOL_PARTITION ) -eq 1 ]] \
      || str::InList ZFS $STORAGE_OPTIONS
    then

        local poolPartitionUuid suffix idx=0 cnt=$( str::GetWordCount $POOL_PARTITION )

        for poolPartition in $POOL_PARTITION ; do

            poolPartitionUuid="UUID="$( fs::GetPartitionUuid $poolPartition )
            [[ $cnt -gt 1 ]] && suffix="-$idx"

            if str::InList PLAIN_BOOT $STORAGE_OPTIONS && [[ $cnt -gt 1 ]] && [[ $idx -ne 0 ]]; then
                echo "$LUKS_POOL_NAME$suffix $poolPartitionUuid $LUKS_POOL_NAME-0 luks,keyscript=/lib/cryptsetup/scripts/decrypt_derived" \
                    >>/etc/crypttab
# TODO TRIM ,allow-discards
                echo "target=$LUKS_POOL_NAME$suffix,source=$poolPartitionUuid,keyscript=$luksScript,rootdev" \
                    >>/etc/initramfs-tools/conf.d/cryptroot
            else
                # DOC crypttab FORMAT: TARGET SOURCE KEYFILE OPTIONS
                echo "$LUKS_POOL_NAME$suffix $poolPartitionUuid none luks" \
                    >>/etc/crypttab
# TODO TRIM ,allow-discards
                echo "target=$LUKS_POOL_NAME$suffix,source=$poolPartitionUuid,$luksKey,rootdev" \
                    >>/etc/initramfs-tools/conf.d/cryptroot
            fi

            ((idx++))
        done

    else
        echo "$LUKS_POOL_NAME $POOL_MD none luks" \
            >>/etc/crypttab
# TODO TRIM ,allow-discards
        echo "target=$LUKS_POOL_NAME,source=$POOL_MD,$luksKey,rootdev" \
            >>/etc/initramfs-tools/conf.d/cryptroot
    fi


    # swap entry

    local poolAny=$LUKS_POOL_NAME
       str::InList ZFS $STORAGE_OPTIONS \
    && [[ $( str::GetWordCount $POOL_PARTITION ) -gt 1 ]] \
    && poolAny=${LUKS_POOL_NAME}-0

    if [[ -n "$SWAP_PARTITION" ]] ; then

        local swapPartitionUuid=$SWAP_MD
           [[ $( str::GetWordCount $SWAP_PARTITION ) -gt 1 ]] \
        || swapPartitionUuid="UUID="$( fs::GetPartitionUuid $SWAP_PARTITION )

        if str::InList CRYPTO_BOOT $STORAGE_OPTIONS ; then
            echo "target=$LUKS_SWAP_NAME,source=$swapPartitionUuid,$luksKey" \
                >>/etc/initramfs-tools/conf.d/cryptroot
        else
            # PLAIN_BOOT || NOBOOT
            # echo "$LUKS_SWAP_NAME $swapPartitionUuid none luks" \

            echo "$LUKS_SWAP_NAME $swapPartitionUuid $poolAny luks,keyscript=/lib/cryptsetup/scripts/decrypt_derived" \
                >>/etc/crypttab
        fi
        echo "RESUME=$SWAP_DEVICE" \
            >/etc/initramfs-tools/conf.d/resume
    fi


    echo "KEYMAP=y" >> /etc/initramfs-tools/initramfs.conf
}



ConfigureUdev () # [ --temp ]
{
    # WORKAROUND GRUB "failed to get canonical path of"

    local perm=1
    [[ "$1" == "--temp" ]] && perm=0

    if str::InList CRYPTO_ROOT $STORAGE_OPTIONS ; then

        if str::InList ZFS $STORAGE_OPTIONS ; then

            # DEV: update-grub OR grub-install => grub-probe => zpool status pool
            local suffix idx=0 cnt=$( str::GetWordCount $POOL_PARTITION )
            for partition in $POOL_PARTITION ; do
                [[ $cnt -gt 1 ]] && suffix="-$idx"
                ((idx++))

                ln -sf /dev/mapper/$LUKS_POOL_NAME$suffix /dev/$LUKS_POOL_NAME$suffix

                   [[ $perm -eq 1 ]] \
                && echo "ENV{DM_NAME}==\"$LUKS_POOL_NAME$suffix\", SYMLINK+=\"\$env{DM_NAME}\"" \
                    >>/etc/udev/rules.d/99-local.rules
            done
        else
            ln -sf /dev/mapper/$LUKS_POOL_NAME /dev/$LUKS_POOL_NAME

               [[ $perm -eq 1 ]] \
            && echo "ENV{DM_NAME}==\"$LUKS_POOL_NAME\", SYMLINK+=\"\$env{DM_NAME}\"" \
                >>/etc/udev/rules.d/99-local.rules
        fi

    elif str::InList ZFS $STORAGE_OPTIONS ; then

        # WORKAROUND BUG grub zfs wholedisk
        # https://bugs.launchpad.net/ubuntu/+source/grub2/+bug/1527727
        # ALT TIP: ZPOOL_VDEV_NAME_PATH=YES zpool status

        local wholeDisks=$( for zfsdev in $POOL_DEVICE ; do
                                   fs::isDeviceType disk $zfsdev \
                                && fs::GetDeviceId $zfsdev
                            done
                          )

        if [[ -n "$wholeDisks" ]] ; then

            for disk in $wholeDisks ; do
                local id=$( fs::GetDeviceId $disk )
                [[ -b "$id-part1" ]] || continue
                ln -sf --relative --logical "$id-part1" "/dev/$( basename "$id" )"
                sys::Chk
            done

               [[ $perm -eq 1 ]] \
            && sys::Write <<'EOF' /etc/udev/rules.d/60-zpool-fix-grub-wholedisk.rules
ENV{DEVTYPE}=="partition", IMPORT{parent}="ID_*", ENV{ID_FS_TYPE}=="zfs_member", SYMLINK+="$env{ID_BUS}-$env{ID_SERIAL}"
EOF
            # udevadm trigger
        fi

    # TIP: udevadm monitor --environment --udev
    # TIP: udevadm test $(udevadm info -n /dev/mapper/crypto-swap -q path)

    fi
}


ConfigureGrub ()
{
    if str::InList UEFI $STORAGE_OPTIONS ; then
        apt::AddPackages grub-efi-amd64 efibootmgr
    else
        apt::AddPackages grub-pc
    fi

    # divert grub config: 00_header 10_linux 30_os-prober
    mkdir /etc/grub.d/real
    for script in 00_header 10_linux 30_os-prober ; do
        # DEV: using subfolder to prevent execution
        dpkg-divert --add --rename --divert /etc/grub.d/real/$script /etc/grub.d/$script
        sys::Chk
        cp -p /etc/grub.d/real/$script /etc/grub.d/$script
    done

    # Disable os-prober
    chmod -x /etc/grub.d/30_os-prober

    # PATCH grub scripts to use bootclone
    if str::InList BOOTCLONE $STORAGE_OPTIONS ; then
        # TIP identify current bootclone: awk '$2=="/"&&$3="zfs"{printf $1}' /proc/mounts | tr -c "_[:alnum:]" "-"

        local bootcloneRelDirname bootcloneCode

        # bootclone-ext
        if [[ "$BOOTCLONE_TYPE" == "ext" ]] ; then
            bootcloneCode='$( awk '\''$2=="/" \&\& $3="zfs" {n=split($1,a,"/");printf a[n]}'\'' /proc/mounts | tr -c "_[:alnum:]" "-" )'
# TODO use fstab instead of procfs
            bootcloneRelDirname="$BOOTCLONE_BOOT/$bootcloneCode"

        # bootclone-zfs
        else
            bootcloneCode='$( awk '\''$2=="/" \&\& $3="zfs" {printf substr($1,index($1,"/")+1)}'\'' /proc/mounts )'
            bootcloneRelDirname="/$bootcloneCode@/boot"
        fi

        sed -i -E \
            's#^\s*rel_dirname=.*#rel_dirname='"$bootcloneRelDirname"'#' \
            /etc/grub.d/10_linux

    fi

    # PATCH grub scripts to WORKAROUND https://bugs.launchpad.net/ubuntu/+source/grub2/+bug/1274320
    # DEV ALT https://bugs.launchpad.net/ubuntu/+source/grub2/+bug/1274320/comments/115
    # DEV ALT https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=754921
    sed -i -E \
        's#^\s*quick_boot="1"#quick_boot="0"#' \
        /etc/grub.d/{00_header,10_linux,30_os-prober}

    # /etc/grub_force_options
    # DEV: USED BY drv::Macbookpro82
    sys::PatchText <<'EOPATCH' /etc/grub.d/10_linux
@@ -199,6 +199,7 @@
        initrd  ${rel_dirname}/${initrd}
 EOF
   fi
+  [ -f /etc/grub_force_options ] && sed "s/^/$submenu_indentation/" /etc/grub_force_options
   sed "s/^/$submenu_indentation/" << EOF
 }
 EOF
EOPATCH

    # Lock patched config files
    chattr +i /etc/grub.d/{00_header,10_linux,30_os-prober}


    # FIX grub BUG: broken grub.cfg when zfs root pool is created from multiple crypto devices
    if   [[ "$UBUNTU_RELEASE" == "xenial" ]] \
      && str::InList ZFS         $STORAGE_OPTIONS \
      && str::InList CRYPTO_ROOT $STORAGE_OPTIONS \
      && [[ $( str::GetWordCount $POOL_PARTITION ) -gt 1 ]] ; then

        # divert grub mkconfig_lib
        dpkg-divert --add --rename --divert /usr/share/grub/grub-mkconfig_lib.real /usr/share/grub/grub-mkconfig_lib
        sys::Chk
        cp -p /usr/share/grub/grub-mkconfig_lib.real /usr/share/grub/grub-mkconfig_lib

        sys::PatchText <<'EOPATCH' /usr/share/grub/grub-mkconfig_lib
@@ -161,7 +161,7 @@
   done

   if [ x$GRUB_ENABLE_CRYPTODISK = xy ]; then
-      for uuid in "`"${grub_probe}" --device $@ --target=cryptodisk_uuid`"; do
+      for uuid in `"${grub_probe}" --device $@ --target=cryptodisk_uuid`; do
      echo "cryptomount -u $uuid"
       done
   fi
@@ -169,7 +169,7 @@
   # If there's a filesystem UUID that GRUB is capable of identifying, use it;
   # otherwise set root as per value in device.map.
   fs_hint="`"${grub_probe}" --device $@ --target=compatibility_hint`"
-  if [ "x$fs_hint" != x ]; then
+  isSingle () { [ $# -eq 1 ] || return 1; }; if [ "x$fs_hint" != x ] && isSingle $fs_hint ; then
     echo "set root='$fs_hint'"
   fi
   if fs_uuid="`"${grub_probe}" --device $@ --target=fs_uuid 2> /dev/null`" ; then
EOPATCH

        # Lock patched script
        chattr +i /usr/share/grub/grub-mkconfig_lib
    fi

    # Prevent grub updates
    apt-mark hold \
        grub-common \
        grub-pc \
        grub-pc-bin \
        grub-efi-amd64 \
        grub-efi-amd64-bin
    sys::Chk

    # Keyboard layout
      ckbcomp -model "$KEYBOARD_MODEL" -layout "$KEYBOARD_LAYOUT" -variant "$KEYBOARD_VARIANT" \
    | grub-mklayout -o /boot/grub/$KEYBOARD_LAYOUT.gkb
    sys::Chk

    # FIX: grub-install ignores GRUB_ENABLE_CRYPTODISK in /etc/default/grub.d/*.cfg
    if     str::InList CRYPTO_ROOT $STORAGE_OPTIONS \
      && ! str::InList PLAIN_BOOT  $STORAGE_OPTIONS ; then
        echo -e "\n\nGRUB_ENABLE_CRYPTODISK=y" >>/etc/default/grub
    fi

    # Configure defaults
    mkdir -p /etc/default/grub.d/

    if str::InList ZFS $STORAGE_OPTIONS ; then
        echo "GRUB_CMDLINE_LINUX_DEFAULT=\"boot=zfs rpool=$ZFS_POOL_NAME root=ZFS=$ZFS_POOL_NAME/$ZFS_ROOT_DSET bootfs=$ZFS_POOL_NAME/$ZFS_ROOT_DSET\"" \
            >/etc/default/grub.d/90-zfs-root.cfg
    elif str::InList PLAIN_BOOT $STORAGE_OPTIONS ; then
        echo "GRUB_CMDLINE_LINUX_DEFAULT=" \
            >/etc/default/grub.d/90-crypto-root.cfg # clear all opts to get rid of quiet splash
    fi

    cat <<EOF >/etc/default/grub.d/94-custom.cfg
GRUB_TERMINAL=console
GRUB_GFXPAYLOAD_LINUX=text
GRUB_TIMEOUT=0
# GRUB_TIMEOUT_STYLE=countdown # TODO instead of GRUB_HIDDEN_TIMEOUT*
GRUB_HIDDEN_TIMEOUT=1
GRUB_HIDDEN_TIMEOUT_QUIET=true
GRUB_RECORDFAIL_TIMEOUT=\$GRUB_TIMEOUT
GRUB_DISABLE_OS_PROBER=true
# GRUB_DISABLE_RECOVERY=true
unset GRUB_INIT_TUNE
EOF
    # TODO recordfail http://askubuntu.com/a/203198

}

InstallBootcloneGrub ()
{


    local bootcloneName bootcloneMain bootcloneBoot bootclonePref
    if [[ "$BOOTCLONE_TYPE" == "ext" ]] ; then
        bootclonePref=""
        bootcloneName=$( str::SanitizeString "${ZFS_ROOT_DSET##*/}" )
        bootcloneMain="$BOOTCLONE_BOOT/$bootcloneName"
        bootcloneBoot=""
    else
        bootclonePref="[install] "
        bootcloneName=$( str::SanitizeString "$ZFS_ROOT_DSET" )
        bootcloneMain="/$ZFS_ROOT_DSET@/boot"
        bootcloneBoot="$BOOTCLONE_GRUB@"
    fi

    # grub template header
    sys::Write <<EOF $TARGET$BOOTCLONE_MNTP$BOOTCLONE_HEAD
# DESC bootclone grub template header

# Pager
set pager=1

# Timing
set timeout=1
set timeout_style=countdown

# Keyboard
insmod keylayouts
insmod usb
insmod usb_keyboard
terminal_input console at_keyboard usb_keyboard0 usb_keyboard1
keymap $bootcloneBoot/grub/$KEYBOARD_LAYOUT.gkb


EOF
# TODO GRUB Background Image, Colors

# DEV: this breaks VBOX boot:
# insmod ehci
# insmod ohci
# insmod uhci
# REMOVED


    if [[ "$BOOTCLONE_TYPE" == "zfs" ]] ; then
        sys::Write --append <<EOF $TARGET$BOOTCLONE_MNTP$BOOTCLONE_HEAD
# Default
set default='$bootclonePref$bootcloneName'

menuentry '$bootclonePref$bootcloneName' --unrestricted {
  configfile $bootcloneMain/grub/grub.cfg
}

EOF
    else
        sys::Write --append <<EOF $TARGET$BOOTCLONE_MNTP$BOOTCLONE_HEAD
# Default
set default='$bootcloneName'

EOF
    fi

    # grub template footer
    sys::Write <<'EOF' $TARGET$BOOTCLONE_MNTP$BOOTCLONE_FOOT
# DESC bootclone grub template footer

EOF
# TOCHECK https://github.com/thias/glim
# TOCHECK http://www.supergrubdisk.org/wiki/Loopback.cfg

}


InstallBootclone ()
{
    [[ "$INSTALL_MODE" == "MenuInstall" ]] && InstallBootcloneGrub

    apt::AddPackages pv

    if [[ "$BOOTCLONE_TYPE" == "zfs" ]] ; then
        sys::Write <<EOF $TARGET/etc/bootclone.conf 0:0 644
BOOTCLONE_TYPE=zfs
EOF
    else
        sys::Write <<EOF $TARGET/etc/bootclone.conf 0:0 644
BOOTCLONE_TYPE=ext
BOOTCLONE_BOOT=$BOOTCLONE_BOOT
EOF
    fi
    sys::Write --append <<EOF $TARGET/etc/bootclone.conf
BOOTCLONE_MNTP=$BOOTCLONE_MNTP
BOOTCLONE_ROOT=$BOOTCLONE_ROOT
BOOTCLONE_HEAD=$BOOTCLONE_HEAD
BOOTCLONE_FOOT=$BOOTCLONE_FOOT
EOF
    
    # gnos-bootclone
    net::CloneGitlabRepo gnos/gnos-bootclone $TARGET/opt
    sys::Mkdir $TARGET/usr/local/sbin/
    ln -s /opt/gnos-bootclone/bootclone $TARGET/usr/local/sbin/
    sys::Chk
}


InstallDropbear ()
{

    # TIP: scp ~/.ssh/id_rsa user@192.168.1.68:.ssh/bootuntu.id_rsa
    ## ssh -v -i .ssh/bootuntu.id_rsa root@localhost -o UserKnownHostsFile=alt.known_hosts -p 2222


    apt::AddPackages dropbear

    # Dropbear Config
    sys::Write --append <<EOF /etc/default/dropbear

# SSH_UNLOCK
NO_START=1
EOF


    # Dropbear Key
    mkdir -p /etc/initramfs-tools/root/.ssh "$HOME/.ssh/"

    echo -n 'command="/bin/unlock" ' \
        >/etc/initramfs-tools/root/.ssh/authorized_keys \

      dropbearkey -t rsa -f "$HOME/.ssh/dropbear.id_rsa"  \
    | awk '$1=="ssh-rsa"' \
        >>/etc/initramfs-tools/root/.ssh/authorized_keys \

    chown $USER_USERNAME:$USER_USERNAME "$HOME/.ssh/dropbear.id_rsa"


    # IRFS Config
    sys::Write --append <<EOF /etc/initramfs-tools/initramfs.conf

# SSH_UNLOCK
# FORMAT: IP=[host ip]::[gateway ip]:[netmask]:[hostname]:[device]:[autoconf]
# IP DOC: http://www.kernel.org/pub/linux/kernel/people/marcelo/linux-2.4/Documentation/nfsroot.txt
# SAMPLE: "static" IP=192.168.1.68::192.168.1.1:255.255.255.0::eth0:off
# SAMPLE: "dhcp"   IP=:::::eth0:dhcp
IP=$IRFS_IP
DEVICE=$( cut -d: -f6 <<<"$IRFS_IP" )
DROPBEAR=y
EOF


    # IRFS hook: unlock
    sys::Write <<'EOF' /etc/initramfs-tools/hooks/crypt_unlock.sh 0:0 755
#!/bin/sh

PREREQS="dropbear"
case $1 in prereqs) echo "\$PREREQS"; exit 0;; esac

. "${CONFDIR}/initramfs.conf"
. /usr/share/initramfs-tools/hook-functions

if [ "${DROPBEAR}" != "n" ] && [ -r "/etc/crypttab" ] ; then
    cat <<'EOS' >"${DESTDIR}/bin/unlock"
#!/bin/sh
PATH=/lib/unlock:/bin:/sbin /scripts/local-top/cryptroot || exit 1
kill $( ps -w | awk '/\/(crypt|unlock)/{print $1}' )
exit 0
EOS
    chmod 755  "${DESTDIR}/bin/unlock"
fi
EOF


    # IRFS scripts: kill dropbear
    # DESC WORKAROUND buggy init-bottom/dropbear
    sys::Write <<'EOF' /etc/initramfs-tools/scripts/init-bottom/dropbear 0:0 755
#!/bin/sh
# DESC override init-bottom/dropbear
EOF
    sys::Write <<'EOF' /etc/initramfs-tools/scripts/local-bottom/dropbear 0:0 755
#!/bin/sh

[ "$1" = "prereqs" ] && exit

. /scripts/functions

if [ -s /run/dropbear.pid ] ; then
    log_begin_msg "Stoping dropbear"
    kill $(cat /run/dropbear.pid)
    log_end_msg
fi
EOF

    update-initramfs -u
}





########
# FUNC #  CORE
########




Accept ()
{
    [[ "INSTALLER_ACCEPT" == "1" ]] && return

    local response match='I ACCEPT'
    local msg1="WARNING
───────

Data on the following devices will be permanently DELETED:"

local msg2="Using this software without storage backups can lead to DATA LOSS"

# She will never forgive you for loosing these pictures and will go
# away with someone able to backup data, you will depress and loose
# your job and family, so please DON'T SAY YOU HAVE NOT BEEN WARNED

    # Resolve GRUB_DEVICE
    local grubDevice
    if ! str::InList UEFI $STORAGE_OPTIONS \
    && [[ -n "$GRUB_DEVICE" ]] ; then
# BUG ZZZ HERE if GRUB_DEVICE="/dev/A /dev/B"
        local partedOutput=$( parted $GRUB_DEVICE --script -- print  )
        if grep -q '^Partition Table: gpt' <<<"$partedOutput" ; then
            # GPT
            grubDevice=$(
                for dev in $GRUB_DEVICE ; do
                    awk -v disk=$dev \
                        '$NF=="bios_grub" {print disk $1"(GRUB)" }' \
                        <<<"$partedOutput"
                done
            )
        else
            # Loop / MBR
            grubDevice=$( for dev in $GRUB_DEVICE ; do echo "$dev(MBR)" ; done )
        fi
    else
# TODO UEFI Data on UEFI ESP will be MODIFIED: $UEFI_PARTITION
        :
    fi

    local allDevices=$(
        for dev in $grubDevice $BOOT_PARTITION $SWAP_PARTITION $POOL_PARTITION ; do
            echo ${dev#/dev/}
        done
     )
    allDevices=$( echo $allDevices )

    local msg="$msg1\n\n$allDevices\n\n\n$msg2"

    [[ "$INSTALLER_MENU" == "1" ]] || sys::Msg "$msg"

    while [[ "$response" != "$match" ]] ; do

        if [[ "$INSTALLER_MENU" == "1" ]] ; then
            response=$( whiptail \
                --cancel-button Exit --ok-button Next \
                --inputbox \
                --backtitle "$UI_TEXT" \
                "$msg\n\n\nType '$match' to continue" \
                20 69 \
                3>&1 1>&2 2>&3
                )
            [[ $? -ne 0 ]] && exit
        else
            echo -e "\e[0;31m"
            echo -n "Type '$match' to continue, or CTRL-C to exit:  "
            echo -e "\e[0m"
            read -p '> ' response
        fi

        if [[ "$response" != "$match" ]] ; then

            if [[ "$INSTALLER_MENU" == "1" ]] ; then
                ui::Say "ERROR: invalid response '$response'"
            else
                echo "ERROR: invalid response '$response'"
            fi

        fi
    done

    INSTALLER_ACCEPT=1
}


SyncInternals ()  # TODO use in MenuOpen ?
{
# DOC Sets the following globals:
# HOME
# UEFI_DEVICE
# BOOT_DEVICE
# SWAP_DEVICE
# POOL_DEVICE
# POOL_PARTITION
# LUKS_KEY
# BOOTCLONE_TYPE

    HOME="/home/$USER_USERNAME"

    # UEFI_DEVICE
       [[ $( str::GetWordCount $UEFI_PARTITION ) -gt 1 ]] \
    && UEFI_DEVICE=$UEFI_MD \
    || UEFI_DEVICE=$UEFI_PARTITION

    # BOOT_DEVICE
    if str::InList CRYPTO_BOOT $STORAGE_OPTIONS ; then
        BOOT_DEVICE=/dev/mapper/$LUKS_BOOT_NAME
    else
           [[ $( str::GetWordCount $BOOT_PARTITION ) -gt 1 ]] \
        && BOOT_DEVICE=$BOOT_MD \
        || BOOT_DEVICE=$BOOT_PARTITION
    fi

    # SWAP_DEVICE
    if str::InList CRYPTO_ROOT $STORAGE_OPTIONS ; then
        SWAP_DEVICE=/dev/mapper/$LUKS_SWAP_NAME
    else
           [[ $( str::GetWordCount $SWAP_PARTITION ) -gt 1 ]] \
        && SWAP_DEVICE=$SWAP_MD \
        || SWAP_DEVICE=$SWAP_PARTITION
    fi

    # POOL_PARTITION
    if [[ -n "$POOL_TOPOLOGY" ]] ; then # FIX MenuOpen
        POOL_PARTITION=$( FilterPoolTopology $POOL_TOPOLOGY )
    fi

    # POOL_DEVICE
    local poolCount=$( str::GetWordCount $POOL_PARTITION )
    if str::InList CRYPTO_ROOT $STORAGE_OPTIONS && str::InList ZFS $STORAGE_OPTIONS ; then
        POOL_DEVICE=
        local suffix idx=0
        for partition in $PARTITION_POOL ; do
            [[ $poolCount -gt 1 ]] && suffix="-$idx"
            ((idx++))
            POOL_DEVICE="$POOL_DEVICE /dev/mapper/$LUKS_POOL_NAME$suffix"
        done
    elif str::InList CRYPTO_ROOT $STORAGE_OPTIONS ; then
        POOL_DEVICE=/dev/mapper/$LUKS_POOL_NAME
    elif str::InList ZFS $STORAGE_OPTIONS ; then
        POOL_DEVICE=$POOL_PARTITION
    elif [[ $poolCount -gt 1 ]] ; then
        POOL_DEVICE=$POOL_MD
    else
        POOL_DEVICE=$POOL_PARTITION
    fi

    # LUKS_KEY & BOOTCLONE_TYPE
    if ! str::InList BOOTCLONE $STORAGE_OPTIONS ; then
        LUKS_KEY=/boot/luks/key
    else
        LUKS_KEY=$BOOTCLONE_MNTP/luks/key

        if      [[ -n "$BOOT_PARTITION" ]] \
        && {  ! str::InList CRYPTO_ROOT  $STORAGE_OPTIONS \
           ||   str::InList CRYPTO_BOOT  $STORAGE_OPTIONS \
           ||   str::InList PLAIN_BOOT   $STORAGE_OPTIONS
           }
        then
            BOOTCLONE_TYPE=ext
        else
            BOOTCLONE_TYPE=zfs
        fi
    fi
}


GetMdTopologyLevel () # $*:TOPOLOGY
{
    [[ "$1" =~ \  ]] && { echo -n $( GetMdTopologyLevel $* ) ; return ; }
    [[ "$1" =~ ($MD_TOPOLOGY_WORDS) ]] && echo -n $1
}


FilterPoolTopology () # $*:WORDS
{
    local buf

    # ZFS topology syntax: remove any reserved words
    if str::InList ZFS $STORAGE_OPTIONS ; then
        buf=$( sed -E "s#($ZFS_TOPOLOGY_WORDS)##g" <<<"$*" )
        echo $buf
        return
    fi

    # MD-RAID topology syntax: remove first reserved word
    buf=$( sed -E "s#^($MD_TOPOLOGY_WORDS)##" <<<"$*" )
    echo $buf
}


CheckConfigDeploy ()
{
    # Check mandatory
    local checkVars="USER_PASSWORD"

       [[ "$INSTALL_MODE" == "MenuInstall" ]] \
    && str::InList CRYPTO_ROOT $STORAGE_OPTIONS \
    && checkVars="$checkVars LUKS_PASSWORD"

    for var in $checkVars ; do
       [[ -z "$( eval echo \$$var )" ]] && sys::Die "Empty required configuration directive: $var"
    done
}


CheckConfig ()
{

    # Check mandatory
    local checkVars=$CORE_MANDATORY

    # UNUSED
    #    [[ "$INSTALL_MODE" == "MenuInstall" ]] \
    # && str::InList CRYPTO_ROOT $STORAGE_OPTIONS \
    # && checkVars="$checkVars LUKS_PASSWORD"

       str::InList ZFS  $STORAGE_OPTIONS \
    && checkVars="$checkVars ZFS_POOL_NAME ZFS_ROOT_DSET"

       str::InList CRYPTO_BOOT $STORAGE_OPTIONS \
    || str::InList PLAIN_BOOT  $STORAGE_OPTIONS \
    && checkVars="$checkVars BOOT_PARTITION"

       str::InList UEFI $STORAGE_OPTIONS \
    && checkVars="$checkVars UEFI_PARTITION"

         str::InList SSH_UNLOCK $STORAGE_OPTIONS \
    && checkVars="$checkVars IRFS_IP"

    for var in $checkVars ; do
       [[ -z "$( eval echo \$$var )" ]] && sys::Die "Empty required configuration directive: $var"
    done


    ## TODO MORE Checks & input values consistency

    # Check STORAGE_OPTIONS
    for option in $STORAGE_OPTIONS; do
        case $option in
            UEFI|APPLE|ZFS|BOOTCLONE|CRYPTO_ROOT|RANDOM|CRYPTO_BOOT|PLAIN_BOOT|SSH_UNLOCK) ;; # UNUSED |SANOID|MANDOS
            *) sys::Die "Invalid STORAGE_OPTIONS option: $option" ;;
        esac
    done

       str::InList CRYPTO_BOOT $STORAGE_OPTIONS \
    && str::InList PLAIN_BOOT  $STORAGE_OPTIONS \
    && sys::Die "CRYPTO_BOOT and PLAIN_BOOT are mutually exclusive"

    # Check encrypted system BOOT_PARTITION type
       [[ -n "$BOOT_PARTITION" ]]                 \
    &&   str::InList CRYPTO_ROOT $STORAGE_OPTIONS \
    && ! str::InList CRYPTO_BOOT $STORAGE_OPTIONS \
    && ! str::InList PLAIN_BOOT  $STORAGE_OPTIONS \
    && sys::Die "Missing encrypted boot type, either CRYPTO_BOOT or PLAIN_BOOT is required in STORAGE_OPTIONS"

    # Check SWAP_PARTITION derivation limit
         [[ -n "$SWAP_PARTITION" ]]                         \
    &&   str::InList CRYPTO_ROOT $STORAGE_OPTIONS           \
    && ! str::InList CRYPTO_BOOT $STORAGE_OPTIONS           \
    &&   str::InList ZFS $STORAGE_OPTIONS                   \
    &&   [[ $( str::GetWordCount $POOL_PARTITION ) -gt 7 ]] \
    &&   sys::Die "Too many pool devices to derive swap from (max 7), try CRYPTO_BOOT"

    # Check existing devices
    for device in       \
        $BOOT_PARTITION \
        $SWAP_PARTITION \
        $UEFI_PARTITION \
        $GRUB_DEVICE    \
        $( FilterPoolTopology $POOL_TOPOLOGY )
    do
        [[ -b "$device" ]] || sys::Die "ERROR: Unknown device $device"
    done

    # Check devices type: $POOL_TOPOLOGY
    for device in \
        $BOOT_PARTITION \
        $SWAP_PARTITION \
        $UEFI_PARTITION ; do
           fs::isDeviceType partition $device \
        || sys::Die "ERROR: Invalid device type for $device, should be partition"
    done

    # Check devices type: $POOL_TOPOLOGY
    if ! str::InList ZFS         $STORAGE_OPTIONS \
    ||   str::InList CRYPTO_ROOT $STORAGE_OPTIONS \
    || [[ -z "$BOOT_PARTITION" ]] ; then

        for device in $( FilterPoolTopology $POOL_TOPOLOGY ) ; do
               fs::isDeviceType partition $device \
            || sys::Die "ERROR: Invalid device type for $device, should be partition"
        done

    fi


    # TODO Check device sizes for pool>900M & boot>100M ?

    # Check IRFS_IP
         str::InList SSH_UNLOCK $STORAGE_OPTIONS \
    && ! str::InList                             \
            $( cut -d: -f6 <<<"$IRFS_IP" ) \
            $( GetNetworkDeviceList --ethernet ) \
    &&   sys::Die "SSH_UNLOCK: Unknown ethernet device: $( cut -d: -f6 <<<"$IRFS_IP" )"

}


Deploy ()
{
    CheckConfig
    CheckConfigDeploy

    SyncInternals

       [[ "$( type -t CheckAdditional 2>/dev/null )" == "function" ]] \
    && CheckAdditional

       [[ "$( type -t SyncAdditional 2>/dev/null )" == "function" ]] \
    && SyncAdditional


    [[ "$INSTALL_MODE" == "MenuInstall" ]] && Accept

    net::Check

    sys::Msg "Active configuration:"
    sys::GetVarsDefinitions $CORE_PREF $AUTO_PREF
    echo

    export LANG="en_US.UTF-8"

    # Logfile
    logOutputFile="./${HOST_HOSTNAME}_$(date +%Y%m%d%H%M%S).$PRODUCT_NAME.install.log"
    sys::LogOutput

    # Logs
    export DEBUG_ACTIVE=1
    set -x

    # Disable unattended-upgrade
    systemctl stop apt-daily.timer
    systemctl stop apt-daily.service
    killall unattended-upgrade 2>/dev/null && dpkg --configure -a

    # DEPS: curl
    add-apt-repository universe
    sys::Chk
    apt::Update
    apt::AddPackages curl # patch

    str::InList ZFS $STORAGE_OPTIONS && zfs::Install

    case $INSTALL_MODE in

        MenuExtend)
            CreateZfsRoot
            MountZfsRoot
            ;;

        MenuInstall)
            FormatUefi
            FormatBoot
            FormatPool
            FormatSwap
            ;;
        *)
            sys::Die "Internal Error, INSTALL_MODE=$INSTALL_MODE"
    esac

    Installer
    sys::Msg "Installation complete"

    # Logfile: close & clean
    sys::UnLogOutput
    sys::SedInline 's/^.*\r[^$]//g' "$logOutputFile"


    # Inspect
    local endText=Reboot
    [[ "$INSTALL_MODE" != "MenuInstall" ]] && endText=Exit

    while ! ui::Bool "Installation complete" "$endText" "Inspect" ; do
        chroot $TARGET
        rm -rf \
            $TARGET/$HOME/.bash_history \
            $TARGET/$HOME/.viminfo
    done

    # DEV: ABSOLUTELY required for ZFS 1st boot
    CloseAll

    # Reboot
    if [[ "$INSTALL_MODE" == "MenuInstall" ]] ; then
        # read -p "ENTER TO REBOOT" # DEBUG
        
        # BUG trusty LiveCD seems to mess something while gracefully rebooting or shutting down
        # https://bugs.launchpad.net/ubuntu/+source/casper/+bug/1447038
        # WORKAROUND reboot using sysrq
        sys::HardwareReset
    fi

}


CloseAll ()
{

    # kill hanging PIDs
    local pidList=$( lsof | awk -v p="$TARGET" 'match($NF, "^" p) {print $2}' | sort -u )
    if [[ -n "$pidList" ]] ; then
        ps -p $pidList # DEBUG
        while kill $pidList 2>/dev/null ; do sleep 1 ; done # DEV kill returns true if at least one pid was alive
    fi

    UnmountChroot

    # DEV: ABSOLUTELY required for ZFS 1st boot
    if str::InList ZFS $STORAGE_OPTIONS ; then

        zfs inherit -r mountpoint $ZFS_POOL_NAME/$ZFS_ROOT_DSET/{home,var}
        sys::Chk

        if [[ -n "$ZFS_DATA_DSET" ]] ; then

            # zfs unmount "$ZFS_POOL_NAME/$ZFS_DATA_DSET"
            zfs set mountpoint=/$( basename $ZFS_DATA_DSET ) "$ZFS_POOL_NAME/$ZFS_DATA_DSET"
            sys::Chk

            if [[ "$INSTALL_MODE" == "MenuExtend" ]] ; then
                zfs inherit mountpoint "$ZFS_POOL_NAME/$ZFS_DATA_DSET/$USER_USERNAME"
                sys::Chk
            fi

        fi

        zfs get -t filesystem mountpoint # DEBUG
    fi

    CloseBoot
    ClosePool
    CloseSwap
}
