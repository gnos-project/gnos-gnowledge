########
# FUNC #  HELP
########


Help ()
{
    Init
    cat <<EOF
${PRODUCT_NAME^^} Core installer
===================

Alternative Ubuntu system installer featuring advanced storage options

Usage:
======

$PRODUCT_NAME <options> <command> <args...>

Options:
========

-c|--config         Use config file
-C|--no-config      Don't detect config file
-a|--additional     Use additional code file
-h|--help           This help screen

Commands:
========

MenuInstall                     Interactive initial system install
MenuExtend                      Interactive additional ZFS install
MenuRepair                      Interactive recovery console
Deploy                          Unattended install
Internal     FUNCTION [ARGS...] Call one internal function with arguments
InternalList FUNCTION...        Call several internal functions without args

┌───────────────────────────────────────────────────────────────────┐
| ! THIS SCRIPT MAY HARM YOUR COMPUTER, PLEASE READ DOCUMENTATION ! |
└───────────────────────────────────────────────────────────────────┘
EOF
# UNUSED -A|--no-additional  Don't detect additional code file

    exit $?
}


########
# FUNC #  MAIN
########



# TODO find based implementation, use with array
TODO_GetConfigfiles ()
{
    {
        find /etc /root \
            -mindepth 1 -maxdepth 1 \
            -name "$PRODUCT_NAME.conf" \
            -print0 2>/dev/null
        find "$(pwd)" "$HOME" \
            -mindepth 1 -maxdepth 1 \
            -name "*.$PRODUCT_NAME.conf" \
            -print0 2>/dev/null
    } | sort --zero-terminated
}

GetConfigfiles ()
{
    # BUG: space separated list

    local foundList
    for candidate in \
              ./{*.,}$PRODUCT_NAME.conf \
           /etc/{*.,}$PRODUCT_NAME.conf \
        $HOME/{.,*.,}$PRODUCT_NAME.conf \
        /root/{.,*.,}$PRODUCT_NAME.conf ;
    do
        [[ -f "$candidate" ]] && foundList="$foundList $( readlink -f $candidate )"

    done

    case "$(pwd)" in
        /etc|$HOME|/root)
            ;;
        *)
            for candidate in ./{*.,}$PRODUCT_NAME.conf ; do
                [[ -f "$candidate" ]] && foundList="$foundList $candidate"
            done
    esac
    echo "${foundList:1}"
}


IsConfigfileValid () # $1:CONFIG_FILE
{
    local bashErrors ret
    bashErrors=$( bash -n "$1" 2>&1 )
    ret=$?
    [[ $ret -ne 0 ]] && sys::Msg "WARNING: config file has errors:\n$bashErrors"
    return $ret
}


Main ()
{
    # Check sudo
       [[ $( id -u ) != "0" ]]  \
    && sys::Die "$( basename "$BASH_SOURCE" ) requires sudo"

    [[ $# -eq 0 ]] && Help

    # Parse options
    local param mode func configfile autoConfigList
    while [[ "$1" =~ ^- ]] ; do
        param=$1
        shift
        case "$param" in

            -h|--help)
                Help
                ;;

            -c|--config)
                [[ -f "$1" ]] || sys::Die "Unknown config file: $1"
                configfile=$1
                shift
                ;;

            -C|--no-config)
                configfile='<none>'
                ;;

            -a|--additional)

                # bundle consistency
                # for additionalHook in InitAdditional MenuAdditional InstallAdditional ; do
                #     type -t $additionalHook &>/dev/null && sys::Die "$additionalHook already bundled"
                # done

                [[ -f "$1" ]] || sys::Die "Unknown additional file: $1"
                bash -n "$1"  || sys::Die "Invalid additional file: $1"
                source "$1"
                shift
                ;;

            # UNUSED
            # -A|--no-additional)
            #     ;;

            *) break ;;

        esac

    done

    # Parse command
    local cmd=$1
    shift


    # Init
    Init

    # Init: Additional
       [[ "$( type -t InitAdditional 2>/dev/null )" == "function" ]] \
    && InitAdditional


    # configfile

    # autodetect configfile
    # if [[ "$configfile" != '<none>' ]] ; then
    local configCount
    if [[ -z "$configfile" ]] ; then
        autoConfigList=$( GetConfigfiles )
        configCount=$( str::GetWordCount $autoConfigList )
           [[ $configCount -eq 1 ]] \
        && configfile=$autoConfigList
    else
        configCount=1
    fi

    # source configfile
    if [[ -n "$configfile" ]] && [[ "$configfile" != '<none>' ]] ; then

           IsConfigfileValid "$configfile" \
        || sys::Die "Invalid config file: $configfile"

        [[ -n "$cmd" ]] && sys::Msg "Using configuration file: $configfile"

        source $configfile

    else
        [[ -n "$cmd" ]] && case $cmd in
            Menu|MenuConfig|MenuInstall|MenuRepair|MenuExtend)
                # configfile is NOT required
                ;;
                
            *)
                if [[ $cmd == 'Internal' && $1 =~ ^Build ]] ; then
                    :
                # configfile is required
                elif [[ -z "$autoConfigList" ]] ; then
                    sys::Die "Command $cmd requires: --config FILE"
                else
                    sys::Die "Found multiple configuration files, use --config to specify one of:\n"$autoConfigList
                fi
                ;;
        esac
    fi

    # check configfile
    # [[ -n "$configfile" ]] && [[ "$configfile" != '<none>' ]] && CheckConfig
    [[ -n "$configfile" ]] && [[ "$configfile" != '<none>' ]] && INSTALL_MODE=MenuInstall CheckConfig


    # sync
    SyncInternals
    
       [[ "$( type -t SyncAdditional 2>/dev/null )" == "function" ]] \
    && SyncAdditional

    PARENT_PID=$$


    case $cmd in
        Menu*)
               [[ "$( type -t $cmd 2>/dev/null )" == "function" ]] \
            || sys::Die "Unknown menu: $func"

            # DEV: whiptail background
            tput setab 5 ; printf ' %0.s' $( seq 1 $(( $( tput lines) * $( tput cols ) )) )

            $cmd "$@"
            ;;


        # Call one internal function with arguments
        i|Internal)
            func=$1
            shift
              [[ "$( type -t $func 2>/dev/null )" == "function" ]] \
            || sys::Die "Unknown internal: $func"

            # NO INSTALL_MODE except for ...
            case $func in
                ChrootedInstaller|InstallAdditional|PostInstallAdditional|Deploy)
                    ;;
                *)  INSTALL_MODE=
                    ;;
            esac



            DEBUG_ACTIVE=1
            set -x # DEBUG

            $func "$@"
            exit $?
            ;;


        # Call multiple internal functions without arguments
        I|InternalList)
            local unknownFuncs
            for func in $* ; do
                   [[ "$( type -t $func 2>/dev/null )" == "function" ]] \
                || unknownFuncs="$unknownFuncs $func"
            done
            [[ -n "$unknownFuncs" ]] && sys::Die "Unknown internals:$unknownFuncs"

            # NO INSTALL_MODE
            INSTALL_MODE=

            DEBUG_ACTIVE=1
            set -x # DEBUG

            for func in $* ; do
                $func
            done
            exit $?
            ;;

        # Unattended install
        Deploy)
            DEBUG_ACTIVE=1
            set -x # DEBUG

            $cmd
            ;;

        # Unknown
        *)
            INSTALL_MODE=
            Help
            ;;

    esac

}

