########
# FUNC #  ZFS
########



zfs::Install ()
{
    {
        grep '^zfs ' /proc/modules || modprobe zfs

           grep '^zfs ' /proc/modules \
        && which zpool \
        && return
    } &>/dev/null

    if ! grep -E -q '^deb.* universe( .*)?$' /etc/apt/sources.list ; then
        add-apt-repository universe
        sys::Chk
        apt::Update
        sys::Chk
    fi

    case "$(lsb_release -cs)" in
        trusty)
            apt::AddPackages g++ libc6-dev make patch
            apt::AddPpa zfs-native/stable
            apt::AddPackages spl-dkms zfs-dkms zfsutils zfs-initramfs
            modprobe zfs
            sys::Chk

            sys::Write <<'EOF' /etc/apt/preferences.d/zfs
Package: *
Pin: release o=LP-PPA-zfs-native-stable
Pin-Priority: 1200
EOF

            dkms status # DEBUG
            ;;
        *)  apt::AddPackages zfsutils-linux zfs-initramfs ;; # zfs-zed
    esac

    # DEV: max 2GB of ram used for zfs arc
    sys::Write <<EOF /etc/modprobe.d/zfs.conf
options zfs zfs_arc_max=2147483648
EOF

    dmesg | grep ZFS: # DEBUG
    which zpool zfs   # DEBUG
}


zfs::IsDataset () # $1:ZFS_DATASET
{
    zfs::Install
    zfs list "$1" 2>/dev/null | awk -v p="$1" 'NR==1{next} $1==p {ok=1} END {exit !ok}'
}

zfs::IsDatasetUsed () # $1:ZFS_DATASET
{
    zfs::Install
    zfs get used $1 | awk 'NR==1{next} $3~/[^K]$/{ok=1} END{exit !ok}'
}

zfs::CreateDataset () # $1:PATH [$@:OPTS]
{
    { local dset=$1 ; shift ; } &>/dev/null

    zfs::Install

       zfs list -t filesystem "$dset" &>/dev/null \
    && return

    zfs create -o xattr=sa "$@" -p "$dset"
    sys::Chk
}

zfs::CreateSnapshot () # $1:DSET $2:SNAP_NAME
{
    zfs::Install

    zfs snapshot -r "$1@$2"
    sys::Chk
}

# BUG: spaces in filenames
# BUG: hardcoded pool/root/gnos/home
zfs::GetFileSnapshots () # $1:PATTERN
{
    [[ $# -eq 1 ]] || { echo "USAGE: $FUNCNAME FILE_PATTERN">&2 ; return; }
    which gawk &>/dev/null || { echo "ERROR: Missing gawk">&2 ; return; }

    local file=$( readlink -m "$1" )

    local path=$file
    while [[ ! -e "$path" ]] ; do
        path=$( dirname "$path" )
    done

    local dset=$( zfs list -H -o name "$path" )
    [[ -n "$dset" ]] || return

    local mntp=$( zfs get mountpoint -H -o value "$dset" )
    [[ "$mntp" == "/" ]] && mntp=""
    [[ "$mntp" == "none" ]] && mntp="$( awk -v m=pool/root/gnos/home '$1==m{print $2; exit}' /proc/mounts )"

    local cand
      find $mntp/.zfs/snapshot -mindepth 1 -maxdepth 1 -print0 \
    | while IFS= read -r -d $'\0' snap || [[ -n $snap ]] ; do
        cand="$snap${file#$mntp}"
           eval ls "$cand" &>/dev/null \
        && sudo zfs list -H -r -t snapshot -o name,creation \
            "$dset@${snap#$mntp/.zfs/snapshot/}"
      done \
    | gawk -F $'\t' -v mntp="$mntp" -v file="${file#$mntp}" '
        BEGIN { # DEV: Populate months array
            m=split("Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec",d,"|")
            for(o=1;o<=m;o++) {  months[d[o]]=sprintf("%02d",o)  }
        }
        {
            snap=substr($1, index($1, "@")+1 )

            $1=""
            ds=substr($0, 2)
            sub(/ +/, " ", ds)
            split(ds, da, " ")
            split(da[4], time, ":")
            date = ( da[5] " " months[ da[2] ] " " da[3] " " time[1] " " time[2] " 0" )

            cmd="bash -c \"eval ls -a \\\"" mntp "/.zfs/snapshot/" snap file "\\\" | while IFS=\\$'"'\\\n'"' read -r i || [[ -n \\$i ]] ; do printf \\\"%s\\n\\\" \\\"\\$i\\\" ; done \" "
            # cmd="sh -c \"for i in " mntp "/.zfs/snapshot/" snap file " ; do printf \\\"%s\\n\\\" \\\"\\$i\\\" ; done \" "

            while ( cmd | getline )
            {
                print strftime( "%Y-%m-%d %H:%M", mktime(date) ), $0
            }
            # print "DBG",cmd
        }' \
    | sort
}
