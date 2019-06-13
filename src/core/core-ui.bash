########
# FUNC #  UI STORAGE
########


GetDevicesOptionList () # $1:"DISK"|"PART"|"ANY" [$1:DEFAULT] [$2:EXCLUDE]
{
    case $1 in
        DISK|PART|ANY)  ;;
        *)              return
    esac

      lsblk -lno TYPE,KNAME,SIZE -x KNAME \
    | awk -v mode="$1" -v default="$2" -v exclude="$3" '
BEGIN {
    default_count=split(default,default_array," ")
    exclude_count=split(exclude,exclude_array," ")
}
$1!="disk" && $1!="part" { next }
($1=="disk") || ($1=="part") {

    device="/dev/"$2
    size=$3

    for (i = 1; i <= exclude_count; i++) if (device==exclude_array[i]) next

    status="off" ; type="" ; label=""
    for (i = 1; i <= default_count; i++) if (device==default_array[i]) status="on"
}
($1=="disk") && (mode!="PART") {

    ( "blkid "device" -s TYPE  -o value" ) | getline type

    ( "parted "device" --script -- print | awk \"/^Model:/ {\$1=null ; \$0=\$0 ; print substr(\$0,2) } \"" ) | getline model

    printf "%s \"%-33s %-5s\" %s ", device, model, size, status # DOC: whiptail list format: [ tag item status ]
}
($1=="part") && (mode!="DISK") {

    ( "blkid "device" -s TYPE  -o value" ) | getline type
    ( "blkid "device" -s LABEL -o value" ) | getline label

    printf "%s \"%-16s %-16s %-5s\" %s ", device, type, label, size, status # DOC: whiptail list format: [ tag item status ]
}'
}

# UNUSED
UiPickStorageDevice () # $1:TEXT [$2:DEFAULT] [$3:EXCLUDE]
{
    local options cmd options=$( GetDevicesOptionList ANY "$2" "$3" )

    cmd="$UI_OPTS --separate-output --radiolist --backtitle \"$UI_TEXT\" \"$1\" 20 64 13 $options"

    ret=$( echo "$cmd" | xargs whiptail 3>&1 1>&2 2>&3 )
    echo $ret
}


UiSelectStoragePartition () # $1:TEXT [$2:DEFAULT] [$3:EXCLUDE]
{
    local ret cmd options=$( GetDevicesOptionList PART "$2" "$3" )

    cmd="$UI_OPTS --separate-output --checklist --backtitle \"$UI_TEXT\" \"$1\" 20 64 13 $options"

    ret=$( echo "$cmd" | xargs whiptail 3>&1 1>&2 2>&3 )
    echo $ret
}


# UNUSED
UiPickStoragePartition () # $1:TEXT [$2:DEFAULT] [$3:EXCLUDE]
{
    local ret cmd options=$( GetDevicesOptionList PART "$2" "$3" )

    cmd="$UI_OPTS --separate-output --radiolist --backtitle \"$UI_TEXT\" \"$1\" 20 64 13 $options"

    ret=$( echo "$cmd" | xargs whiptail 3>&1 1>&2 2>&3 )
    echo $ret
}


UiSelectStorageDevice () # $1:TEXT [$2:DEFAULT] [$3:EXCLUDE]
{
    local ret cmd options=$( GetDevicesOptionList ANY "$2" "$3" )

    cmd="$UI_OPTS --separate-output --checklist --backtitle \"$UI_TEXT\" \"$1\" 20 64 13 $options"

    ret=$( echo "$cmd" | xargs whiptail 3>&1 1>&2 2>&3 )
    echo $ret
}


GetGrubOptionList () # [$1:DEFAULT] [$2:EXCLUDE]
{
    local gptExclude
    for disk in $( lsblk -lno TYPE,KNAME -x KNAME | awk '$1=="disk"{print $2}' ) ; do

        partedOutput=$( parted /dev/$disk --script -- print  )

        # Exclude BIOS Boot partitions, as grub wants the disk name instead
        gptExclude="$gptExclude "$( awk -v disk=/dev/$disk '$NF=="bios_grub" {print disk $1}' <<<"$partedOutput" )

        # Exclude gpt labels without BIOS Boot partition
             grep -q '^Partition Table: gpt' <<<"$partedOutput" \
        && ! grep -q 'bios_grub$'            <<<"$partedOutput" \
        && gptExclude="$gptExclude "/dev/$disk

    done
    gptExclude=$( echo $gptExclude $2 )

    GetDevicesOptionList ANY "$1" "$gptExclude"
}


UiSelectStorageGrub () # $1:TEXT [$2:DEFAULT] [$3:EXCLUDE]
{
    local ret cmd options=$( GetGrubOptionList "$2" "$3")

    cmd="$UI_OPTS --separate-output --checklist --backtitle \"$UI_TEXT\" \"$1\" 20 64 13 $options"

    ret=$( echo "$cmd" | xargs whiptail 3>&1 1>&2 2>&3 )
    echo $ret
}




########
# FUNC #  UI KEYBOARD
########



