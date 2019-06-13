#   ▞▀▖▙ ▌▞▀▖▞▀▖  ▞▀▖  ▌  ▌▗▐  ▗          ▜
#   ▌▄▖▌▌▌▌ ▌▚▄   ▙▄▌▞▀▌▞▀▌▄▜▀ ▄ ▞▀▖▛▀▖▝▀▖▐
#   ▌ ▌▌▝▌▌ ▌▖ ▌  ▌ ▌▌ ▌▌ ▌▐▐ ▖▐ ▌ ▌▌ ▌▞▀▌▐
#   ▝▀ ▘ ▘▝▀ ▝▀   ▘ ▘▝▀▘▝▀▘▀▘▀ ▀▘▝▀ ▘ ▘▝▀▘ ▘


CheckAdditional ()
{
    :
    # TODO CHECK $INSTALL_BUNDLES
    # TODO CHECK $INSTALL_DRIVERS

}

InitAdditional ()
{
    # Additionnal CONSTS
    CORE_PREF="$CORE_PREF
        INSTALL_BUNDLES
        INSTALL_DRIVERS"

    # Fonts
    THEME_FONT_FIXED_NAME="Hack"
    THEME_FONT_FIXED_SIZE="11"

    if [[ "$INSTALL_FREE" == "1" ]] ; then
        THEME_FONT_DOCUMENT_NAME="Sans"
        THEME_FONT_DEFAULT_NAME="Sans"
        THEME_FONT_WINDOW_NAME="Sans Bold"
        THEME_FONT_SHORT_NAME="Sans"
    else
        THEME_FONT_DOCUMENT_NAME="Arial"
        THEME_FONT_DEFAULT_NAME="Helvetica Neue Regular"
        THEME_FONT_WINDOW_NAME="Helvetica Neue Bold"
        THEME_FONT_SHORT_NAME="Helvetica Neue"
    fi
    THEME_FONT_DEFAULT_SIZE="13"

    # Themes
    THEME_CURSOR="Capitaine"
    THEME_ICON="Numix-Circle"
    THEME_GTK="Gnos"  # DEV: symlinked for root theme support
    THEME_GS="$THEME_GTK-theme"

    # Colors
    THEME_COLOR_FOREGD_RGB="192,192,192"
    THEME_COLOR_BACKGD_RGB="24,22,20"
    THEME_COLOR_WINDOW_RGB="36,34,32"
    THEME_COLOR_OBJECT_RGB="48,46,44"
    THEME_COLOR_SELECT_RGB="23,77,141"
    THEME_COLOR_HOTHOT_RGB="232,122,52"
    THEME_COLOR_MANAGE_RGB="183,58,48"
    THEME_COLOR_OKOKOK_RGB="47,134,70"

    # THEME_COLOR_MANAGE_RGB="168,77,174" # purple

    ColorDec2Hex () # $1:R,G,B
    {
        awk 'BEGIN{RS=","} {printf "%02x",$1}' <<<"$1"
    }
    THEME_COLOR_HOTHOT_HEX=$( ColorDec2Hex $THEME_COLOR_HOTHOT_RGB )
    THEME_COLOR_FOREGD_HEX=$( ColorDec2Hex $THEME_COLOR_FOREGD_RGB )
    THEME_COLOR_BACKGD_HEX=$( ColorDec2Hex $THEME_COLOR_BACKGD_RGB )
    THEME_COLOR_WINDOW_HEX=$( ColorDec2Hex $THEME_COLOR_WINDOW_RGB )
    THEME_COLOR_OBJECT_HEX=$( ColorDec2Hex $THEME_COLOR_OBJECT_RGB )
    THEME_COLOR_SELECT_HEX=$( ColorDec2Hex $THEME_COLOR_SELECT_RGB )
    THEME_COLOR_MANAGE_HEX=$( ColorDec2Hex $THEME_COLOR_MANAGE_RGB )
    THEME_COLOR_OKOKOK_HEX=$( ColorDec2Hex $THEME_COLOR_OKOKOK_RGB )


    # DEV: set | grep '^THEME.*_HEX='
    # THEME_COLOR_BACKGD_HEX=181614
    # THEME_COLOR_FOREGD_HEX=c0c0c0
    # THEME_COLOR_HOTHOT_HEX=e87a34
    # THEME_COLOR_MANAGE_HEX=b73a30
    # THEME_COLOR_OBJECT_HEX=302e2c
    # THEME_COLOR_OKOKOK_HEX=2f8646
    # THEME_COLOR_SELECT_HEX=174d8d
    # THEME_COLOR_WINDOW_HEX=242220



    INSTALL_ORDERED="
        com::Cli
        com::Gui
        app::Nautilus
        app::Vlc
        app::Web
        app::Konsole
        app::SublimeText_NONFREE
    "

    # UNUSED NACT_HELPER_RUN_ALL=/usr/local/bin/nact-helper-runall
    NACT_HELPER_GET_ONE=/usr/local/bin/nact-helper-getone
}

