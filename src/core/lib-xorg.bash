########
# FUNC #  XORG
########



xorg::GetCurrentGraphicsDriver ()
{
    X :2 -configure
    local xorgConf=/home/ubuntu/xorg.conf.new # DEV: callable from livecd
    [[ -f "$xorgConf" ]] || xorgConf=$HOME    # DEV: callable from chroot
    [[ -f "$xorgConf" ]] || return
    awk '/^Section "Device"/{s=1} (s==1)&&($1=="Driver") { print substr($2,2,length($2)-2); exit}' \
        $xorgConf \
    rm $xorgConf
}

xorg::GetCurrentKeyboardProperty () # $1:"model|layout|variant"
{
      setxkbmap -query 2>/dev/null \
    | awk -v p=$1 '$1==p":"{
        i=index($2,",")
        if (i==0) i=length($2)+1
        print substr($2,1,i-1)
    }'
}

xorg::GetAllKeyboardProperty () # $1:"model|layout|variant"
{
      setxkbmap -query 2>/dev/null \
    | awk -v p=$1 '$1==p":"{print $2}'
}

xorg::SwitchKeyboardUs ()
{
    BACKUP_KEYBOARD_LAYOUT=$( xorg::GetAllKeyboardProperty layout )
    BACKUP_KEYBOARD_VARIANT=$( xorg::GetAllKeyboardProperty variant )
    setxkbmap us
}

xorg::SwitchKeyboardBack ()
{
    setxkbmap $BACKUP_KEYBOARD_LAYOUT $BACKUP_KEYBOARD_VARIANT
}