UiPickKeyboardModel () # $1:TEXT [$2:DEFAULT]
{
    local options cmd

    options=$(
          /usr/share/console-setup/kbdnames-maker /usr/share/console-setup/KeyboardNames.pl \
        | sort \
        | awk -F\* -v default=$2 '
            $2=="model" {
                status="off"
                if ($3==default) status="on"
                printf $3 " \"" substr($4, 1, 24) "\" " status " " # DOC: whiptail list format: [ tag item status ]
            }'
    )

    cmd="$UI_OPTS --radiolist --backtitle \"$UI_TEXT\" \"$1\" 20 64 13 $options"
    echo "$cmd" | xargs whiptail 3>&1 1>&2 2>&3
}

UiPickKeyboardLayout () # $1:TEXT [$2:DEFAULT]
{
    local options cmd

    options=$(
          /usr/share/console-setup/kbdnames-maker /usr/share/console-setup/KeyboardNames.pl \
        | sort \
        | awk -F\* -v default=$2 '
            $2=="layout" {
                status="off"
                if ($3==default) status="on"
                printf $3 " \"" substr($4, 1, 24) "\" " status " " # DOC: whiptail list format: [ tag item status ]
            }'
    )

    cmd="$UI_OPTS --radiolist --backtitle \"$UI_TEXT\" \"$1\" 20 64 13 $options"
    echo "$cmd" | xargs whiptail 3>&1 1>&2 2>&3
}

UiPickKeyboardVariant () # $1:TEXT $2:LAYOUT [$3:DEFAULT]
{
    local options cmd

    options=$(
          /usr/share/console-setup/kbdnames-maker /usr/share/console-setup/KeyboardNames.pl \
        | LC_COLLATE=C sort \
        | awk -F '*' -v layout="$2" -v default="$3" '
            ($2=="variant") && ($3==layout) {
                status="off"
                if ($4==default) status="on"
                printf "\"" $4 "\"" " \"" substr($5, 1, 24) "\" " status " " # DOC: whiptail list format: [ tag item status ]
            }'
    )

    cmd="$UI_OPTS --radiolist --backtitle \"$UI_TEXT\" \"$1\" 20 64 13 $options"
    echo "$cmd" | xargs whiptail 3>&1 1>&2 2>&3
}




########
# FUNC #  UI HOST_TIMEZONE
########



ZoneinfoBrowser () # [$1:ZONEINFO_PATH]
{
    local ziPath=/usr/share/zoneinfo

    [[ -f "$ziPath/$1" ]] && { echo $1; return ; }

      find "$ziPath" -type f -printf '%P\n' \
    | awk -F/ -v p=$1 '
        BEGIN { r="^"p"/?" }
        $0~r {
            f=substr($0,1+length(p))
            pos2=match(f, "/")
            if (pos2 == 0) a[$0]=0
            else           a[substr($0, 1, pos2+length(p))]=0
        }
        END { for (i in a) print i }' \
    | LC_COLLATE=C sort
}

UiPickTimezone () # $1:TEXT $2:DEFAULT
{
    local new old d c=0
    declare -a defaults

    read -a defaults <<<"$( sed -E 's#/#/ #g' <<< "$2" )"

    while true; do
        d="$d${defaults[$c]}"
        new=$( ZoneinfoBrowser $old )
        [[ -z "$new" ]] && break
        [[ "$new" == "$old" ]] && { echo $new ; break ; }
        new=$( echo "$new" | awk '{printf $1 " " $1 " "}' ) # DOC: whiptail --noitem menu format: [ tag item ]
        old=$( echo "$UI_OPTS --default-item=$d --noitem --menu --backtitle \"$UI_TEXT\" \"$1\" 20 80 12 $new" \
             | xargs whiptail 3>&1 1>&2 2>&3 )
        ((c++))
    done
}




########
# FUNC #  UI NETWORK
########



GetNetworkDeviceList () # [ --ethernet | --wireless ]
{
    local mod
    if   [[ "$1" == "--ethernet" ]] ; then mod=' && !wirl' ;
    elif [[ "$1" == "--wireless" ]] ; then mod=' &&  wirl' ;
    fi

      lshw  -class network 2>/dev/null \
    | awk '
    $1~/^\*-/       {commit(); name="";wirl=0}
    $1=="logical"   {name=$NF}
    /wireless/      {wirl=1}
    END             {commit();}
    function commit() {if (name'"$mod"') print name}
    '
}

UiPickNetworkDevice () # [ --ethernet | --wireless ] $1:TEXT # DEV: NOT IMPLEMENTED [$2:DEFAULT]
{
    local arg
    if   [[ "$1" == "--ethernet" ]] ; then arg=$1; shift ;
    elif [[ "$1" == "--wireless" ]] ; then arg=$1; shift ;
    fi

    local ret cmd options=$( GetNetworkDeviceList $arg | awk '$NF>0{ print $0 " off" }' )

    # Single Ethernet interface
    if [[ $( str::GetWordCount ) -eq 2 ]] ; then
        echo ${options%% *}
        return
    fi

    cmd="$UI_OPTS --noitem --separate-output --radiolist --backtitle \"$UI_TEXT\" \"$1\" 20 64 13 $options"

    ret=$( echo "$cmd" | xargs whiptail 3>&1 1>&2 2>&3 )
    echo $ret
}