SyncAdditional ()
{

    # POSTINST
    POSTINST_USER_SESSION_SCRIPT=/usr/share/session-migration/scripts/$PRODUCT_NAME-postinst-session.sh
    POSTINST_USER_START_SCRIPT=/usr/share/session-migration/scripts/$PRODUCT_NAME-postinst-user.sh
    POSTINST_USER_START_LAUNCHER=$HOME/.config/autostart/$PRODUCT_NAME-postinst-user.desktop
    POSTINST_ROOT_START_SCRIPTS=$HOME/.local/share/$PRODUCT_NAME-postinst-root
    POSTINST_ROOT_START_LAUNCHER=$HOME/.config/autostart/$PRODUCT_NAME-postinst-root.desktop

}

MenuAdditional ()
{

    [[ -z ${INSTALL_BUNDLES+unset} ]] && PRESEED_BUNDLES=0 || PRESEED_BUNDLES=1

    local orig_INSTALL_BUNDLES=$INSTALL_BUNDLES
    INSTALL_BUNDLES=

    local installCli=off
    local installGui=off
    local installApps=off
    local installFull=off

    local installFree=off
    local installPick=off

    if [[ $PRESEED_BUNDLES == 1 ]] ; then

        str::InList com::Cli $orig_INSTALL_BUNDLES && installCli=on
        str::InList com::Gui $orig_INSTALL_BUNDLES && installGui=on

        local list
        list=$( str::RemoveWord com::Cli $orig_INSTALL_BUNDLES )
        list=$( str::RemoveWord com::Gui $list )
        [[ "$( str::GetWordCount $list )" == "0" ]] || installApps=on

    else
        installCli=on
        installGui=on
        installApps=on
        installFull=on
    fi


    local autofix first=1 depsContinue=0
    while true ; do

        if [[ $first -eq 0 ]] ; then

            installCli=off
            installGui=off
            installApps=off
            installFull=off
            installFree=off
            installPick=off

            str::InList CLI     $installOptions && installCli=on
            str::InList GUI     $installOptions && installGui=on
            str::InList APPS    $installOptions && installApps=on
            str::InList FULL    $installOptions && installFull=on
            str::InList FREE    $installOptions && installFree=on
            str::InList PICK    $installOptions && installPick=on
        else

            first=0
        fi

        local installOptions=$(
            ui::SelectList "${autofix}Software additions" \
                CLI      "Command-line tools"       $installCli \
                GUI      "Graphical interface"      $installGui \
                APPS     "Install apps"             $installApps \
                FULL     "Include all apps"         $installFull \
                FREE     "Exclude proprietary apps" $installFree \
                PICK     "Manual app selection"     $installPick
            )
        # TODO # DRIV     "Probe drivers" on \

        # Autofix dependencies
        local depsContinue=0

        if   str::InList FULL $installOptions \
        && ! str::InList APPS $installOptions; then
            installOptions="$installOptions "APPS
            depsContinue=1
        fi

        if   str::InList APPS $installOptions \
        && ! str::InList GUI  $installOptions; then
            installOptions="$installOptions "GUI
            depsContinue=1
        fi

        if [[ $depsContinue -eq 1 ]] ; then
            autofix='[AUTOFIX] '
            continue
        fi

        break
    done


    local INSTALL_FREE
       str::InList FREE $installOptions \
    && INSTALL_FREE=1

    # FULL
    if str::InList FULL $installOptions ; then

        INSTALL_BUNDLES="
            com::Cli
            com::Gui
            $PACKAGES_SETTINGS
            $PACKAGES_SOFTWARE
            $PACKAGES_ACCESSORIES
            $PACKAGES_STORAGE
            $PACKAGES_ENGINE
            $PACKAGES_BROWSE
            $PACKAGES_NET
            $PACKAGES_TRANSFER
            $PACKAGES_SPEAK
            $PACKAGES_PERSONAL
            $PACKAGES_AUDIO
            $PACKAGES_GRAPHICS
            $PACKAGES_VIDEO
            $PACKAGES_ENTERTAIN
            $PACKAGES_OFFICE
            $PACKAGES_CODE
            $PACKAGES_LEARN
            "

           [[ "$INSTALL_FREE" == "1" ]] \
        && INSTALL_BUNDLES=$( AppsNonFreeFilter $INSTALL_BUNDLES )

           str::InList PICK $installOptions \
        && orig_INSTALL_BUNDLES="$INSTALL_BUNDLES" \
        && INSTALL_BUNDLES="com::Cli com::Gui" \
        && MenuApps

    else

           str::InList CLI $installOptions \
        && INSTALL_BUNDLES="$INSTALL_BUNDLES com::Cli"

           str::InList GUI $installOptions \
        && INSTALL_BUNDLES="$INSTALL_BUNDLES com::Gui"

           str::InList APPS $installOptions \
        && MenuApps
    fi

    INSTALL_BUNDLES=$( echo $INSTALL_BUNDLES )

    if [[ -n "$INSTALL_BUNDLES" ]] ; then
        local tdata="PGUP/PGDOWN to scroll, TAB+ENTER to accept

$(
    {
          sed -E <<<$INSTALL_BUNDLES -e 's/\s/\n/g' \
        | grep '^com::' \
        | sed -E -e 's/(^|\s)(com)::/\1/g'

          sed -E <<<$INSTALL_BUNDLES -e 's/(^|\s)com::\S+//g' -e 's/(^|\s)(app)::/\1/g' -e 's/\s/\n/g' \
        | sort -u
    } \
    | awk -v cols=4 '{ for (i = 1; i <= NF; i++) { a[j++]=$i } }
        END { rows=int(j/cols) ; if (j/cols>rows) rows++;
            for (r = r; r <= rows; r++) {
                for (c = 0; c <= cols +1; c++) {
                    if (c==0) print "" ; else printf " "
                    printf a[r+c*rows]
                }
            }
         }' \
    | column -t 2>/dev/null
)"
        whiptail $UI_OPTS --textbox --scrolltext --backtitle "$UI_TEXT" \
            --title "Please review additional software"  \
            /dev/fd/0 38 80 3>&1 1>&2 2>&3 <<<"$tdata"
    fi
}


