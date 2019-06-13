########
# FUNC #  FS
########


fs::GetDisksPartitions () # $1:DEVICE
{
    local str=$(
        for dev in $* ; do

            fs::isDeviceType disk $dev || return

              lsblk -lno KNAME $dev -x KNAME \
            | awk 'NR!=1'

        done
    )
    echo $str
}

fs::isDeviceType () # $1:TYPE $2:DEVICE
{
    local deviceType=$( udevadm info --query=property $2 2>/dev/null | awk -F"=" '$1=="DEVTYPE" {print $2}' )

    [[ "$deviceType" == "$1" ]]
}

fs::GetDeviceDisk () # $1:PARTITION
{
    if fs::isDeviceType partition $1 ; then

        local disk=$( basename $( dirname $( udevadm info --query=property --name=$1 2>/dev/null | grep ^DEVPATH= ) 2>/dev/null ) 2>/dev/null )

        [[ -b /dev/$disk ]] && echo /dev/$disk

    elif fs::isDeviceType disk $1 ; then

        echo $1

    fi
}

fs::GetDeviceId () # $1:PARTITION
{
    find -L /dev/disk/by-id/ -samefile "$1"
}

fs::GetPartitionType () # $1:DEVICE
{
       fs::isDeviceType partition $1 \
    || return

      sgdisk -p $( fs::GetDeviceDisk $1 ) \
    | awk -v n=$( fs::GetPartitionNumber $1 ) '$1==n{print $6}'

}

fs::GetPartitionNumber () # $1:DEVICE
{
       fs::isDeviceType partition $1 \
    || return

    # ALT sed -E 's/^.*[^0-9]([0-9]+)/\1/' <<<$1

    local n=$( lsblk -lno MAJ:MIN "$1" | awk -F: '{print $2}' )
    echo $n
}

fs::GetPartitionUuid () # $1:DEVICE
{
    blkid $1 -s UUID -o value
}

fs::GetPartitionFormat () # $1:DEVICE
{
       fs::isDeviceType partition $1 \
    || return

    lsblk -lno FSTYPE $1
}


fs::RandomizeDevices () # $*:devices
{

    if ! grep -E -q '^deb.* universe( .*)?$' /etc/apt/sources.list ; then
        add-apt-repository universe
        sys::Chk
        apt::Update
    fi

    apt::AddPackages pv

    for device in $*; do

        [[ -b "$device" ]]
        sys::Chk

        local tmpDev=crypto-temp tmpKey=$( dd 'if=/dev/urandom' of=/dev/stdout bs=1 count=512 2>/dev/null )

        echo -n "$tmpKey" | cryptsetup -v luksFormat $1 $LUKS_FORMAT_OPTS
        sys::Chk
        echo -n "$tmpKey" | cryptsetup -v luksOpen $1 $tmpDev
        sys::Chk

          dd 'if=/dev/zero' bs=64K \
        | pv  --buffer-size=64k --progress --timer --eta --rate --name $1 --size $( blockdev --getsize64 $device ) \
        | dd of=/dev/mapper/$tmpDev bs=64K


        cryptsetup -v luksClose $tmpDev
        sys::Chk

    done
}
