########
# FUNC #  UI BASE
########


ui::Bool () # $1:TEXT $2:DEFAULT $3:ALT
{
    whiptail --yes-button "$2" --no-button "$3" --yesno --backtitle "$UI_TEXT" "$1" 10 64 3>&1 1>&2 2>&3
}

ui::Say () # $1:TEXT
{
    whiptail $UI_OPTS --msgbox --backtitle "$UI_TEXT" "$*" 10 64 3>&1 1>&2 2>&3 </dev/fd/0
}

# DEV: no scrolling
ui::Text () # $1:TEXT
{
    whiptail $UI_OPTS --textbox  --backtitle "$UI_TEXT" /dev/fd/0 32 74 3>&1 1>&2 2>&3 <<<"$1"
}

ui::Required () # $1:UI_CMD $*:ARGS
{
    local ret

    while [[ -z "$ret" ]] ; do
        ret=$( "$@" )
        [[ -z "$ret" ]] && ui::Say "Input is required, please retry"
    done

    echo "$ret"
}

ui::Ask () # $1:TEXT $2:DEFAULT
{
    whiptail $UI_OPTS --inputbox --backtitle "$UI_TEXT" "$1" 10 64 -- "$2" 3>&1 1>&2 2>&3
}

ui::AskSanitized () # $1:TEXT [ $2:DEFAULT ] [ $3:MORE_ALLOWED_CHARS ]
{
    local ret=$( ui::Ask "$1" "$2" ) cleaned
    cleaned=$( str::SanitizeStringAllow "$3" "$ret" )

    while [[ "$cleaned" != "$ret" ]] ; do
        ret=$( ui::Ask "[AUTOFIX] $1" "$cleaned" )
        cleaned=$( str::SanitizeStringAllow "$3" "$ret" )
    done

    echo "$ret"
}

ui::AskPassword () # $1:TEXT $2:DEFAULT
{
    whiptail $UI_OPTS --passwordbox --backtitle "$UI_TEXT" "$1" 10 32 -- "$2" 3>&1 1>&2 2>&3
}

ui::AskPasswordTwice () # $1:TEXT $2:DEFAULT
{
    local temppass1=init temppass2 default=$2

    while [[ "$temppass1" != "$temppass2" ]] ; do

        while true; do
            temppass1=$( ui::AskPassword "$1" "$2" )
            [[ -n "$2" ]] && [[ "$temppass1" != "$2" ]] && default=
            [[ -z "$temppass1" ]] && ui::Say "Empty password, please retry" || break
        done

        temppass2=$( ui::AskPassword "Please confirm password" "$default" )
        [[ "$temppass1" != "$temppass2" ]] && ui::Say "Password mismatch, please retry"

    done

    echo -n "$temppass1"
}

ui::Menu () # [ '--noitem' ] $1:TEXT $2:DEFAULT $*:KEY+ITEM
{
    local noitem
    [[ "$1" == "--noitem" ]] && { noitem="--noitem" ; shift ; }
    local text=$1 ; shift
    local default=$1 ; shift
    [[ $(( ${#@} % 2 )) != 0 ]] && return 1

    whiptail $UI_OPTS \
        --default-item="$default" \
        $noitem --menu \
        --backtitle "$UI_TEXT" \
        "$text" 20 64 10 "$@" 3>&1 1>&2 2>&3
}

ui::SelectList () # [ '--noitem' ] $1:TEXT $*:KEY+ITEM+STATUS
{
    local noitem
    [[ "$1" == "--noitem" ]] && { noitem="--noitem" ; shift ; }
    local text=$1 ; shift
    [[ $(( ${#@} % 3 )) != 0 ]] && return 1

    local ret=$(
        whiptail $UI_OPTS \
            $noitem --separate-output --checklist \
            --backtitle "$UI_TEXT" \
            "$text" 20 64 13 "$@" 3>&1 1>&2 2>&3
    )

    echo $ret
}

ui::PickList () # [ '--noitem' ] $1:TEXT $*:KEY+ITEM+STATUS
{
    local noitem
    [[ "$1" == "--noitem" ]] && { noitem="--noitem" ; shift ; }
    local text=$1 ; shift
    [[ $(( ${#@} % 3 )) != 0 ]] && return 1

    whiptail $UI_OPTS \
        $noitem --radiolist \
        --backtitle "$UI_TEXT" \
        "$text" 20 64 13 "$@" 3>&1 1>&2 2>&3
}