MenuApps ()
{
    local categories=$(
        ui::SelectList "Software categories"       \
            SETTINGS    "Settings management"   on \
            SOFTWARE    "Software management"   on \
            ACCESSORIES "Desktop accessories"   on \
            STORAGE     "Storage management"    on \
            ENGINE      "Execution engines"     on \
            BROWSE      "Web browsers"          on \
            NET         "Network tools"         on \
            TRANSFER    "File transfer"         on \
            SPEAK       "Chat and Share"        on \
            PERSONAL    "Personal information"  on \
            ENTERTAIN   "Entertainment"         on \
            AUDIO       "Audio software"        on \
            GRAPHICS    "Graphics software"     on \
            VIDEO       "Video software"        on \
            OFFICE      "Office software"       on \
            CODE        "Development tools"     on \
            LEARN       "Learning sources"      on
        )

    # DEV: reordrered to fulfill dependencies issues
    AppsCategoryHelper SETTINGS    "Settings management"    "$PACKAGES_SETTINGS"
    AppsCategoryHelper SOFTWARE    "Software management"    "$PACKAGES_SOFTWARE"
    AppsCategoryHelper ACCESSORIES "Desktop accessories"    "$PACKAGES_ACCESSORIES"
    AppsCategoryHelper STORAGE     "Storage management"     "$PACKAGES_STORAGE"
    AppsCategoryHelper ENGINE      "Execution engines"      "$PACKAGES_ENGINE"
    AppsCategoryHelper BROWSE      "Web browsers"           "$PACKAGES_BROWSE"
    AppsCategoryHelper NET         "Network tools"          "$PACKAGES_NET"
    AppsCategoryHelper TRANSFER    "File transfer"          "$PACKAGES_TRANSFER"
    AppsCategoryHelper SPEAK       "Chat and Share"         "$PACKAGES_SPEAK"
    AppsCategoryHelper PERSONAL    "Personal information"   "$PACKAGES_PERSONAL"
    AppsCategoryHelper AUDIO       "Audio software"         "$PACKAGES_AUDIO"
    AppsCategoryHelper GRAPHICS    "Graphics software"      "$PACKAGES_GRAPHICS"
    AppsCategoryHelper VIDEO       "Video software"         "$PACKAGES_VIDEO"
    AppsCategoryHelper ENTERTAIN   "Entertainment"          "$PACKAGES_ENTERTAIN"
    AppsCategoryHelper OFFICE      "Office software"        "$PACKAGES_OFFICE"
    AppsCategoryHelper CODE        "Development tools"      "$PACKAGES_CODE"
    AppsCategoryHelper LEARN       "Learning sources"       "$PACKAGES_LEARN"
}




