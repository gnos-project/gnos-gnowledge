########
# FUNC #  SYS
########


## FD MAP: sys::LogOutput sys::UnLogOutput
# use fd 3 as stdout backup
# use fd 4 as stderr backup

## FD MAP: sys::_Die & sys::Dbg
# use fd 5 as msg input
exec 7>&0 # use fd 7 as stdin  backup
exec 8>&1 # use fd 8 as stdout backup
exec 9>&2 # use fd 9 as stderr backup


## MACROS
# DEV: aliases MUST be defined before calling functions
shopt -s expand_aliases
alias 'sys::Chk={ sys::_Chk || return 1 ; }'
alias 'sys::Die={ sys::_Die || return 1 ; } 5<<<'



# DEV: 3-level BASH_COMMAND history for sys::_Chk
set -o functrace
trap '{ CommandHistory; } 2>/dev/null' DEBUG
CommandHistory ()
{
    {
        DEBUG_HIST3="$DEBUG_HIST2"
        DEBUG_HIST2="$DEBUG_HIST1"
        DEBUG_HIST1="$DEBUG_HIST0"
        DEBUG_HIST0="$BASH_COMMAND"
    } 2>/dev/null
}


sys::_Chk () # [$*:ERROR_TEXT]
{
    {
        local ret=$? cmd="$DEBUG_HIST3" xtrace
        if [[ $- =~ x ]] ; then
            set +x
            xtrace=1
        fi
    } 2>/dev/null

    # DEV: Read OPTIONAL message from fd 5
    local msg
    while IFS= read -r -t 0.1 m 2>/dev/null <&5 || [[ -n "$m" ]] ; do [[ -n "$m" ]] && msg="$msg$m" ; done

    if [[ $ret -ne 0 ]] ; then
        sys::_Die 5<<<"${*+$*\n\n}${cmd+Command:  $cmd\n}Return:   $ret${msg+\nMessage:  $msg}"
        ret=$?
    fi

    # xtrace on
    {
        [[ -n "$xtrace" ]] && set -x
        return $ret
    } 2>/dev/null
}


sys::_Die () # $1:ERROR_TEXT
{
    # xtrace off
    {
        local xtrace
        if [[ $- =~ x ]] ; then
            set +x
            xtrace=1
        fi
    } 2>/dev/null

    # Message
    local msg tips
    [[ "$BASH_SUBSHELL" != "0" ]] && tips="$tips, SUBSHELL $BASH_SUBSHELL"
    if [[ ! -t 0 && ! -t 1 ]] ; then
        tips="$tips, PIPE IN/OUT"
    elif [[ ! -t 0 ]] ; then
        tips="$tips, PIPE IN"
    elif [[ ! -t 1 ]] ; then
        tips="$tips, PIPE OUT"
    fi
    msg="RUNTIME ERROR$tips\n─────────────"

    # DEV: Read MANDATORY message from fd 5
    while IFS= read -r -t 0.1 m 2>/dev/null <&5 || [[ -n "$m" ]]; do [[ -n "$m" ]] && msg="$msg\n$m" ; done
    # [[ -n "$*" ]] && msg="${msg}: $*"

    sys::Msg --color "1;31" "$msg"

    # Debug
    [[ "$DEBUG_ACTIVE" == "1" ]] || exit 1

    # Stacktrace
    sys::Msg "Stacktrace"
    local frame=0
      while caller $frame; do ((frame++)); done \
    | awk 'BEGIN{print "FUNC FILE:LINE"; print "──── ─────────"} {print $2, $3":"$1}' \
    | tr -cd '[:print:]\n' \
    | column -t >&9

    # Code Context
    sys::Msg "Code Context"
    local stair=0;
    case $( caller 0 | awk '{print $2}') in
        sys::_Chk)   stair=1;;
    esac
    local file=$( caller $stair | awk '{print $3}' )
    local line=$( caller $stair | awk '{print $1}' )
    local head=$((line -5))
      sed -n $head,+9p "$file" \
    | awk -v l=$head -v m=$line >&9 \
        'l==m{printf "\033[1;36m"} l==m+1{printf "\033[0m"} { printf("%.5s: ",l); print; l=l+1}'


    # Debug
    [[ "$DEBUG_INTERACTIVE" != "0" ]] || exit 1

    # Debug
    sys::Dbg
    ret=$?

    # xtrace on
    {
        # [[ $ret -eq 2 ]] && exit 2
        [[ -n "$xtrace" ]] && set -x
        return $ret
    } 2>/dev/null
}


sys::Dbg ()
{
    # xtrace off
    {
        local xtrace
        if [[ $- =~ x ]] ; then
            set +x
            xtrace=1
        fi
    } 2>/dev/null

    sys::UnLogOutput

    local cmd sub
    [[ -t 1 && -t 0 ]] || sub=1

    while true ; do

        sys::Msg --color "1;33" \
            "DEBUG Commands:

[s]hell   Fix or workaround issue in console
[i]gnore  Continue execution flow
[r]eturn  Break execution flow" \
"$( [[ -z "$sub" ]] && echo -e "\n[q]uit    Exit installer" )" >&9

        read -p "DEBUG command [s] > " cmd <&7

        case $cmd in
            s|shell|'') # default
                sys::Msg "DEBUG Shell: Try to fix the issue, then \`exit\`"
                if [[ -f "$HOME/.bashrc" ]] ; then
                    bash --rcfile "$HOME/.bashrc" <&7 >&9 2>&9
                else
                    bash <&7 >&9 2>&9
                fi
                sys::Msg "DEBUG Shell: Back, what do we do now ?"
                ;;
            i|ignore)
                sys::Msg "DEBUG Returning 0 ..."
                sys::LogOutput
                {
                    [[ -n "$xtrace" ]] && set -x # xtrace on
                    return 0
                } 2>/dev/null
                ;;
            r|return)
                sys::Msg "DEBUG Returning 1 ..."
                sys::LogOutput
                {
                    [[ -n "$xtrace" ]] && set -x # xtrace on
                    return 1
                } 2>/dev/null
                ;;
            q|quit)
                if [[ -n "$sub" ]] ; then
                    echo "DEBUG Invalid command: $*"
                else
                    sys::Msg "DEBUG Exiting ..."
                    # return 2
                    exit 2
                fi
                ;;
            *)
                echo "DEBUG Invalid command: $*"
        esac
    done
}


sys::Msg () # [--color CODE] [$*:TEXT]
{
    # xtrace
    {
        local xtrace
        if [[ $- =~ x ]] ; then
            set +x
            xtrace=1
        fi
    } 2>/dev/null

    local cols=$(tput cols 2>/dev/null)
    cols=${cols-80}

    local col="0;33"
    [[ "$1" == "--color" ]] && { col="$2"; shift 2; }
    local sep="$( printf '─%0.s' $( seq 1 $(( $cols -2)) ) )"
        echo -e "\n\e[${col}m┌$sep┐" >&9
      echo -ne "$*" \
    | awk '{print "│ " $0}' >&9
    echo -e "└$sep┘\e[0m\n" >&9

    # xtrace
    {
        [[ -n "$xtrace" ]] && set -x
    } 2>/dev/null
}


sys::MsgPause ()
{
    {
        sys::Msg $*
        read -p "<ENTER> to continue"
    } 2>/dev/null
}


sys::LogOutput () # [ $1:FILE ]
{
    {
           [[ -z "$1" ]] \
        && [[ -z "$logOutputFile" ]] \
        && return

           [[ -n "$1" ]] \
        && logOutputFile="$1"

    } 2>/dev/null

    exec 3>&1 4>&2 &> >( tee -a "$logOutputFile" )
    logOutputPid=$!
}


sys::UnLogOutput ()
{
    {
       [[ -z "$logOutputPid" ]] && return
    } 2>/dev/null

    if kill $logOutputPid ; then
        exec 1>&3 2>&4 3>&- 4>&-
        logOutputPid=
    fi
}


sys::HardwareReset ()
{
    # DOC sysrq  http://www.mjmwired.net/kernel/Documentation/sysrq.txt
    echo s > /proc/sysrq-trigger
    echo b > /proc/sysrq-trigger
}