AppsCategoryHelper () # $1:KEY $2:TITLE $3:LIST
{
    # DEV this macro is using local variables from upper functions:
    # from MenuApps(): $categories
    # from MenuAdditional(): $PRESEED_BUNDLES $INSTALL_FREE $orig_INSTALL_BUNDLES $installOptions $MenuAdditional

    local default selected onlyFree

    if [[ $PRESEED_BUNDLES == 0 ]] ; then
        [[ "$INSTALL_FREE" == "1" ]] && onlyFree="--free"
    fi

    if [[ $PRESEED_BUNDLES == 1 ]] \
    || str::InList $1 $categories ; then

        if str::InList FULL $installOptions \
        || [[ $PRESEED_BUNDLES == 1 ]] ; then
            default=$orig_INSTALL_BUNDLES
        else
            for pack in $3 ; do
                   [[ "$( GetFuncMetaByKey $pack "no-default" )" == "true" ]] \
                || default="$default $pack"
            done
        fi

        if [[ $PRESEED_BUNDLES == 1 ]] \
        || str::InList PICK $installOptions ; then

            selected=$( AppsSelectBundle $onlyFree "$2" "$3" "$default" )
            INSTALL_BUNDLES="$INSTALL_BUNDLES $selected"

        else
            [[ -n "$onlyFree" ]] && default=$( AppsNonFreeFilter $default )
            INSTALL_BUNDLES="$INSTALL_BUNDLES $default"
        fi

    elif str::InList FULL $installOptions ; then

        selected=$( AppsSelectBundle $onlyFree "$2" "$3" "" )
        INSTALL_BUNDLES="$INSTALL_BUNDLES $selected"

    fi
}


AppsNonFreeFilter () # $*:
{
    local ret
    for package in $* ; do
        [[ $package != *_NONFREE ]] && ret="$ret "$package
    done

    echo $ret
}


AppsSelectBundle () # [ '--free' ] $1:TEXT $2:LIST [ $3:DEFAULT ]
{
    local prefix="app::"

    local onlyfree=
    [[ "$1" == "--free" ]] && { onlyfree="--free" ; shift ; }


    local options status
    for package in $2 ; do
        status="off"
        if str::InList $package $3 ; then
            status="on"
        fi
        [[ -n "$onlyfree" ]] && [[ $package == *_NONFREE ]] && status="off"
        options="$options ${package#$prefix} \"$( GetFuncMetaByKey $package desc )\" $status"
    done

    local cmd="$UI_OPTS --separate-output --checklist --backtitle \"$UI_TEXT\" \"$1\" 20 64 13 $options"
    local ret=$( echo "$cmd" | xargs whiptail 3>&1 1>&2 2>&3 )
    for package in $ret ; do echo -n "$prefix$package " ; done
}