sys::Mkdir () # $1:DEST_DIR [ $2:OWNER [ $3:PERMS ] ]
{
    {
        local dst=$1
        [[ "${dst:0:1}" != / ]] && dst=$( readlink -m "$PWD/$dst" )

        local prev
        local dir=$( dirname "$dst" )

    } 2>/dev/null

    if [[ -d "$dst" ]] ; then
        :
    elif [[ -e "${dst%%/}" && ! -d "$dst" ]] ; then
        sys::Die "Invalid dir: $dst"
    elif [[ -e "$dir" && -d "$dir" ]] ; then
        mkdir "$dst"
        sys::Chk
        chown --preserve-root --changes --no-dereference --reference="$dir/" "$dst/"
        sys::Chk
    else

        while [[ -n "$dir" ]]  && ! [[ -e "$dir" ]] ; do
            prev="$dir"
            dir="$( dirname "$dir" )"
        done

        [[ -d "$dir" ]] || sys::Die "Invalid dir: $dir"

        mkdir -p "$dst"
        sys::Chk
        chown --preserve-root --changes --recursive --no-dereference --reference="$( dirname "$prev" )/" "$prev/"
        sys::Chk
        chmod --preserve-root --changes --recursive                  --reference="$( dirname "$prev" )/" "$prev/"
        sys::Chk

    fi

    if [[ $# -ge 2 ]] ; then
        chown --preserve-root --changes --recursive --no-dereference $2 "$dst/"
        sys::Chk
    fi

    if [[ $# -ge 3 ]] ; then
        chmod --preserve-root --changes --recursive $3 "$dst/"
        sys::Chk
    fi
}

# TODO sys::Move

sys::Copy () # [--rename] $1:SRC  $2:DST [ $3:OWNER [ $4:PERMS ] ]
{
    {
        local dst rename renameopt permstarget
        if [[ "$1" == "--rename" ]] ; then
            shift
            dst="$( dirname "$2" )/"
            rename="$( basename "$2" )"
            renameopt=--no-target-directory
            permstarget="$2"
        else
            dst="$2"
            permstarget="$dst/$( basename "$1" )"
        fi
        local src="$1"
        shift 2
    } 2>/dev/null

    if [[ ! $dst =~ /$ ]] ; then
        [[ -d "$src" ]] && sys::Die "Invalid call: use / suffix for destination dir"

        sys::Touch "$dst$rename" "$@"

        cp --verbose "$src" "$dst$rename"
        sys::Chk
    else
        sys::Mkdir "$dst$rename" # "$@"

        cp $renameopt --recursive --verbose "$src" "$dst$rename"
        sys::Chk

        if [[ $# -eq 0 ]] ; then
            chown --preserve-root --changes --recursive --no-dereference --reference="$( dirname "$permstarget" )/"  "$permstarget"
            sys::Chk
        fi
        if [[ $# -ge 1 ]] ; then
            chown --preserve-root --changes --recursive --no-dereference $1 "$permstarget"
            sys::Chk
        fi
        if [[ $# -ge 2 ]] ; then
            chmod --preserve-root --changes --recursive $2 "$permstarget"
            sys::Chk
        fi
    fi
}


sys::Touch () # $1:DEST_FILE [ $2:OWNER [ $3:PERMS ] ]
{
    {
        local dst="$1"
        local dir="$( dirname "$dst" )"
    } 2>/dev/null

    sys::Mkdir "$dir"
    touch "$dst"
    sys::Chk

    if [[ $# -eq 1 ]] ; then
        chown --preserve-root --changes --recursive --no-dereference --reference="$( dirname "$dst" )/" "$dst"
        sys::Chk
    fi
    if [[ $# -ge 2 ]] ; then
        chown --preserve-root --changes --recursive --no-dereference $2 "$dst"
        sys::Chk
    fi
    if [[ $# -ge 3 ]] ; then
        chmod --preserve-root --changes --recursive $3 "$dst"
        sys::Chk
    fi
}

sys::Write () # [ '--append' ] $1:DEST [ $2:OWNER [ $3:PERMS ] ]
{
    {
        local doAppend=0
        [[ "$1" == "--append" ]] && { doAppend=1 ; shift ; }

        local dst=$1

        [[ -n "$dst" ]] || sys::Die "Missing arguments"

    } 2>/dev/null

    sys::Touch "$@"

    if [[ $doAppend -eq 1 ]] ; then
        cat >>"$dst"
        sys::Chk
    else
        cat  >"$dst"
        sys::Chk
    fi

}

sys::PatchText () # $1:FILE
{
    apt::AddPackages patch
    local tmp=$( mktemp )
    cat >"$tmp"
    if [[ "$( awk '{print substr($0, 1, 3);exit}' "$tmp" )" == "---" ]] ; then
        local tmp2=$( mktemp )
        echo -e "--- new\n+++ old" >"$tmp2"
        cat "$tmp"  >>"$tmp2"
        cat "$tmp2"  >"$tmp"
        rm "$tmp2"
    fi

       patch --ignore-whitespace --dry-run "$1" <"$tmp" \
    || sys::Die "Failed to apply patch to: $1"

    patch --ignore-whitespace "$1" <"$tmp"
    rm "$tmp"
}

sys::PatchBinary () # $1:FILE $2:PAYLOAD $3:HEX_OFFSET
{   # SAMPLE: sys::PatchBinary my.bin '\x95' 50734
    local offset=$3
    [[ $offset =~ ^0x ]] && offset=$(( $offset )) # Hex support
    printf "$2" | dd seek=$offset conv=notrunc bs=1 of="$1"
}

sys::GetVarsDefinitions () # $*:VAR_NAME
{
      declare -p "$@" 2>/dev/null \
    | awk '/^declare -/{ $1="" ; $2="" ; $0=$0 ; print substr($0, 3)}' \
    | sort
}

sys::GetVarsNamesByRegex () # $1:REGEX
{
      declare -p \
    | grep -E "^declare -[irx-]+ " \
    | cut -d' ' -f3- \
    | cut -d'=' -f1 \
    | awk -v r="$1" 'match($0,r)'
}

sys::GetFuncsNamesByRegex () # $1:REGEX
{
      declare -f \
    | grep -E '^[^ =]+ \(\) *$' \
    | cut -d' ' -f1 \
    | awk -v r="$1" 'match($0,r)'
}

sys::Templatize () # $1:IN_FILE|- $2:OUT_FILE|- $*:VARIABLE_NAME
{
    local src dst
    [[ $1 == "-" ]] && src=/dev/fd/2 || { [[ -f "$1" ]] && src=$1 || sys::Die "Unknown source template file: $1" ; }
    [[ $2 == "-" ]] && dst=/dev/fd/0 || dst=$2
    shift 2

    local defNames=$( sed -E 's/\s+/,$/g' <<<"$*" )
    [[ -n "$defNames" ]] && defNames="\$$defNames"

    (   # DEV: Subshell for exporting
        for name in $*; do export $name; done
        envsubst $defNames <"$src" >"$dst"
    )
    sys::Chk
}

sys::TemplatizeByRegex () # $1:IN_FILE|- $2:OUT_FILE|- $3:REGEX
{
    sys::Templatize "$1" "$2" $( sys::GetVarsNamesByRegex "$3" )
}

# DOC: sed command "cheat-sheet"
# :  # label
# =  # line_number
# a  # append_text_to_stdout_after_flush
# b  # branch_unconditional
# c  # range_change
# d  # pattern_delete_top/cycle
# D  # pattern_ltrunc(line+nl)_top/cycle
# g  # pattern=hold
# G  # pattern+=nl+hold
# h  # hold=pattern
# H  # hold+=nl+pattern
# i  # insert_text_to_stdout_now
# l  # pattern_list
# n  # pattern_flush=nextline_continue
# N  # pattern+=nl+nextline
# p  # pattern_print
# P  # pattern_first_line_print
# q  # flush_quit
# r  # append_file_to_stdout_after_flush
# s  # substitute
# t  # branch_on_substitute
# w  # append_pattern_to_file_now
# x  # swap_pattern_and_hold
# y  # transform_chars


sys::Sed () # $1:CMD $2:SRC [DST] [OPTS] ...
{
    local cmd="$1" src="$2"
    shift 2

    [[ -f "$src" ]] || sys::Die "Unknown source file: $src"

    local dst
    if [[ $# -ge 1 ]] && [[ ! $1 =~ ^- ]]; then
        dst="$1"
        shift
        [[ -n "$dst" && ! -f "$dst" ]] && sys::Touch "$dst"
    fi

    if [[ -f "$dst" ]] ; then
        sed -E "$@" "$cmd" "$src" >"$dst"
        sys::Chk
    else
        sed -E "$@" "$cmd" "$src"
        sys::Chk
    fi
}

sys::SedInline () # $1:CMD $2:FILE [OPTS] ...
{
    local cmd="$1" src="$2"
    shift 2

    sys::Sed "$cmd" "$src" -i "$@"
}

sys::Jq () # $1:EXPRESSION $2:FILE
{
    which jq &>/dev/null || apt::AddPackages jq >&2

    if [[ $# -eq 1 ]] ; then
        jq -r "$1"
        sys::Chk
    else
        jq -r "$1" "$2"
        sys::Chk
    fi
}

sys::JqInline () # $1:EXPRESSION $2:FILE
{
    which jq &>/dev/null || apt::AddPackages jq

    local tmpFile=$( mktemp )

    if jq "$1" "$2" >"$tmpFile" ; then
        cat "$tmpFile" >"$2"
    else
        sys::Die "jq failed"
    fi

    rm -rf "$tmpFile"
}

sys::XmlstarletInline () # $1:DEST $2:ARGS
{
    which xmlstarlet &>/dev/null || apt::AddPackages xmlstarlet

    local dst="$1"
    shift

    xmlstarlet ed --inplace "$@" "$dst"
    sys::Chk
}

sys::Crudini () # $1:DEST $2:SECTION $3:NAME $4:VALUE
{
    local dst="$1"

    which crudini &>/dev/null || apt::AddPackages crudini >&2
   crudini --set \
        "$dst" \
        "$2" \
        "$3" \
        "$4"
    sys::Chk
    sys::SedInline 's#^(\S+) = #\1=#' "$dst"
}




sys::StartServices () # $*:SERVICES
{
    # TODO CHECK services exists
    for i in $* ; do
        systemctl unmask $i
        sys::Chk
        if [[ $i =~ \.service$ ]] ; then
            systemctl start  $i
        else
            systemctl enable $i
        fi
        sys::Chk
    done
}
sys::StopServices () # $*:SERVICES
{
    for i in $( tr ' ' '\n' <<<$* | tac | tr '\n' ' ' ) ; do
        systemctl stop  $i
        sys::Chk
        systemctl mask $i
        sys::Chk
    done
}


sys::RecursiveKill ()
{   # FROM https://stackoverflow.com/a/42140260
    local children ret=0 sig=${2:-15}

    kill -SIGSTOP $1 ;

    children=$( ps -o pid --no-headers --ppid $1 )

ps -o pid --no-headers --ppid $1 # DBG

    for child in $children ; do
        sys::RecursiveKill $child $sig
        ret=$(( $ret+$? ))
    done

    [[ $ret -eq 0 ]] && kill -$sig $1

    kill -SIGCONT $1
    [[ $ret -eq 0 ]]
    return $?
}

# UNUSED
# sys::RecursiveLdd () # $1:FILE [$2:RESERVED]
# {
#     local tmpList=$2
#     local isRoot=0
#     if [[ -z "$tmpList" ]] ; then
#         isRoot=1
#         tmpList=$(mktemp)
#     fi
#     for lib in $( ldd $1 \
#                 | grep -E '\s/' \
#                 | sed -E 's#.*\s(/\S+).*#\1#'
#                 ) ; do
#         fgrep -q $lib $tmpList && continue
#         echo $lib >>$tmpList
#         ${FUNCNAME[0]} $lib $tmpList >>$tmpList
#     done
#     if [[ $isRoot -eq 1 ]] ; then
#         sort $tmpList
#         rm $tmpList
#     fi
# }

sys::GetUserHome ()
{
    local res="$( getent passwd $1 | cut -f 6 -d ":" )"
    [[ -z "$res" ]] && sys::Die "Unknown user home"
    echo "$res"
}