InstallAdditional ()
{
    sys::LogOutput

    local bundles=$INSTALL_BUNDLES
    local cnt=0 tot=$( str::GetWordCount $bundles )

    # DEV: First, run ordered installers
    for installer in $INSTALL_ORDERED ; do
        if str::InList $installer $INSTALL_BUNDLES ; then
            ((cnt++))
            sys::Msg --color "0;34" "Installing bundle $cnt/$tot: $installer"
            $installer
            bundles=$( str::RemoveWord $installer $bundles )

            # DEBUG snapshots
            #    str::InList ZFS $STORAGE_OPTIONS \
            # && zfs::CreateSnapshot $ZFS_POOL_NAME/$ZFS_ROOT_DSET install-debug-$installer
        fi
    done

    # DEV: Then, run other installers
    for installer in $bundles ; do
        ((cnt++))
        sys::Msg --color "0;34" "Installing bundle $cnt/$tot: $installer"
        $installer

        # DEBUG snapshots
        #    str::InList ZFS $STORAGE_OPTIONS \
        # && zfs::CreateSnapshot $ZFS_POOL_NAME/$ZFS_ROOT_DSET install-debug-$installer
    done

    # HOOK HookPostAdditional
    if [[ "$( type -t HookPostAdditional 2>/dev/null )" == "function" ]] ; then
        sys::Msg --color "0;34" "Installing HookPostAdditional"
        HookPostAdditional
    fi

    #
    Clean


    # ZFS snapshot
    if str::InList ZFS $STORAGE_OPTIONS ; then

        zfs::CreateSnapshot $ZFS_POOL_NAME/$ZFS_ROOT_DSET factory-install

        # ZFS bootclone
        # if str::InList BOOTCLONE $STORAGE_OPTIONS ; then
        #     bootclone create $( basename $ZFS_ROOT_DSET )-factory-install \
        #         $ZFS_POOL_NAME/$ZFS_ROOT_DSET@factory-install
        #     sys::Chk
        # fi
    fi



}


RegisterPostInstall () # $1:FUNC_NAME $2:PRIO
{
    sys::Touch "$POSTINST_ROOT_START_SCRIPTS/$2_$1" 1000:1000
}


# DEV Called interactively by $POSTINST_ROOT_START_LAUNCHER
PostInstallAdditional ()
{
    if [[ ! -d "$POSTINST_ROOT_START_SCRIPTS" ]] ; then
        mv "$POSTINST_ROOT_START_LAUNCHER"{,.DISABLED}
        return
    fi

    sys::Msg "$PRODUCT_NAME POSTINST scripts"

    net::Check

    sys::LogOutput "/tmp/$(basename "$POSTINST_ROOT_START_SCRIPTS" .sh)_$$.log"

    # process post:: scripts
    local ret func err=0
    while IFS= read -r -d $'\0' file || [[ -n $file ]] ; do
        func="$( basename "$file" )"
        func="${func#*_}"
        if [[ "$( type -t $func 2>/dev/null )" == "function" ]] ; then
            sys::Msg --color "0;34" "Running $func"
            DEBUG_ACTIVE=1
set -x
            $func
            ret=$?
set +x
            DEBUG_ACTIVE=
            if [[ $ret -eq 0 ]] ; then
                sys::Msg "Succesfull $func run"
                rm "$file"
            else
                err=1
                sys::Msg --color "1;31" "ERROR: $func returned $ret"
                mv "$file"{,.FAILED}
            fi
        else
            sys::Msg "Ignoring invalid POSTINST $file"
            continue
        fi
    done < <( find -L "$POSTINST_ROOT_START_SCRIPTS" \
                 -maxdepth 1 \
                 -type f \
                 -name "??_post::?*" \
                 \! -name "*.FAILED" \
                 -print0 \
                 2>/dev/null \
            | sort -z
            )

    # clean
    [[ $err -eq 0 ]] && rm "$POSTINST_ROOT_START_LAUNCHER"
    if find "$POSTINST_ROOT_START_SCRIPTS" -maxdepth 0 -type d -empty 2>/dev/null ; then
        rmdir "$POSTINST_ROOT_START_SCRIPTS"
    fi

    sys::UnLogOutput
    return 0
}


