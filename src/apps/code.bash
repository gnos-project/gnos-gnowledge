########
# FUNC #  BUNDLES::DEV
########



PACKAGES_CODE="
    app::Konsole
    app::SublimeText_NONFREE
    app::SublimeMerge_NONFREE
    app::Vscode
    app::Ghidra
    app::Gitkraken_NONFREE
    app::Meld
    app::Okteta
    app::Dbeaver
    app::Sqlitebrowser
    app::Insomnia
    app::Zeal
    "



app::Konsole ()
{
    Meta --desc "Terminal emulator"

    rm /usr/local/share/applications/terminal.desktop

    apt::AddPackages \
        konsole \
        kdelibs-bin \
        kdelibs5-plugins

    gui::AddAppFolder Code org.kde.konsole
    # gui::AddFavoriteApp org.kde.konsole

    gui::AddKeybinding term-new "<Shift><Super>t" "konsole" # TIP: org.gnome.settings-daemon.plugins.media-keys terminal
    gui::AddKeybinding term "<Super>t" \
        'bash -c "f=0 ; for i in $( xdotool search --class konsole ) ; do r=$( xdotool windowactivate $i 2>&1) ; [[ ${#r} -eq 0 ]] && f=1 && break ; done ; [[ $f -eq 0 ]] && /usr/local/bin/gnos-sugar Nohup konsole"'
        # 'bash -c "xdotool windowactivate $( comm -13 <( xdotool search -maxdepth 1 --class konsole | sort) <( xdotool search --class konsole | sort ) | tail -1 ) 2>/dev/null || konsole"'
    gui::AddKeybinding term-root "<Primary><Super>t" "konsole --new-tab --profile bash:ROOT@local"

    # FIX StartupWMClass
    sed -E \
        's#^(\[Desktop Entry\].*)$#\1\nStartupWMClass=konsole#' \
        /usr/share/applications/org.kde.konsole.desktop \
        >/usr/local/share/applications/org.kde.konsole.desktop

    # FIX Filemanager MIME
    gui::SetDefaultAppForMimetypes nautilus-folder-handler inode/directory
    gui::SetDefaultAppForMimetypes --user nautilus-folder-handler inode/directory

    # gnome-terminal hijack
    sys::Write <<'EOF' /usr/local/bin/gnome-terminal 0:0 755
#!/bin/bash
# Convert common first option from gnome-terminal to konsole usage
declare -a opt
tab=--new-tab
while true ; do
    case $1 in
        --window)               shift ; tab= ;;
        --full-screen)          shift ; opt+=("--fullscreen")  ;;
        --working-directory)    shift ; opt+=("--workdir"); opt+=("$1") ; shift ;;
        -x)                     shift ; opt+=("-e") ; break ;;
        *)                      break ;;
    esac
done
[[ -n "$tab" ]] && xdotool windowactivate $( comm -13 <( xdotool search -maxdepth 1 --class konsole | sort) <( xdotool search --class konsole | sort ) | tail -1 ) 2>/dev/null
exec konsole $tab "${opt[@]}" "$@"
EOF

    # CONF
    local konsoleRc=$HOME/.config/konsolerc # vivid & wily

    sys::Write <<EOF $konsoleRc 1000:1000
[Desktop Entry]
DefaultProfile=bash:$USER_USERNAME@local.profile

[Favorite Profiles]
Favorites=bash:$USER_USERNAME@local.profile,bash:ROOT@local.profile,fish:$USER_USERNAME@local.profile,zsh:$USER_USERNAME@local.profile,htop:$USER_USERNAME@local.profile,lnav:ROOT@local.profile,tmux:$USER_USERNAME@local.profile

[FileLocation]
scrollbackUseCacheLocation=true
scrollbackUseSystemLocation=false

[KonsoleWindow]
ShowAppNameOnTitleBar=false
ShowMenuBarByDefault=false
ShowWindowTitleOnTitleBar=true
UseSingleInstance=true

[MainWindow]
MenuBar=Disabled

[Profile Shortcuts]
Alt+B=bash:$USER_USERNAME@local.profile
Alt+R=bash:ROOT@local.profile
Alt+H=htop:$USER_USERNAME@local.profile
Alt+L=lnav:ROOT@local.profile
EOF

    # Custom Konsole Color Scheme FROM: Terminator Ambiance palette
    local konsoleColorScheme=/usr/local/share/konsole/$PRODUCT_NAME.colorscheme # vivid

    sys::Write <<EOF $konsoleColorScheme
[Background]
Color=$THEME_COLOR_BACKGD_RGB

[BackgroundIntense]
Color=$THEME_COLOR_WINDOW_RGB

[Color0]
Color=$THEME_COLOR_BACKGD_RGB

[Color1]
Color=$THEME_COLOR_MANAGE_RGB

[Color2]
Color=$THEME_COLOR_OKOKOK_RGB

[Color3]
Color=196,160,0

[Color4]
Color=$THEME_COLOR_SELECT_RGB

[Color5]
Color=117,80,123

[Color6]
Color=6,152,154

[Color7]
Color=211,215,207

[Color0Intense]
Color=$THEME_COLOR_OBJECT_RGB

[Color1Intense]
Color=239,41,41

[Color2Intense]
Color=138,226,52

[Color3Intense]
Color=252,233,79

[Color4Intense]
Color=114,159,207

[Color5Intense]
Color=173,127,168

[Color6Intense]
Color=52,226,226

[Color7Intense]
Color=238,238,236

[Foreground]
Color=$THEME_COLOR_FOREGD_RGB

[ForegroundIntense]
Color=255,255,255

[General]
Description=$PRODUCT_NAME
Opacity=1
Wallpaper=
EOF

    chown -hR 1000:1000 $HOME/.kde $konsoleColorScheme

    # PROFILES
    local konsoleDefaultProfile=/usr/share/konsole/Shell.profile
    local konsoleProfilesPath=$HOME/.local/share/konsole/

    mkdir -p "$konsoleProfilesPath"

    # Default profile
    sys::Write <<EOF $konsoleDefaultProfile
[Appearance]
ColorScheme=$PRODUCT_NAME
Font=$THEME_FONT_FIXED_NAME,$THEME_FONT_FIXED_SIZE,-1,5,50,0,0,0,0,0

[Cursor Options]
UseCustomCursorColor=true
CustomCursorColor=$THEME_COLOR_HOTHOT_RGB

[General]
Name=Default
Command=/bin/bash
Icon=terminal
Parent=FALLBACK/
LocalTabTitleFormat=%w
RemoteTabTitleFormat=%w

[Interaction Options]
AutoCopySelectedText=true
OpenLinksByDirectClickEnabled=false
TripleClickMode=1

[Scrolling]
HistoryMode=2

[Terminal Features]
FlowControlEnabled=false
EOF


    # PROFILES
    local name

    name="bash:$USER_USERNAME@local"
    sys::Copy "$konsoleDefaultProfile" "$konsoleProfilesPath/$name.profile"
    sys::Crudini "$konsoleProfilesPath/$name.profile" "General"   "Icon"    "terminal"
    sys::Crudini "$konsoleProfilesPath/$name.profile" "General"   "Command" "bash"

    name="bash:ROOT@local"
    sys::Copy "$konsoleDefaultProfile" "$konsoleProfilesPath/$name.profile"
    sys::Crudini "$konsoleProfilesPath/$name.profile" "General"   "Name"    "$name"
    sys::Crudini "$konsoleProfilesPath/$name.profile" "General"   "Icon"    "gksu-root-terminal"
    sys::Crudini "$konsoleProfilesPath/$name.profile" "General"   "Command" 'sudo --set-home bash --rcfile $HOME/.bashrc'
    sys::Crudini "$konsoleProfilesPath/$name.profile" "Cursor Options" "CustomCursorColor" "$THEME_COLOR_MANAGE_RGB"

    name="htop:$USER_USERNAME@local"
    sys::Copy "$konsoleDefaultProfile" "$konsoleProfilesPath/$name.profile"
    sys::Crudini "$konsoleProfilesPath/$name.profile" "General"   "Name"    "$name"
    sys::Crudini "$konsoleProfilesPath/$name.profile" "General"   "Icon"    "htop"
    sys::Crudini "$konsoleProfilesPath/$name.profile" "General"   "Command" "shtop"
    sys::Crudini "$konsoleProfilesPath/$name.profile" "Scrolling" "ScrollBarPosition" 2

    name="lnav:ROOT@local"
    sys::Copy "$konsoleDefaultProfile" "$konsoleProfilesPath/$name.profile"
    sys::Crudini "$konsoleProfilesPath/$name.profile" "General"   "Name"    "$name"
    sys::Crudini "$konsoleProfilesPath/$name.profile" "General"   "Icon"    "logview"
    sys::Crudini "$konsoleProfilesPath/$name.profile" "Scrolling" "ScrollBarPosition" 2
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        sys::Crudini "$konsoleProfilesPath/$name.profile" "General"   "Command" "sudo --set-home lnav -s"
    else
        sys::Crudini "$konsoleProfilesPath/$name.profile" "General"   "Command" "sudo --set-home lnav"
    fi

    # fish:user@local
    if which fish &>/dev/null ; then
        name="fish:$USER_USERNAME@local"
        sys::Copy "$konsoleDefaultProfile" "$konsoleProfilesPath/$name.profile"
        sys::Crudini "$konsoleProfilesPath/$name.profile" "General"   "Name"    "$name"
        sys::Crudini "$konsoleProfilesPath/$name.profile" "General"   "Icon"    "xterm-color"
        sys::Crudini "$konsoleProfilesPath/$name.profile" "General"   "Command" "fish"
        sys::Crudini "$konsoleRc" "Profile Shortcuts" "Alt+F" "$name.profile"
    fi

    if which zsh &>/dev/null ; then
        name="zsh:$USER_USERNAME@local"
        sys::Copy "$konsoleDefaultProfile" "$konsoleProfilesPath/$name.profile"
        sys::Crudini "$konsoleProfilesPath/$name.profile" "General"   "Name"    "$name"
        sys::Crudini "$konsoleProfilesPath/$name.profile" "General"   "Icon"    "final-term"
        sys::Crudini "$konsoleProfilesPath/$name.profile" "General"   "Command" "zsh"
        sys::Crudini "$konsoleRc" "Profile Shortcuts" "Alt+Z" "$name.profile"
    fi

    if which tmux &>/dev/null ; then
        name="tmux:$USER_USERNAME@local"
        sys::Copy "$konsoleDefaultProfile" "$konsoleProfilesPath/$name.profile"
        sys::Crudini "$konsoleProfilesPath/$name.profile" "General"   "Name"    "$name"
        sys::Crudini "$konsoleProfilesPath/$name.profile" "General"   "Icon"    "extraterm"
        sys::Crudini "$konsoleProfilesPath/$name.profile" "General"   "Command" "tmux new -A -s default"
        sys::Crudini "$konsoleProfilesPath/$name.profile" "Scrolling" "ScrollBarPosition" 2
        sys::Crudini "$konsoleRc" "Profile Shortcuts" "Alt+T" "$name.profile"
    fi


    # THEMING tabbar
    sys::Write --append <<EOF "$konsoleRc"
[TabBar]
TabBarPosition=Top
TabBarVisibility=ShowTabBarWhenNeeded
TabBarStyleSheet=QTabBar::tab { padding: 5px; border-style: solid; font-size: 12px; font-weight: bold; } QTabBar::tab:hover { background-color: #$THEME_COLOR_OBJECT_HEX; } QTabBar::tab:selected {color: #$THEME_COLOR_HOTHOT_HEX; background-color: palette(base); border-top: 2px solid palette(window);}
EOF
    # DEV HIDPI { iconSize 20px; font-size: 20px;

    # KEYBINDING: file manager
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then

        grep -v '</kpartgui>' \
            /usr/share/kxmlgui5/konsole/sessionui.rc \
            >"$HOME/.local/share/kxmlgui5/konsole/sessionui.rc"

        sys::Write --append <<EOF "$HOME/.local/share/kxmlgui5/konsole/sessionui.rc" 1000:1000
  <ActionProperties scheme="Default">
    <Action name="open-browser" shortcut="Ctrl+Alt+F"/>
  </ActionProperties>
</kpartgui>
EOF

        sys::Write <<'EOF' "$HOME/.local/share/kxmlgui5/konsole/konsoleui.rc"
<!DOCTYPE kpartgui>
<kpartgui version="10" name="konsole">
 <MenuBar>
  <Menu name="file">
   <text>File</text>
   <Action name="new-window"/>
   <Action name="new-tab"/>
   <Action name="clone-tab"/>
   <Separator/>
   <DefineGroup name="session-operations"/>
   <Separator/>
   <DefineGroup name="session-tab-operations"/>
   <Action name="close-window"/>
  </Menu>
  <Menu name="edit">
   <text>Edit</text>
   <DefineGroup name="session-edit-operations"/>
  </Menu>
  <Menu name="view">
   <text>View</text>
   <Menu name="view-split">
    <text>Split View</text>
    <Action name="split-view-left-right"/>
    <Action name="split-view-top-bottom"/>
    <Action name="close-active-view"/>
    <Action name="close-other-views"/>
    <Action name="expand-active-view"/>
    <Action name="shrink-active-view"/>
   </Menu>
   <Separator/>
   <Action name="detach-view"/>
   <Separator/>
   <DefineGroup name="session-view-operations"/>
  </Menu>
  <Action name="bookmark"/>
  <Menu name="settings">
   <text>Settings</text>
   <DefineGroup name="session-settings"/>
   <Action name="manage-profiles"/>
   <Action name="show-menubar"/>
   <Separator/>
   <Action name="view-full-screen"/>
   <Separator/>
   <Action name="configure-shortcuts"/>
   <Action name="configure-notifications"/>
   <Action name="configure-settings"/>
  </Menu>
  <Menu name="help">
   <text>Help</text>
  </Menu>
 </MenuBar>
 <ActionProperties scheme="Default">
  <Action name="open-browser" shortcut="Ctrl+Alt+F"/>
  <Action name="clone-tab" shortcut=""/>
  <Action name="help_contents" shortcut=""/>
  <Action name="new-window" shortcut=""/>
  <Action name="next-view" shortcut="Alt+Right"/>
  <Action name="previous-view" shortcut="Alt+Left"/>
  <Action name="move-view-left" shortcut="Alt+Shift+Left"/>
  <Action name="move-view-right" shortcut="Alt+Shift+Right"/>
 </ActionProperties>
</kpartgui>
EOF
    else  # BIONIC

        sys::Write <<'EOF' "$HOME/.local/share/kxmlgui5/konsole/konsoleui.rc"
<!DOCTYPE kpartgui>
<kpartgui name="konsole" version="10">
 <MenuBar>
  <Menu name="file">
   <text>File</text>
   <Action name="new-window"/>
   <Action name="new-tab"/>
   <Action name="clone-tab"/>
   <Separator/>
   <DefineGroup name="session-operations"/>
   <Separator/>
   <DefineGroup name="session-tab-operations"/>
   <Action name="close-window"/>
  </Menu>
  <Menu name="edit">
   <text>Edit</text>
   <DefineGroup name="session-edit-operations"/>
  </Menu>
  <Menu name="view">
   <text>View</text>
   <Menu name="view-split">
    <text>Split View</text>
    <Action name="split-view-left-right"/>
    <Action name="split-view-top-bottom"/>
    <Action name="close-active-view"/>
    <Action name="close-other-views"/>
    <Action name="expand-active-view"/>
    <Action name="shrink-active-view"/>
   </Menu>
   <Separator/>
   <Action name="detach-view"/>
   <Separator/>
   <DefineGroup name="session-view-operations"/>
  </Menu>
  <Action name="bookmark"/>
  <Menu name="settings">
   <text>Settings</text>
   <DefineGroup name="session-settings"/>
   <Action name="manage-profiles"/>
   <Action name="show-menubar"/>
   <Separator/>
   <Action name="view-full-screen"/>
   <Separator/>
   <Action name="configure-shortcuts"/>
   <Action name="configure-notifications"/>
   <Action name="configure-settings"/>
  </Menu>
  <Menu name="help">
   <text>Help</text>
  </Menu>
 </MenuBar>
 <ActionProperties scheme="Default">
  <Action name="clone-tab" shortcut=""/>
  <Action name="help_contents" shortcut=""/>
  <Action name="next-view" shortcut="Alt+Right"/>
  <Action name="previous-view" shortcut="Alt+Left"/>
  <Action name="move-view-left" shortcut="Alt+Shift+Left"/>
  <Action name="move-view-right" shortcut="Alt+Shift+Right"/>
  <Action name="new-window" shortcut=""/>
 </ActionProperties>
</kpartgui>
EOF

        sys::Write <<'EOF' "$HOME/.local/share/kxmlgui5/konsole/sessionui.rc"
<!DOCTYPE kpartgui>
<kpartgui version="24" name="session">
 <MenuBar>
  <Menu name="file">
   <Action name="file_save_as" group="session-operations"/>
   <Separator group="session-operations"/>
   <Action name="file_print" group="session-operations"/>
   <Separator group="session-operations"/>
   <Action name="open-browser" group="session-operations"/>
   <Action name="close-session" group="session-tab-operations"/>
  </Menu>
  <Menu name="edit">
   <Action name="edit_copy" group="session-edit-operations"/>
   <Action name="edit_paste" group="session-edit-operations"/>
   <Separator group="session-edit-operations"/>
   <Action name="select-all" group="session-edit-operations"/>
   <Separator group="session-edit-operations"/>
   <Action name="copy-input-to" group="session-edit-operations"/>
   <Action name="send-signal" group="session-edit-operations"/>
   <Action name="rename-session" group="session-edit-operations"/>
   <Action name="zmodem-upload" group="session-edit-operations"/>
   <Separator group="session-edit-operations"/>
   <Action name="edit_find" group="session-edit-operations"/>
   <Action name="edit_find_next" group="session-edit-operations"/>
   <Action name="edit_find_prev" group="session-edit-operations"/>
  </Menu>
  <Menu name="view">
   <Action name="monitor-silence" group="session-view-operations"/>
   <Action name="monitor-activity" group="session-view-operations"/>
   <Separator group="session-view-operations"/>
   <Action name="enlarge-font" group="session-view-operations"/>
   <Action name="shrink-font" group="session-view-operations"/>
   <Action name="set-encoding" group="session-view-operations"/>
   <Separator group="session-view-operations"/>
   <Action name="clear-history" group="session-view-operations"/>
   <Action name="clear-history-and-reset" group="session-view-operations"/>
  </Menu>
  <Menu name="settings">
   <Action name="edit-current-profile" group="session-settings"/>
   <Action name="switch-profile" group="session-settings"/>
  </Menu>
 </MenuBar>
 <Menu name="session-popup-menu">
  <Action name="edit_copy"/>
  <Action name="edit_paste"/>
  <Action name="web-search"/>
  <Action name="open-browser"/>
  <Separator/>
  <Action name="set-encoding"/>
  <Action name="clear-history"/>
  <Action name="adjust-history"/>
  <Separator/>
  <Action name="switch-profile"/>
  <Action name="edit-current-profile"/>
  <Separator/>
  <Action name="close-session"/>
 </Menu>
 <ActionProperties scheme="Default">
  <Action shortcut="Ctrl+Alt+F" name="open-browser"/>
 </ActionProperties>
</kpartgui>
EOF
    fi

    chown -hR 1000:1000 "$konsoleProfilesPath" "$HOME/.local/share/kxmlgui5"

    # Man function opens `man` in new tab
    local bashrc=$HOME/.bashrc
    [[ -d "$HOME/.bashrc.d" ]] && bashrc=$HOME/.bashrc.d/gvm
    sys::Write --append <<'EOF' "$bashrc"
Man ()
{
    local prefix
    [[ "$( id -u )" == "0" ]] && prefix=grun
    $prefix konsole --new-tab -p tabtitle="man:$*" -e bash -ic "man $*"

}
source /usr/share/bash-completion/completions/man && complete -F _man Man

EOF

    # TIP: tweaking konsole LOCALLY
    # konsoleprofile UseCustomCursorColor=true ; konsoleprofile  CustomCursorColor="#f04a50"
    # konsoleprofile UseCustomCursorColor=true ; konsoleprofile  CustomCursorColor="#ffa726"
}



app::SublimeText_NONFREE ()
{
    Meta --desc "Text editor"

    # CodeIntel
    pip::Install --upgrade --pre CodeIntel

    # Hide Vim
    gui::HideApps vim

    apt::AddSource sublime-text \
            "https://download.sublimetext.com/" \
            "apt/stable/" \
            "https://download.sublimetext.com/sublimehq-pub.gpg"
    apt::AddPackages sublime-text
    local launcherName=sublime_text
    gui::AddAppFolder Code $launcherName
    # gui::AddFavoriteApp    $launcherName
    gui::SetAppProp        $launcherName StartupWMClass sublime_text
    gui::SetAppIcon        $launcherName sublime-text-3

    ln -s /opt/sublime_text/sublime_text /usr/local/bin/

    gui::AddKeybinding editor "<Super>e" \
        'bash -c "f=0 ; for i in $( xdotool search --class sublime_text ) ; do r=$( xdotool windowactivate $i 2>&1) ; [[ ${#r} -eq 0 ]] && f=1 && break ; done ; [[ $f -eq 0 ]] && subl"'
    gui::AddKeybinding editor-new  "<Shift><Super>e"      'subl --new-window'
    gui::AddKeybinding editor-root "<Primary><Super>e"    'bash -c "pkexec subl; sleep 2"'


    # MIME: Register text/plain & others
    gui::SetDefaultAppForMimetypes $launcherName \
        text/plain \
        application/x-shellscript \
        text/comma-separated-values \
        text/x-comma-separated-values \
        text/csv \
        text/x-csv \
        text/tab-separated-values \
        text/english \
        text/css \
        text/html \
        text/xml \
        text/markdown \
        application/javascript \
        application/xhtml+xml \
        application/xml \
        text/x-c \
        text/x-c++ \
        text/x-chdr \
        text/x-c++hdr \
        text/x-csrc \
        text/x-c++src \
        text/x-java \
        text/x-makefile \
        text/x-moc \
        text/x-pascal \
        text/x-python \
        text/x-tcl \
        text/x-tex

    local tempdir=$( mktemp -d )


    # Theme & Color Scheme: Afterglow
    # DEV: cannot preseed color schemes using "installed_packages"
    # WORKAROUND: manual install
    net::Download "https://github.com/YabataDesign/afterglow-theme/archive/master.zip" \
        $tempdir/master.zip

    unzip $tempdir/master.zip "afterglow-theme-master/*" -d "$tempdir"

    mkdir -p "$HOME/.config/sublime-text-3/Packages/Theme - Afterglow"
    mv "$tempdir/afterglow-theme-master"/* "$HOME/.config/sublime-text-3/Packages/Theme - Afterglow"
    sys::Chk
    rm -rf $tempdir

    # PATCH Afterglow bg,caret,fg,selection colors
    sys::XmlstarletInline \
        "$HOME/.config/sublime-text-3/Packages/Theme - Afterglow/Afterglow.tmTheme" \
        --update '(/plist/dict/array/dict/dict/string)[1]' \
        --value "#$THEME_COLOR_BACKGD_HEX" \
        --update '(/plist/dict/array/dict/dict/string)[2]' \
        --value "#$THEME_COLOR_HOTHOT_HEX" \
        --update '(/plist/dict/array/dict/dict/string)[3]' \
        --value "#$THEME_COLOR_FOREGD_HEX" \
        --update '(/plist/dict/array/dict/dict/string)[6]' \
        --value "#${THEME_COLOR_SELECT_HEX}80"

    # Package Control
    # TIP packagecontrol: https://packagecontrol.io/channel_v3.json
    local tempzip=$( mktemp )
    mkdir -p "$HOME/.config/sublime-text-3/Installed Packages"
    net::Download \
        "https://packagecontrol.io/Package%20Control.sublime-package" "$tempzip"
    unzip "$tempzip" -d "$HOME/.config/sublime-text-3/Packages/Package Control/"
    sys::Chk
    rm -rf "$tempzip"

    # Install packages DOC http://stackoverflow.com/a/19531651
    local userPackages=$HOME/.config/sublime-text-3/Packages/User

    sys::Write <<'EOF' "$userPackages/Package Control.sublime-settings"
{
    "auto_upgrade": true,
    "http_cache": false,
    "submit_usage": false,
    "installed_packages":
    [

    // System features
        "ReadmePlease",
        "PackageResourceViewer",
        "Open Folder",
        "Open in Nautilus",
        "Open URL",
        "Open in Relevant Window",
        "Terminal",
        "File History",
        "File Rename",
        "SideBarEnhancements",
        "SyncedSideBar",

    // Text features
// BROKEN        "BracketHighlighter",
        "Color Highlighter",
        "WordHighlight",
        "AlignTab",
        "GotoLastEditEnhanced",
        "TrailingSpaces",

    // Text formats
        "Advanced CSV",
        "Markmon real-time markdown preview",
        "MarkdownEditing",
        "Table Editor",
// BROKEN        "HexViewer",
        "INI",
        "Pretty JSON",
        "Pretty YAML",
        "IndentX",

    // Devel features
        "EditorConfig",
        "FileDiffs",
        "Function Name Display",
        "GitSavvy",
        "GithubEmoji",
        "SublimeCodeIntel",
        "SublimeREPL",
        "Zeal",

    // Devel Linting
        "SublimeLinter",
        "SublimeLinter-annotations",
        "SublimeLinter-mdl",
        "SublimeLinter-html-tidy",
        "SublimeLinter-json",
        "SublimeLinter-contrib-yamllint",

    // Devel Linting: languages
        "SublimeLinter-golint",
        "SublimeLinter-gotype",
        "SublimeLinter-eslint",
        "SublimeLinter-contrib-scss-lint",
        "SublimeLinter-contrib-sqlint",
        "SublimeLinter-csslint",
        "SublimeLinter-php",
        "SublimeLinter-pylint",
        "SublimeLinter-ruby",
        "SublimeLinter-shellcheck",

    // Devel enhanced languages
        "Dockerfile Syntax Highlighting",
        "HTML-CSS-JS Prettify",
        "JsFormat",
        "Sass",
        "ShellScriptImproved",
        "SqlBeautifier"
    ]
}
EOF


# DEPRACATED "GitGutter",
# https://github.com/jisaacks/GitGutter/issues/543#issuecomment-473677350
# // "Babel",      // Syntax definitions for ES6 JavaScript with React JSX extensions.
# //        "Shell Turtlestein",
# // BROKEN?? "Superlime",
# // BUGGY "Open Search in a New Tab",
# // BUGGY "Log Highlight",
# // BUGGY "Save Copy As",
# UNUSED slow "SidebarHoverToggle", "MouseEventListener",

    # TOCHECK a lot of stuff
    # https://github.com/yveskaufmann/devdocs-sublime
    # https://github.com/kylebebak/sublime_text_config
    # http://kylebebak.github.io/post/useful-packages
    # http://kylebebak.github.io/post/auto-save

# TODO
# BetterFindBuffer + colorscheme
# ToggleQuotes
# Gitignored File Excluder
# All Autocomplete
# Emmet
# Hayaku
# ApplySyntax
# Better CoffeeScript
# Python Improved
# Java​Script​Next - ES6 Syntax vs. Babel
# MarkdownHighlighting
# Colorcoder https://packagecontrol.io/packages/Colorcoder
# https://github.com/shagabutdinov/sublime-autocompletion

# TOCHECK
# https://github.com/bordaigorl/sublime-external-diff
# https://packagecontrol.io/packages/EasyDiff
# https://packagecontrol.io/packages/Local%20History
# "ShellCommand"
# "File​System Autocompletion"
# "Non Text Files"
# "Locate"
# https://github.com/dreki/sublime-extract-to-file



    # Remove comments
    sed -i -E 's#^\s*//.*##' "$userPackages/Package Control.sublime-settings"


    # DEPS Linters
    gog::Install golang.org/x/tools/cmd/gotype golang.org/x/lint/golint # github.com/golang/lint/golint
    pip::Install yamllint pylint sqlparse jsbeautifier
    gem::Install mdl scss_lint sqlint
    npm::Install eslint csslint
    apt::AddPpaPackages ondrej/php tidy
    apt::AddPackages shellcheck


    # CONF: default keybindings
    sys::Write <<EOF "$userPackages/Default (Linux).sublime-keymap"
[
    { "keys": ["ctrl+shift+o"], "command": "prompt_open_folder" },
]
EOF

    # CONF: default prefs
    sys::Write <<EOF "$userPackages/Preferences.sublime-settings"
{
    "hot_exit": false,
    "remember_open_files": false,
    "translate_tabs_to_spaces": true,
    "tab_size": 4,
    "rulers": [80],
    "always_show_minimap_viewport": true,
    "show_full_path": true,
    "font_size": $THEME_FONT_FIXED_SIZE.3,
    "font_face": "$THEME_FONT_FIXED_NAME",
    "color_scheme": "Packages/Theme - Afterglow/Afterglow.tmTheme",
    "theme": "Afterglow-orange.sublime-theme",
    "tabs_small": true,

    "highlight_line": true,
    "caret_extra_width": 1,
    "caret_style": "phase",
    "drag_text": false,
    "word_wrap": false,
    "fade_fold_buttons": false,
    "bold_folder_labels": true,
    "scroll_past_end": false,

    "update_check": false,
    "ignored_packages": [ "Vintage", "Markdown" ],

    "folder_exclude_patterns": ["node_modules", "target", ".sass-cache", ".svn", ".git", ".hg", "CVS"],
    "file_exclude_patterns": ["*.pyc", "*.pyo", "*.exe", "*.dll", "*.obj","*.o", "*.a", "*.lib", "*.so", "*.dylib", "*.ncb", "*.sdf", "*.suo", "*.pdb", "*.idb", ".DS_Store", "*.class", "*.psd", "*.db", "*.sublime-workspace"],
    "binary_file_patterns": ["generated/*", "*.tbz2", "*.gz", "*.gzip", "*.jar", "*.zip", "*.jpg", "*.jpeg", "*.png", "*.gif", "*.ttf", "*.tga", "*.dds", "*.ico", "*.eot", "*.pdf", "*.swf"]

}
EOF

# // TOCHECK
# //    "scroll_speed": 5.0,
# //    "line_padding_bottom": 1,
# //    “wide_caret”: true,

# // Destructive
# //    "ensure_newline_at_eof_on_save": true,
# //    "trim_trailing_white_space_on_save": true,

# // Opinionated
# //    "enable_tab_scrolling": false,
# //    "open_files_in_new_window": false,
# //    "preview_on_click": false,


    # PATCH colors Afterglow-markdown.tmTheme
    sys::XmlstarletInline \
        "$HOME/.config/sublime-text-3/Packages/Theme - Afterglow/Afterglow-markdown.tmTheme" \
        --update '(/plist/dict/array/dict/dict/string)[1]' \
        --value "#$THEME_COLOR_BACKGD_HEX" \
        --update '(/plist/dict/array/dict/dict/string)[2]' \
        --value "#$THEME_COLOR_FOREGD_HEX"
        # --update '(/plist/dict/array/dict/dict/string)[6]' \
        # --value "#$THEME_COLOR_SELECT_HEX" \


    # Restore Afterglow over MarkdownEditing Markdown syntax-specific theme
    sys::Write <<'EOF' "$userPackages/Markdown.sublime-settings"
{
    // "line_padding_top": 2,
    // "line_padding_bottom": 2,
    "color_scheme": "Packages/Theme - Afterglow/Afterglow-markdown.tmTheme",
    "enable_table_editor": true,
    "wrap_width": 0,
    "draw_centered": false,
    "line_numbers": true,
    "tab_size": 4,
}
EOF
    cp "$userPackages/Markdown.sublime-settings" "$userPackages/MultiMarkdown.sublime-settings"
    cp "$userPackages/Markdown.sublime-settings" "$userPackages/Markdown GFM.sublime-settings"


    # THEME Afterglow-orange customization
    local agoTheme=/usr/share/themes/$THEME_GS/sublime-text/Afterglow-orange.sublime-theme
    if [[ -f "$agoTheme" ]] ; then
        cp -v "$agoTheme" "$userPackages/Afterglow-orange.sublime-theme"
        sys::Chk
    fi


    # EXT: Zeal
    sys::Write <<'EOF' "$userPackages/Zeal.sublime-settings"
{
  "zeal_command": "/usr/local/bin/zeal",
  "language_mapping": {
    "C": {"lang": "c", "zeal_lang": "c"},
    "C++": {"lang": "c", "zeal_lang": "c++"},
    "CSS": {"lang": "css", "zeal_lang": "css"},
    "Dockerfile": {"lang": "dockerfile", "zeal_lang": "docker"},
    "Go": {"lang": "go", "zeal_lang": "go"},
    "HTML": {"lang": "html", "zeal_lang": "html"},
    "JavaScript": {"lang": "javascript", "zeal_lang": "javascript"},
    "NodeJS": {"lang": "javascript", "zeal_lang": "nodejs"},
    "PHP": {"lang": "php", "zeal_lang": "php"},
    "Python": {"lang": "python", "zeal_lang": "python"},
    "Ruby": {"lang": "ruby", "zeal_lang":"ruby"},
    "ShellScript Improved": {"lang": "shell", "zeal_lang": "bash"}
  }
}
EOF

    # EXT: SideBar
    sys::Write <<'EOF' "$userPackages/Side Bar.sublime-settings"
{
    "portable_browser": "browser",
    "i_donated_to_sidebar_enhancements_developer": "https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=DD4SL2AHYJGBW",
 }
EOF

    # EXT: SideBarEnhancements
    touch \
        $HOME/.SideBarEnhancements.optout \
        /root/.SideBarEnhancements.optout \
        /etc/skel/.SideBarEnhancements.optout
    chown -hR 1000:1000 $HOME/.SideBarEnhancements.optout


    # EXT: Word Highlight
    sys::Write <<'EOF' "$userPackages/Word Highlight.sublime-settings"
{
    "mark_occurrences_on_gutter" : true,
    "draw_outlined" : false,
}
EOF


    # # EXT: Shell Turtlestein
    # sys::Mkdir $HOME/.config/sublime-text-3/Packages/Shell Turtlestein

    # EXT: Terminal
    sys::Write <<'EOF' "$userPackages/Terminal.sublime-settings"
{
  "terminal": "/usr/local/bin/gnome-terminal",
  "parameters": ["--working-directory", "%CWD%"]
}
EOF

    # EXT: TrailingSpaces
    sys::Write <<'EOF' "$userPackages/trailing_spaces.sublime-settings"
{
    "trailing_spaces_modified_lines_only": true,
    "trailing_spaces_include_current_line": false,
    "trailing_spaces_include_empty_lines": false,
}
EOF

    # EXT: HTML-CSS-JS Prettify
    sys::Write <<'EOF' "$userPackages/HTMLPrettify.sublime-settings"
{
  "node_path": { "linux": "node" }
}
EOF

#     # EXT: GitGutter vs SublimeLinter
#     sys::Write <<'EOF' "$userPackages/GitGutter.sublime-settings"
# {
#     "protected_regions": [
#         "sublimelinter-warning-marks",
#         "sublimelinter-error-marks",
#         "sublimelinter-warning-gutter-marks",
#         "sublimelinter-error-gutter-marks",
#         "lint-underline-illegal",
#         "lint-underline-violation",
#         "lint-underline-warning",
#         "lint-outlines-illegal",
#         "lint-outlines-violation",
#         "lint-outlines-warning",
#         "lint-annotations",
#     ]
# }
# EOF

    # EXT: Markmon real-time markdown preview
    gem::Install kramdown kramdown-parser-gfm rouge:'\<2'
    npm::Install markmon

    # FIX missing default config
    sys::Write <<EOF "$userPackages/sublime-text-markmon.sublime-settings"
{
  "command": "kramdown -i kramdown -o html --syntax_highlighter rouge",
  "stylesheet": "$userPackages/sublime-text-markmon.css"
}
EOF
    # OLD "command": "kramdown -i GFM -o html --syntax_highlighter rouge",
    # BUG: kramdown-parser-gfm lib seems not used by kramdown cli for now
    # BUG: SECURITY ISSUE: https://github.com/yyjhao/markmon/issues/19
    # markmon listens on *ALL* interfaces, not just loopback

    ## CSS: Markdown style
      net::Download \
        "https://raw.githubusercontent.com/revolunet/sublimetext-markdown-preview/master/css/markdown.css" \
    | sed -E 's/\.markdown-body/.content/' \
    > "$userPackages/sublime-text-markmon.css"
        # "https://raw.githubusercontent.com/revolunet/sublimetext-markdown-preview/master/markdown.css" \

    ## CSS: Highlight style -> rouge(pygments)
      net::Download \
        "https://raw.githubusercontent.com/aahan/pygments-github-style/master/jekyll-github.css" \
    >> "$userPackages/sublime-text-markmon.css"
    # ALT rougify style base16.solarized.dark >> "$userPackages/sublime-text-markmon.css"
    # TIP php without tag: ```php?start_inline=1


    # EXT: Color Highlighter
    sys::Write <<EOF "$userPackages/ColorHighlighter.sublime-settings"
{
  "search_colors_in":
  {
    "all_content":
    {
      "color_highlighters":
      {
        "color_scheme":
        {
          "enabled": true,
          "highlight_style": "filled"
        },
        "gutter_icons":
        {
          "enabled": false
        },
        "phantoms":
        {
          "enabled": false
        }
      },
      "enabled": true
    },
    "hover":
    {
      "color_highlighters":
      {
        "color_scheme":
        {
          "enabled": true,
          "highlight_style": "filled"
        },
        "gutter_icons":
        {
          "enabled": false,
        },
        "phantoms":
        {
          "enabled": false,
        }
      },
      "enabled": true
    },
    "selection":
    {
      "color_highlighters":
      {
        "color_scheme":
        {
          "enabled": false,
          "highlight_style": "outlined"
        },
        "gutter_icons":
        {
          "enabled": false,
          "icon_style": "square"
        },
        "phantoms":
        {
          "enabled": true,
          "length": 2,
          "style": "left"
        }
      },
      "enabled": true
    }
  }
}
EOF

    # EXT: .desktop syntax FROM https://github.com/sctthrvy/desktop-sublime-syntax
    net::Download "https://raw.githubusercontent.com/sctthrvy/desktop-sublime-syntax/master/Desktop.tmLanguage" \
        "$userPackages/"


    # EXT: Git GUI Clients, GitKraken branch
    if str::InList app::Gitkraken_NONFREE $INSTALL_BUNDLES ; then
        net::DownloadGithubFiles \
            --branch GitKraken  thgreasi/SublimeText-Git-GUI-Clients \
            "$HOME/.config/sublime-text-3/Packages/Git GUI Clients/"
    fi



    # 'subl' helper: Inject env launcher
    mkdir -p $HOME/.config/sublime-text-3/env.d
    sys::Write <<'EOF' "/usr/local/bin/subl"  0:0 755
#!/bin/bash

# DEV: Source sublime env.d parts

ENVD_PATH=~/.config/sublime-text-3/env.d

shopt -s extglob
if ! pgrep --uid $USER -x sublime_text &>/dev/null \
&&  [[ -d "$ENVD_PATH" && "$( id -u )" != "0" ]] ; then
    for i in "$ENVD_PATH"/!(*.disabled) ; do source "$i"; done
fi

exec /opt/sublime_text/sublime_text "$@"
EOF
# LC_COLLATE="en_AU.UTF-8" exec /opt/sublime_text/sublime_text "$@"

    gui::SetAppProp $launcherName Exec /usr/local/bin/subl

    # pkexec
    gui::AddPkexecPolicy \
        /usr/local/bin/subl \
        com.sublimetext.3

    ## env.d: nvm
       [[ -f "$HOME/.nvm/nvm.sh" ]] \
    && sys::Write <<'EOF' "$HOME/.config/sublime-text-3/env.d/nvm"
# NVM support
   [[ -z "$NVM_DIR" ]] \
&& [[ -f "$HOME/.nvm/nvm.sh" ]] \
&& source "$HOME/.nvm/nvm.sh"
EOF

    ## env.d: rvm
       [[ -f "/etc/profile.d/rvm.sh" ]] \
    && sys::Write <<'EOF' "$HOME/.config/sublime-text-3/env.d/rvm"
# RVM support
   [[ -z "$RUBY_VERSION" ]] \
&& [[ -f "/etc/profile.d/rvm.sh" ]] \
&& source "/etc/profile.d/rvm.sh"
EOF

    ## env.d: gvm
       [[ -f "$HOME/.gvm/scripts/gvm" ]] \
    && sys::Write <<'EOF' "$HOME/.config/sublime-text-3/env.d/gvm"
# GVM support
   [[ -z  "$GVM_ROOT" ]] \
&& [[ -f  "$HOME/.gvm/scripts/gvm" ]] \
&& source "$HOME/.gvm/scripts/gvm"
EOF


    # Git editor: keep new window process
    sudo --set-home -u \#1000 git config --global core.editor "subl --multiInstance --new-window --wait"


    # SLAP https://github.com/slap-editor/slap
    # WORKAROUND: use cancerberoSgx fork
    npm::Install -g git+https://github.com/cancerberoSgx/slap.git
    sys::Write <<'EOF' /usr/local/bin/slap 0:0 755
#!/bin/bash
[[ -d $NVM_BIN ]] || source ~/.nvm/nvm.sh &>/dev/null
[[ -x $NVM_BIN/slap ]] && exec slap "$@"
echo "Failed to reach NVM"
EOF
    # 'e': cli helper supporting PIPE
    sys::Write <<'EOF' /usr/local/bin/e 0:0 755
#!/bin/bash
# DESC Sublime Text wrapper with PIPE support

# Config
EDIT_CLI=slap # vi
EDIT_GUI="subl"
EDIT=$EDIT_CLI
TIMEOUT_CLI=5
TIMEOUT_GUI=1
TIMEOUT=$TIMEOUT_CLI

# GUI detect
   pstree -As $$ \
|  grep -q -E -- \
    '---(gnome-shell|xterm|konsole|gnome-terminal|terminator|tilix|meld)---' \
&& EDIT=$EDIT_GUI \
&& TIMEOUT=$TIMEOUT_GUI

# UNUSED # FIREJAIL support via dbus
# if pstree -As $$ | grep -q -E -- '^firejail---' ; then
#     EDIT=$EDIT_GUI
#     dbus-send --print-reply --session --dest="com.sublimetext" /com/sublimetext com.sublimetext.start
#     sleep .5
# fi

# Default
[[ -t 0 ]] && exec $EDIT "$@"

# Piped to CLI
# [[ "$EDIT" == "$EDIT_CLI" ]] && exec "$EDIT" "$@" -

# Piped to GUI
DEST=/tmp/e.$( id -u )
mkdir -p "$DEST"                     # DEV: user-wide dir
DEST=$( mktemp -d -p "$DEST" 'XXX' ) # DEV: 2-level depth prevents saving
FILE=$( mktemp    -p "$DEST" 'XXX' )
trap 'rm -rf -- "'"$DEST"'"' EXIT    # DEV: supports canceling with ^C
cat >"$FILE"
nohup bash -c 'sleep '$TIMEOUT' ; rm -rf -- "'"$DEST"'"' \
    >/dev/null 2>/dev/null </dev/null &
trap - EXIT
[[ -s "$FILE" ]] && exec $EDIT "$FILE" "$@"
exec $EDIT "$@"
EOF

# UNUSED
#     # 'e': register dbus service
#     sys::Write <<'EOF' /usr/share/dbus-1/services/com.sublimetext.service
# [D-BUS Service]
# Name=com.sublimetext
# Exec=/usr/local/bin/dbus-start-subl
# EOF
#     sys::Write <<'EOF' /usr/local/bin/dbus-start-subl 0:0 755
# #!/usr/bin/env python3

# import os
# from gi.repository import Gtk
# import dbus
# import dbus.service
# from dbus.mainloop.glib import DBusGMainLoop

# class SublService(dbus.service.Object):
#     def __init__(self):
#         bus_name = dbus.service.BusName('com.sublimetext', bus=dbus.SessionBus())
#         dbus.service.Object.__init__(self, bus_name, '/com/sublimetext')

#     @dbus.service.method('com.sublimetext')
#     def start(self):
#         Gtk.main_quit()   # Terminate after running. Daemons don't use this.
#         os.system('subl --background')
#         return "Started!"

# DBusGMainLoop(set_as_default=True)
# myservice = SublService()
# Gtk.main()
# EOF


    # User
    chown -hR 1000:1000 $HOME/.config/sublime-text-3 # $HOME/.codeintel


    # DEV: Run several times to download & install all packages
    apt::AddPackages xfwm4

    # WORKAROUND: "Unable to init shm"
    chmod 777 /dev/shm

    # WORKAROUND: blocking update prompt prevents packages installation
    sys::Write --append <<'EOF' /etc/hosts
127.0.0.1 sublimetext.com www.sublimetext.com download.sublimetext.com sublimehq.com telemetry.sublimehq.com license.sublimehq.com #DISABLE_SUBLIME_UPDATES
EOF

    # WORKAROUND: Package Control issues
    # TIP: missing deps repo https://github.com/wbond/package_control_channel/blob/master/repository/dependencies.json

    # WORKAROUND: missing dep pyyaml
    # net::DownloadGithubFiles packagecontrol/pyyaml \
    #     "$HOME/.config/sublime-text-3/Packages/pyyaml"/
    # # DOC : https://packagecontrol.io/docs/dependencies
    # sys::Touch "$HOME/.config/sublime-text-3/Packages/pyyaml/.sublime-package"

    # # WORKAROUND: missing dep numpy
    # net::DownloadGithubFiles komsit37/sublime-numpy \
    #     "$HOME/.config/sublime-text-3/Packages/numpy"/
    # sys::Touch "$HOME/.config/sublime-text-3/Packages/numpy/.sublime-package"

    # # WORKAROUND: https://github.com/wbond/package_control/issues/1430
    # # HARDCODED: missing python-jinja2
    # local tmpzip=$( mktemp )
    # local tmpdir=$( mktemp -d )
    # net::Download \
    #     "https://bitbucket.org/teddy_beer_maniac/sublime-text-dependency-jinja2/get/0f764ff20f33.zip" \
    #     "$tmpzip"
    # unzip "$tmpzip" -d "$tmpdir"
    # sys::Chk
    # sys::Mkdir "$HOME/.config/sublime-text-3/Packages/python-jinja2"
    # cp -R "$tmpzip/teddy_beer_maniac-sublime-text-dependency-jinja2-0f764ff20f33/all" \
    #     "$HOME/.config/sublime-text-3/Packages/python-jinja2"
    # chown -hR 1000:1000 "$HOME/.config/sublime-text-3/Packages/python-jinja2"
    # rm -rf "$tmpdir" "$tmpzip"
    # # HARDCODED: missing markupsafe
    # local tmpzip=$( mktemp )
    # local tmpdir=$( mktemp -d )
    # net::Download \
    #     "https://bitbucket.org/teddy_beer_maniac/sublime-text-dependency-markupsafe/get/ae155c4a5704.zip" \
    #     "$tmpzip"
    # unzip "$tmpzip" -d "$tmpdir"
    # sys::Chk
    # sys::Mkdir "$HOME/.config/sublime-text-3/Packages/markupsafe"
    # cp -R "$tmpzip/teddy_beer_maniac-sublime-text-dependency-markupsafe-ae155c4a5704/all" \
    #     "$HOME/.config/sublime-text-3/Packages/markupsafe"
    # chown -hR 1000:1000 "$HOME/.config/sublime-text-3/Packages/markupsafe"
    # rm -rf "$tmpdir" "$tmpzip"

    # First run for deps
# cat "$userPackages/Package Control.sublime-settings" # DBG
    gui::XvfbXfwmRunClose 30 /opt/sublime_text/sublime_text -w
    sys::JqInline '.ignored_packages |= ["Markdown","Vintage"]' "$userPackages/Preferences.sublime-settings"
sys::Jq '.ignored_packages' "$userPackages/Preferences.sublime-settings" # DBG
cat "$userPackages/Package Control.sublime-settings" # DBG

    # Multiple runs for package manager
    local retry=0 processingCount=1
    while [[ $retry -le 5 ]] && [[ "$processingCount" -ne 0 ]] ; do
        gui::XvfbXfwmRunClose 90 /opt/sublime_text/sublime_text -w
sys::Jq '.ignored_packages' "$userPackages/Preferences.sublime-settings" # DBG
        sys::JqInline '.ignored_packages |= ["Markdown","Vintage"]' "$userPackages/Preferences.sublime-settings"
cat "$userPackages/Package Control.sublime-settings" # DBG
        retry=$(( $retry + 1 ))
        processingCount=$(
          sed -E 's#^\s*//.*##' "$userPackages/Package Control.sublime-settings" \
        | sys::Jq '.in_process_packages|length'
        )
    done

    apt::RemovePackages xfwm4

    # WORKAROUND: blocking update prompt
    sed -i -E '/#DISABLE_SUBLIME_UPDATES$/d' /etc/hosts
    sys::Chk

    # Remove sessions
    rm -rfv \
        "$HOME/.config/sublime-text-3/Local/"*.sublime_session \
        "$userPackages/"FileHistory*.json

    # Root
    mkdir -p /root/.config
    cp -R $HOME/.config/sublime-text-3 /root/.config/sublime-text-3

    ## Root: Afterglow caret color
    sys::XmlstarletInline \
        "/root/.config/sublime-text-3/Packages/Theme - Afterglow/Afterglow.tmTheme" \
        --update '(/plist/dict/array/dict/dict/string)[2]' \
        --value "#$THEME_COLOR_MANAGE_HEX"

    ## Root: Remove some packages that shouldn't fork as root
    ## DEV: Terminal BUG: "%CWD%" is not replaced as root
    ## DEV: Git GUI Clients: should not launch gitkraken as root
    ## DEV: Markmon real-time markdown preview: should not launch as root
    for i in \
      "Packages/Terminal" \
      "Packages/Git GUI Clients" \
      "Installed Packages/Markmon real-time markdown preview.sublime-package" \
    ; do
      sys::JqInline '.installed_packages|= .-["'"$( basename "$i" .sublime-package )"'"]' "/root/.config/sublime-text-3/Packages/User/Package Control.sublime-settings"
      rm -rfv "/root/.config/sublime-text-3/$i"
    done
}



app::SublimeMerge_NONFREE ()
{
    Meta --desc "Git client" \
         --no-default true

    apt::AddRemotePackages \
        https://download.sublimetext.com/sublime-merge_build-1111_amd64.deb
    gui::AddAppFolder Code sublime_merge

    # launchers
    ln -s /opt/sublime_merge/sublime_merge /usr/local/bin/
    sys::Write <<'EOF' "/usr/share/gnome/file-manager/actions/git.desktop"
[Desktop Entry]
Type=Action
TargetLocation=true
Icon=sublime_merge
Name=Git
Profiles=profile-zero;

[X-Action-Profile profile-zero]
Exec=sublime_merge --new-window %f
Name=default
ShowIfTrue=find "%f" -maxdepth 1 -type d -name ".git" -printf "true"
SelectionCount==1
EOF

    # icon
    gui::SetAppIcon sublime_merge sublime_merge
    sys::Write <<'EOF' "/usr/share/icons/$THEME_ICON/48/apps/sublime_merge.svg"
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg
   xmlns:dc="http://purl.org/dc/elements/1.1/"
   xmlns:cc="http://creativecommons.org/ns#"
   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
   xmlns:svg="http://www.w3.org/2000/svg"
   xmlns="http://www.w3.org/2000/svg"
   xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd"
   xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"
   version="1.1"
   viewBox="0 0 48 48"
   id="svg6814"
   sodipodi:docname="sublime-merge.svg"
   inkscape:version="0.92.3 (2405546, 2018-03-11)">
  <metadata
     id="metadata6818">
    <rdf:RDF>
      <cc:Work
         rdf:about="">
        <dc:format>image/svg+xml</dc:format>
        <dc:type
           rdf:resource="http://purl.org/dc/dcmitype/StillImage" />
        <dc:title></dc:title>
      </cc:Work>
    </rdf:RDF>
  </metadata>
  <sodipodi:namedview
     pagecolor="#ffffff"
     bordercolor="#666666"
     borderopacity="1"
     objecttolerance="10"
     gridtolerance="10"
     guidetolerance="10"
     inkscape:pageopacity="0"
     inkscape:pageshadow="2"
     inkscape:window-width="1920"
     inkscape:window-height="1144"
     id="namedview6816"
     showgrid="false"
     inkscape:zoom="4.703125"
     inkscape:cx="16.533517"
     inkscape:cy="29.811999"
     inkscape:window-x="0"
     inkscape:window-y="28"
     inkscape:window-maximized="1"
     inkscape:current-layer="svg6814" />
  <defs
     id="defs6790">
    <linearGradient
       id="linearGradient842"
       x1="1"
       x2="47"
       y1="24"
       y2="24"
       gradientUnits="userSpaceOnUse">
      <stop
         style="stop-color:#404040"
         offset="0"
         id="stop6785" />
      <stop
         style="stop-color:#4d4d4d"
         offset="1"
         id="stop6787" />
    </linearGradient>
  </defs>
  <path
     d="m36.31 5c5.859 4.062 9.688 10.831 9.688 18.5 0 12.426-10.07 22.5-22.5 22.5-7.669 0-14.438-3.828-18.5-9.688 1.037 1.822 2.306 3.499 3.781 4.969 4.085 3.712 9.514 5.969 15.469 5.969 12.703 0 23-10.298 23-23 0-5.954-2.256-11.384-5.969-15.469-1.469-1.475-3.147-2.744-4.969-3.781zm4.969 3.781c3.854 4.113 6.219 9.637 6.219 15.719 0 12.703-10.297 23-23 23-6.081 0-11.606-2.364-15.719-6.219 4.16 4.144 9.883 6.719 16.219 6.719 12.703 0 23-10.298 23-23 0-6.335-2.575-12.06-6.719-16.219z"
     style="opacity:.05"
     id="path6792" />
  <path
     d="m41.28 8.781c3.712 4.085 5.969 9.514 5.969 15.469 0 12.703-10.297 23-23 23-5.954 0-11.384-2.256-15.469-5.969 4.113 3.854 9.637 6.219 15.719 6.219 12.703 0 23-10.298 23-23 0-6.081-2.364-11.606-6.219-15.719z"
     style="opacity:.1"
     id="path6794" />
  <path
     d="m31.25 2.375c8.615 3.154 14.75 11.417 14.75 21.13 0 12.426-10.07 22.5-22.5 22.5-9.708 0-17.971-6.135-21.12-14.75a23 23 0 0 0 44.875-7 23 23 0 0 0-16-21.875z"
     style="opacity:.2"
     id="path6796" />
  <g
     transform="matrix(0,-1,1,0,0,48)"
     style="fill:#501616"
     id="g6800">
    <path
       d="m24 1c12.703 0 23 10.297 23 23s-10.297 23-23 23-23-10.297-23-23 10.297-23 23-23z"
       style="fill:url(#linearGradient842)"
       id="path6798" />
  </g>
  <path
     d="m40.03 7.531c3.712 4.084 5.969 9.514 5.969 15.469 0 12.703-10.297 23-23 23-5.954 0-11.384-2.256-15.469-5.969 4.178 4.291 10.01 6.969 16.469 6.969 12.703 0 23-10.298 23-23 0-6.462-2.677-12.291-6.969-16.469z"
     style="opacity:.1"
     id="path6802" />
  <g
     id="g36357">
    <path
       inkscape:connector-curvature="0"
       id="path36335"
       d="m 16.025176,21.644986 c -2.278436,-1.599984 -4.195482,-2.988688 -4.260099,-3.086013 -0.06494,-0.09783 -0.09213,-0.256845 -0.06082,-0.355629 0.04656,-0.14682 3.856021,-5.672124 4.044203,-5.865835 0.03165,-0.03255 0.158563,-0.08417 0.282013,-0.114623 0.193019,-0.04763 1.047875,0.520423 6.106412,4.057676 3.235083,2.262176 5.939451,4.168583 6.009705,4.236456 0.110338,0.106588 -0.03403,0.123399 -1.059866,0.123399 h -1.1876 l -2.807089,1.962775 c -1.543905,1.079529 -2.833462,1.960097 -2.865692,1.956817 -0.03222,-0.0033 -1.922765,-1.315046 -4.2012,-2.915023 z"
       style="fill:#86d7d8;stroke-width:0.0872345" />
    <path
       inkscape:connector-curvature="0"
       id="path36333"
       d="M 15.826198,37.018693 C 15.578179,36.830965 11.66242,31.16686 11.66242,30.995836 c 0,-0.08932 0.107956,-0.268185 0.239893,-0.397485 0.131946,-0.129292 2.006394,-1.465773 4.165452,-2.969956 2.159049,-1.504184 3.990142,-2.807858 4.069082,-2.897049 0.07895,-0.08919 1.403693,-1.043293 2.94389,-2.120226 l 2.800342,-1.958061 4.907225,0.04615 4.907217,0.04615 1.853731,1.849009 c 1.384888,1.381361 1.853739,1.901965 1.853739,2.058369 0,0.15601 -0.471595,0.682811 -1.851052,2.067715 l -1.851053,1.858371 H 32.19269 c -1.929498,0 -3.60028,0.03502 -3.712843,0.07779 -0.112563,0.04277 -2.84579,1.926977 -6.073844,4.187059 -3.228054,2.260091 -5.942707,4.148591 -6.032558,4.196685 -0.217436,0.11637 -0.373075,0.110222 -0.547247,-0.02159 z"
       style="fill:#00e4e5;stroke-width:0.0872345" />
  </g>
</svg>
EOF
}



app::Dbeaver ()
{
    Meta --desc "Universal database manager" \
         --no-default true

    # DEAD free EE version
    # apt::AddRemotePackages \
    #     "http://dbeaver.jkiss.org/files/dbeaver-ee_latest_amd64.deb"
    #     # "http://dbeaver.com/files/dbeaver-ee_latest_amd64.deb"
    net::InstallGithubLatestRelease dbeaver/dbeaver '/dbeaver-ce_.*_amd64\\.deb$'
    gui::AddAppFolder Code dbeaver
    gui::SetAppIcon dbeaver dbeaver
    gui::SetAppName dbeaver DBeaver


    # Theming Test/production colors
    sys::Write <<EOF "$HOME/.dbeaver4/.metadata/.plugins/org.eclipse.core.runtime/.settings/org.eclipse.e4.ui.css.swt.theme.prefs" 1000:1000
eclipse.preferences.version=1
themeid=org.eclipse.e4.ui.css.theme.e4_dark
EOF
    sys::Write <<EOF "$HOME/.dbeaver4/.metadata/.plugins/org.jkiss.dbeaver.core/connection-types.xml" 1000:1000
<?xml version="1.0" encoding="UTF-8"?>
<types>
    <type id="dev" name="Development" color="255,255,255" description="Regular development database" autocommit="true" confirmExecute="false"/>
    <type id="test" name="Test" color="$THEME_COLOR_OKOKOK_RGB" description="Test (QA) database" autocommit="true" confirmExecute="false"/>
    <type id="prod" name="Production" color="$THEME_COLOR_MANAGE_RGB" description="Production database" autocommit="false" confirmExecute="true"/>
</types>
EOF
}



app::Insomnia ()
{
    Meta --desc "REST client" \
         --no-default true

    apt::AddSource insomnia \
            "https://dl.bintray.com/getinsomnia/Insomnia" \
            "/" \
            "https://insomnia.rest/keys/debian-public.key.asc"
    apt::AddPackages insomnia
    gui::AddAppFolder Code insomnia
}



app::Sqlitebrowser ()
{
    Meta --desc "SQLite browser" \
         --no-default true

    apt::AddPackages sqlitebrowser
    gui::AddAppFolder Code sqlitebrowser
    gui::SetAppName sqlitebrowser SQLite


    # THEMING
    sys::Write <<EOF "$HOME/.config/sqlitebrowser/sqlitebrowser.conf" 1000:1000
[databrowser]
null_bg_colour=@Variant(\0\0\0\x43\x1\xff\xff%%%%%%\0\0)
null_fg_colour=@Variant(\0\0\0\x43\x1\xff\xff\xc0\xc0\xc0\xc0\xc0\xc0\0\0)
null_text=NULL
EOF
}



app::Vscode ()
{
    Meta --desc "Code editor (Microsoft)" \
         --no-default true

    apt::AddSource vscode \
        "[arch=amd64] https://packages.microsoft.com/repos/vscode" \
        "stable main" \
        "https://packages.microsoft.com/keys/microsoft.asc"

    apt::AddPackages code # ALT code-insiders

    # FIX duplicate source
    rm /etc/apt/sources.list.d/vscode.src.list

    gui::SetAppName code "VS Code"
    gui::SetAppIcon code vscode
    gui::AddAppFolder Code code

    # CONF
    sys::Write <<'EOF' $HOME/.config/Code/User/settings.json
{
    "editor.fontFamily": "Hack",
    "editor.fontSize": 17,
    "editor.dragAndDrop": false,
    "telemetry.enableCrashReporter": false,
    "telemetry.enableTelemetry": false,
    "workbench.startupEditor": "newUntitledFile"
}
EOF
}



app::Gitkraken_NONFREE ()
{
    Meta --desc "Git client" \
         --no-default true

    # TIP: curl -sSL https://release.gitkraken.com/linux/RELEASES | jq -r .url_deb

    # WORKAROUND SSL cert issue
    local tempdeb=$( mktemp -d )
    net::Download --opts "-k" https://release.gitkraken.com/linux/gitkraken-amd64.deb "$tempdeb/0.deb"
    apt::AddLocalPackages "$tempdeb/0.deb"
    rm -rf "$tempdeb/"

    gui::AddAppFolder Code gitkraken

    # CONF
    sys::Write <<'EOF' $HOME/.gitkraken/config 1000:1000
{
  "keepGitConfigInSyncWithProfile": false,
  "optIntoAnalytics": false,
  "newUserSetup": {
    "askedAboutAnalytics": true,
    "askedAboutBugReporting": true
  },
  "optIntoBugReporting": false
}
EOF

    # FIX
    sys::Mkdir $HOME/.gitkraken/profiles
}



app::Meld ()
{
    Meta --desc "Diff viewer"

    # Installation
    apt::AddPackages meld # python-gtksourceview2
    gui::AddAppFolder Code meld

    # Configuration
    sys::Write <<EOF /usr/share/glib-2.0/schemas/$PRODUCT_NAME-meld.gschema.override
[org.gnome.meld]
highlight-current-line=true
highlight-syntax=true
indent-width=4
insert-spaces-instead-of-tabs=true
show-line-numbers=true
draw-spaces=['tab', 'trailing']
text-filters=[('CVS/SVN keywords', false, '\\$\\w+(:[^\\n$]+)?\\$'), ('C++ comment', false, '//.*'), ('C comment', false, '/\\*.*?\\*/'), ('All whitespace', false, '[ \\t\\r\\f\\v]*'), ('Leading whitespace', true, '^[ \\t\\r\\f\\v]*'), ('Trailing whitespace', false, '[ \\t\\r\\f\\v]*$'), ('Script comment', false, '#.*')]
EOF
# style-scheme='classic'

    # TODO ? SCRIPT org.gnome.meld.text-filters
    # DEV awk -F ', ' 'BEGIN{RS="\), \(" ; OFS=", "} $1~/Leading whitespace/{$2="true" ; $0=$0} NR>1{printf "), ("} {printf $0}'

    # Integration: nautilus
    if which nautilus &>/dev/null ; then
        apt::AddPackages nautilus-compare
        gui::HideApps nautilus-compare-preferences
        rm -f /var/lib/update-notifier/user.d/nautilus-compare-notification
    fi

    # Integration: git
    if which git &>/dev/null  ; then
        sys::Write --append <<'EOF' $HOME/.gitconfig 1000:1000 600

[merge]
    tool = meld

[mergetool]
    prompt = false

[mergetool "meld"]
    cmd = meld "$BASE $LOCAL $REMOTE $MERGED"
    trustExitCode = false

[diff]
    tool = meld

[difftool]
    prompt = false

[difftool "meld"]
    cmd = meld "$LOCAL $REMOTE"
EOF
    fi


    # Integration: Sublime
    local userPackages=$HOME/.config/sublime-text-3/Packages/User
    if [[ -d "$userPackages" ]] ; then
        sys::Write <<'EOF' "$userPackages/FileDiffs.sublime-settings" 1000:1000
{
    "cmd": ["meld", "$file1", "$file2"],
    "open_in_sublime": true
}
EOF
    sys::Write --append <<EOF /usr/share/glib-2.0/schemas/$PRODUCT_NAME-meld.gschema.override
use-system-editor=false
custom-editor-command='e {file}:{line}'
EOF
        glib-compile-schemas /usr/share/glib-2.0/schemas/
    fi
}



app::Zeal ()
{
    Meta --desc "Offline documentation browser" \
         --no-default true

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        # ALT 0.3.1 does NOT support DarkMode
        apt::AddPpaPackages zeal-developers/ppa zeal
        apt::AddPackages libqt5concurrent5 # runtime deps
        gui::AddAppFolder Code org.zealdocs.Zeal
    else
        apt::AddPackages zeal
        gui::AddAppFolder Code zeal
    fi

    # BUGFIX
    apt-get remove -f -y appmenu-qt5

    gui::AddKeybinding zeal "<Super>z" zeal

    sys::Write <<'EOF' /usr/local/bin/zeal 0:0 755
#!/bin/bash
# DESC: prevent launching zeal as root
grun /usr/bin/zeal "$@"
EOF

    # CONF
    sys::Write --append <<EOF $HOME/.config/Zeal/Zeal.conf 1000:1000
[General]
check_for_update=false
show_systray_icon=false

[content]
custom_css_file=$HOME/.config/Zeal/custom.css
dark_mode=true
default_font_family=sans-serif
disable_ad=true
fixed_font_family=$THEME_FONT_FIXED_NAME
minimum_font_size=$THEME_FONT_DEFAULT_SIZE
sans_serif_font_family=$THEME_FONT_SHORT_NAME

[internal]
install_id=ac58dbb1-cd64-4eee-b0b3-7177ccbf9f25
version=git

[search]
fuzzy_search_enabled=true
EOF
    sys::Write <<EOF $HOME/.config/Zeal/custom.css 1000:1000
/* TIP: DarkMode
html {
    -webkit-filter: invert() hue-rotate(180deg) contrast(70%);
    filter: invert() hue-rotate(180deg) contrast(70%);
}
html img {
    -webkit-filter: invert() hue-rotate(180deg) contrast(120%);
    filter: invert() hue-rotate(180deg) contrast(120%);
}
*/
body {
    background-color: white;
    font-family: $THEME_FONT_DEFAULT_NAME;
}
pre,code {
    font-family: $THEME_FONT_FIXED_NAME;
}
EOF

    # Download DOCSETS to .local/share/Zeal/Zeal/docset
    local ds=$HOME/.local/share/Zeal/Zeal/docsets
    mkdir -p $ds

    local reg=$( mktemp )
    net::Download "http://api.zealdocs.org/v1/docsets" "$reg"

    for i in Bash C C++ CSS Docker HTML Go JavaScript NodeJS Ruby PHP "Python_3" Vim ; do
        # MORE: Python_2 GLib Qt_4 Qt_5

        net::DownloadUntarGzip "http://london.kapeli.com/feeds/$i.tgz" "$ds"

        sys::Jq \
          '.[] | select(.name=="'$i'") | { "extra": .extra, "name": .name, "revision": .revision, "title": .title, "version": .versions[0] } | if .extra == null then del(.extra) else . end | if .version == null then del(.version) else . end' \
          "$reg" \
          >"$ds/${i//_/ }.docset/meta.json"

          sys::Jq '.[] | select(.name=="'$i'") | .icon' "$reg" \
        | base64 -d >"$ds/${i//_/ }.docset/icon.png"
 
          sys::Jq '.[] | select(.name=="'$i'") | .icon2x' "$reg" \
        | base64 -d >"$ds/${i//_/ }.docset/icon@2x.png"
 
    done

    rm "$reg"

    chown -hR 1000:1000 $HOME/.local/share/Zeal
}



app::Ghidra ()
{
    Meta --desc "Software Reverse Engineering" \
         --no-default true

    apt::AddPackages openjdk-11-jdk-headless

    # DEV: HARDCODED version
    local vers=9.0.4
    local date=20190516

    # TODO Scrap
    # local base="https://www.ghidra-sre.org"
    # local url=$( net::Download "$base" | awk -F '"' '{for(i=1;i<=NF;i++) if ($i ~ /^ghidra_[0-9.]+_PUBLIC_20[0-9]+\.zip$/){print $i}}' )
    # [[ "$(str::GetWordCount $url)" == "1" ]] || sys::Die "Failed to scrap Ghidra archive url"
    # url="$base/$url"
    # TODO rematch $vers

    # Install
    net::DownloadUnzip \
        "https://www.ghidra-sre.org/ghidra_${vers}_PUBLIC_$date.zip" \
        /opt

    sys::Write <<EOF /usr/local/share/applications/ghidra.desktop
[Desktop Entry]
Name=Ghidra
Exec=env _JAVA_OPTIONS= /opt/ghidra_$vers/ghidraRun
Terminal=false
Type=Application
Icon=ghidra
EOF

    gui::AddAppFolder Code ghidra

    # Conf
    sys::Write <<EOF $HOME/.ghidra/.ghidra-$vers/preferences
USER_AGREEMENT=ACCEPT
SHOW_TIPS=false
LastLookAndFeel=Metal
LookAndFeel.UseInvertedColors=true
EOF
# LookAndFeel.UseInvertedColors=false
# LastLookAndFeel=GTK+

    # TODO colorscheme tcd
    # https://github.com/elliiot/ghidra_darknight

    # Icon
    sys::Write <<'EOF' "/usr/share/icons/$THEME_ICON/48/apps/ghidra.svg"
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!-- Created with Inkscape (http://www.inkscape.org/) -->

<svg
   xmlns:dc="http://purl.org/dc/elements/1.1/"
   xmlns:cc="http://creativecommons.org/ns#"
   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
   xmlns:svg="http://www.w3.org/2000/svg"
   xmlns="http://www.w3.org/2000/svg"
   xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd"
   xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"
   width="49.528793mm"
   height="49.12431mm"
   viewBox="0 0 49.528793 49.12431"
   version="1.1"
   id="svg6844"
   inkscape:version="0.92.3 (2405546, 2018-03-11)"
   sodipodi:docname="ghidra2.svg">
  <defs
     id="defs6838" />
  <sodipodi:namedview
     id="base"
     pagecolor="#ffffff"
     bordercolor="#666666"
     borderopacity="1.0"
     inkscape:pageopacity="0.0"
     inkscape:pageshadow="2"
     inkscape:zoom="3.959798"
     inkscape:cx="170.52792"
     inkscape:cy="77.484004"
     inkscape:document-units="mm"
     inkscape:current-layer="layer1"
     showgrid="false"
     inkscape:window-width="1920"
     inkscape:window-height="1172"
     inkscape:window-x="0"
     inkscape:window-y="28"
     inkscape:window-maximized="1"
     fit-margin-top="0"
     fit-margin-left="0"
     fit-margin-right="0"
     fit-margin-bottom="0" />
  <metadata
     id="metadata6841">
    <rdf:RDF>
      <cc:Work
         rdf:about="">
        <dc:format>image/svg+xml</dc:format>
        <dc:type
           rdf:resource="http://purl.org/dc/dcmitype/StillImage" />
        <dc:title></dc:title>
      </cc:Work>
    </rdf:RDF>
  </metadata>
  <g
     inkscape:label="Layer 1"
     inkscape:groupmode="layer"
     id="layer1"
     transform="translate(-54.667863,-121.30503)">
    <ellipse
       style="fill:#ffffff;stroke-width:0.26458332"
       id="path6978"
       cx="79.406403"
       cy="145.86719"
       rx="24.738541"
       ry="24.562155" />
    <path
       inkscape:connector-curvature="0"
       id="path6881"
       d="m 105.64953,142.25904 v -24.56215 h 24.73854 24.73854 v 24.56215 24.56216 h -24.73854 -24.73854 z"
       style="fill:#fcfbfb;stroke-width:0.08819444" />
    <g
       id="g6995"
       transform="translate(-50.914845,3.6081386)">
      <path
         style="fill:#f59e2a;stroke-width:0.08819444"
         d="m 127.80808,166.68629 c -5.77538,-0.52389 -11.50132,-3.35456 -15.49987,-7.66251 -1.20642,-1.29977 -1.26403,-1.4341 -0.5055,-1.17878 0.22951,0.0773 2.06433,0.7023 4.07737,1.38899 10.33609,3.52581 14.66651,3.89673 20.26248,1.73557 6.57278,-2.53841 9.72834,-6.84441 10.1246,-13.81573 0.31892,-5.6108 -1.6592,-8.48975 -6.27875,-9.1381 l -1.06785,-0.14987 -0.75625,0.23578 c -0.85625,0.26697 -0.80914,0.21955 -1.1307,1.13782 -0.86481,2.46956 -3.03901,4.3866 -4.97506,4.3866 -0.57115,0 -0.50741,-0.0941 -1.22532,1.80798 -0.92796,2.45854 -2.47908,6.30307 -3.11351,7.71702 -0.3156,0.70335 -0.75043,1.67322 -0.96631,2.15527 -0.94352,2.10688 -1.53253,2.43324 -3.44548,1.90908 -2.49864,-0.68466 -4.32416,-2.09012 -6.80234,-5.2371 -0.22262,-0.28269 0.009,-0.30357 1.57935,-0.14213 3.89441,0.40048 4.53034,0.24873 4.67473,-1.11549 0.4922,-4.65034 0.47628,-4.89134 -0.44496,-6.73251 -0.90809,-1.81489 -1.17885,-2.90576 -0.92204,-3.71487 0.0624,-0.19661 -0.0619,-0.23439 -0.20473,-0.0623 -0.0515,0.062 -0.21878,0.45871 -0.37176,0.88151 -0.61691,1.70491 -2.10598,2.52882 -3.72156,2.05916 -1.10883,-0.32234 -1.00906,0.10764 0.24067,1.0372 1.1368,0.84556 1.14263,0.8839 0.15434,1.0163 -2.0619,0.27624 -2.75023,0.21652 -3.56998,-0.30974 -0.50907,-0.3268 -0.57179,-0.29654 -0.42759,0.20625 0.0876,0.30532 1.00436,1.61685 1.371,1.96128 0.55455,0.52098 0.27495,0.5658 -1.34843,0.21619 -1.95888,-0.42186 -2.80989,-0.8733 -3.33484,-1.76907 -0.41038,-0.70026 -0.73527,0.0541 -1.09487,2.54206 -0.17795,1.23117 -0.17232,1.23162 -1.10943,-0.0892 -3.06723,-4.32323 -1.33023,-9.33612 3.67265,-10.59903 4.37603,-1.10468 6.40257,-2.76904 7.19451,-5.90871 0.7164,-2.8402 2.35711,-3.86204 5.23952,-3.26319 0.46081,0.0957 0.89812,0.17459 0.9718,0.17523 0.0737,6.2e-4 0.39118,-0.36464 0.70555,-0.81173 3.72431,-5.29643 11.2878,-8.23028 16.89701,-6.55429 0.65582,0.19595 2.90458,1.70444 2.75856,1.85046 -0.0194,0.0194 -0.61105,0.0757 -1.31477,0.12505 -1.27018,0.0891 -2.63701,0.40404 -2.78366,0.64134 -0.0373,0.0604 10e-4,0.0764 0.10672,0.0439 0.53089,-0.16371 2.0278,-0.33966 3.25666,-0.38281 l 1.41559,-0.0497 1.26023,1.1804 c 17.15675,16.06991 4.04963,44.41694 -19.54778,42.27639 z m -17.16087,-9.62528 c -0.10148,-0.10148 -0.0642,-0.20579 0.0735,-0.20579 0.42337,0 0.65103,-0.79261 0.315,-1.09671 -0.26804,-0.24257 -0.52151,-0.10459 -0.64312,0.35009 -0.10653,0.39832 -0.33334,0.41594 -0.33334,0.0259 0,-0.99192 1.30804,-1.04112 1.46803,-0.0552 0.0958,0.59039 -0.55048,1.31133 -0.88007,0.98174 z m 0.17474,-2.47347 c -0.0304,-0.18373 -0.0556,-0.48413 -0.0562,-0.66755 -6.3e-4,-0.21439 -0.0482,-0.35163 -0.13326,-0.38426 -0.21084,-0.0809 -0.15339,-0.27206 0.10095,-0.3359 0.34737,-0.0872 0.39387,0.0245 0.36571,0.8782 -0.0272,0.82394 -0.17911,1.10317 -0.27722,0.50951 z m 1.88313,0.21356 c -0.68434,-0.34527 -0.42492,-1.65004 0.32807,-1.65004 0.70956,0 1.01259,0.96596 0.47247,1.50609 -0.28146,0.28145 -0.46322,0.31414 -0.80054,0.14395 z m 0.66915,-0.45878 c 0.2266,-0.34583 0.0247,-0.92668 -0.32217,-0.92668 -0.19987,0 -0.43517,0.32371 -0.43517,0.59869 0,0.54023 0.48161,0.74882 0.75734,0.32799 z m -4.8993,-0.70024 c -0.0632,-0.118 -0.0892,-0.28122 -0.058,-0.36271 0.0868,-0.22632 0.31936,0.009 0.31936,0.32346 0,0.31019 -0.10774,0.32637 -0.2614,0.0392 z m -0.0326,-1.07899 c -0.0323,-0.0323 -0.0588,-0.32732 -0.0588,-0.65551 0,-0.51926 -0.0229,-0.60399 -0.17639,-0.6527 -0.24259,-0.077 -0.22095,-0.20791 0.0515,-0.3115 0.32928,-0.12519 0.36787,-0.0672 0.43546,0.65411 0.0755,0.80578 -0.0252,1.19214 -0.25177,0.9656 z m 1.82025,-0.15405 c -0.52045,-0.44767 -0.22013,-1.55104 0.42217,-1.55104 0.36195,0 0.51382,0.0831 0.65656,0.35909 0.45573,0.88128 -0.37401,1.79812 -1.07873,1.19195 z m 0.69562,-0.20607 c 0.44152,-0.5141 0.0162,-1.37727 -0.46432,-0.94237 -0.22686,0.20531 -0.22353,0.69047 0.006,0.92032 0.21623,0.21622 0.28825,0.21969 0.45799,0.0221 z m 1.7486,0.30564 c -0.74344,-0.37616 -0.50644,-1.65061 0.30694,-1.65061 0.32521,0 0.48178,0.0906 0.62062,0.35909 0.39649,0.76671 -0.23287,1.64302 -0.92756,1.29152 z m 0.61252,-0.41009 c 0.13497,-0.25219 0.11085,-0.6792 -0.0473,-0.83734 -0.30605,-0.30605 -0.65516,-0.0744 -0.65516,0.43467 0,0.34894 0.1553,0.57326 0.39688,0.57326 0.12159,0 0.25377,-0.0738 0.30557,-0.17059 z m 1.41646,0.26103 c -0.51453,-0.51453 -0.18797,-1.58974 0.48282,-1.58974 0.30179,0 0.64791,0.32313 0.71199,0.6647 0.11842,0.63127 -0.18466,1.09919 -0.71199,1.09919 -0.18976,0 -0.37577,-0.0671 -0.48282,-0.17415 z m 0.74111,-0.22903 c 0.0783,-0.0783 0.13859,-0.28723 0.13859,-0.48007 0,-0.71782 -0.71706,-0.76037 -0.77754,-0.0461 -0.0446,0.52632 0.3302,0.83496 0.63895,0.52621 z m -3.03001,-2.12226 c -0.51912,-0.65995 0.0736,-1.73897 0.79178,-1.44148 0.49317,0.20428 0.64126,1.0477 0.25597,1.45783 -0.28944,0.30809 -0.7988,0.30014 -1.04775,-0.0163 z m 0.82645,-0.22822 c 0.1784,-0.25471 0.17476,-0.58654 -0.009,-0.78923 -0.45346,-0.50106 -0.97909,0.3475 -0.54171,0.87451 0.142,0.1711 0.39865,0.13134 0.55037,-0.0853 z m 1.4119,0.22724 c -0.16603,-0.17915 -0.21628,-0.33003 -0.21628,-0.64944 0,-0.9817 1.10895,-1.22339 1.4112,-0.30755 0.28245,0.85583 -0.61934,1.57805 -1.19492,0.95699 z m 0.79296,-0.22724 c 0.18919,-0.27011 0.17191,-0.65131 -0.0391,-0.86232 -0.2561,-0.25609 -0.41303,-0.21438 -0.61166,0.16256 -0.28077,0.5328 0.31727,1.17588 0.65075,0.69976 z m 1.60903,-0.30191 c -0.0333,-0.0333 -0.0606,-0.327 -0.0606,-0.65254 0,-0.5138 -0.0262,-0.61027 -0.19843,-0.73107 -0.22825,-0.16007 -0.0981,-0.3195 0.2629,-0.32197 0.25116,-0.002 0.30461,0.20591 0.27055,1.05096 -0.0241,0.59662 -0.11512,0.81388 -0.27438,0.65462 z m 2.04616,-2.01351 c -0.69755,-0.38539 -0.45359,-1.7219 0.31431,-1.7219 0.98037,0 1.10061,1.58496 0.13654,1.79999 -0.12127,0.0271 -0.32415,-0.008 -0.45085,-0.0781 z m 0.66633,-0.4186 c 0.3706,-0.52911 -0.18789,-1.35396 -0.58483,-0.86376 -0.30564,0.37745 -0.11904,1.05977 0.28982,1.05977 0.0867,0 0.2195,-0.0882 0.29501,-0.19601 z"
         id="path6879"
         inkscape:connector-curvature="0" />
      <path
         style="fill:#ee7449;stroke-width:0.08819444"
         d="m 127.80808,166.68629 c -5.39498,-0.48939 -10.72406,-2.97285 -14.7287,-6.86388 -1.17621,-1.14284 -1.12199,-1.13855 0.6514,0.0515 8.88181,5.96028 18.01158,7.16954 25.84361,3.42305 9.03965,-4.32415 12.00327,-16.22045 5.82871,-23.39712 -0.58247,-0.67701 -0.67561,-0.64085 -0.22712,0.0882 4.52047,7.3483 1.58251,16.98223 -6.39972,20.98547 -7.3741,3.69825 -14.98294,3.19285 -24.91226,-1.65472 -1.08459,-0.5295 -2.00371,-0.94313 -2.04248,-0.91916 -0.0769,0.0475 -0.52755,-0.44888 -0.52755,-0.58103 0,-0.11846 0.19081,-0.10031 0.62832,0.0598 12.97069,4.74589 18.20568,5.41403 24.22027,3.09119 6.57278,-2.53841 9.72834,-6.84441 10.1246,-13.81573 0.31892,-5.6108 -1.6592,-8.48975 -6.27875,-9.1381 l -1.06785,-0.14987 -0.75625,0.23578 c -0.85625,0.26697 -0.80914,0.21955 -1.1307,1.13782 -0.86481,2.46956 -3.03901,4.3866 -4.97506,4.3866 -0.57115,0 -0.50741,-0.0941 -1.22532,1.80798 -0.92796,2.45854 -2.47908,6.30307 -3.11351,7.71702 -0.3156,0.70335 -0.75043,1.67322 -0.96631,2.15527 -0.94352,2.10688 -1.53253,2.43324 -3.44548,1.90908 -2.49864,-0.68466 -4.32416,-2.09012 -6.80234,-5.2371 -0.22262,-0.28269 0.009,-0.30357 1.57935,-0.14213 3.89441,0.40048 4.53034,0.24873 4.67473,-1.11549 0.4922,-4.65034 0.47628,-4.89134 -0.44496,-6.73251 -0.90809,-1.81489 -1.17885,-2.90576 -0.92204,-3.71487 0.0624,-0.19661 -0.0619,-0.23439 -0.20473,-0.0623 -0.0515,0.062 -0.21878,0.45871 -0.37176,0.88151 -0.61691,1.70491 -2.10598,2.52882 -3.72156,2.05916 -1.10883,-0.32234 -1.00906,0.10764 0.24067,1.0372 1.1368,0.84556 1.14263,0.8839 0.15434,1.0163 -2.0619,0.27624 -2.75023,0.21652 -3.56998,-0.30974 -0.50907,-0.3268 -0.57179,-0.29654 -0.42759,0.20625 0.0876,0.30532 1.00436,1.61685 1.371,1.96128 0.55455,0.52098 0.27495,0.5658 -1.34843,0.21619 -1.95888,-0.42186 -2.80989,-0.8733 -3.33484,-1.76907 -0.41038,-0.70026 -0.73527,0.0541 -1.09487,2.54206 -0.17795,1.23117 -0.17232,1.23162 -1.10943,-0.0892 -3.06723,-4.32323 -1.33023,-9.33612 3.67265,-10.59903 4.37603,-1.10468 6.40257,-2.76904 7.19451,-5.90871 0.7164,-2.8402 2.35711,-3.86204 5.23952,-3.26319 0.46081,0.0957 0.89812,0.17459 0.9718,0.17523 0.0737,6.2e-4 0.39118,-0.36464 0.70555,-0.81173 3.72431,-5.29643 11.2878,-8.23028 16.89701,-6.55429 0.65582,0.19595 2.90458,1.70444 2.75856,1.85046 -0.0194,0.0194 -0.61105,0.0757 -1.31477,0.12505 -1.27018,0.0891 -2.63701,0.40404 -2.78366,0.64134 -0.0373,0.0604 10e-4,0.0764 0.10672,0.0439 0.53089,-0.16371 2.0278,-0.33966 3.25666,-0.38281 l 1.41559,-0.0497 1.26023,1.1804 c 17.15675,16.06991 4.04963,44.41694 -19.54778,42.27639 z"
         id="path6877"
         inkscape:connector-curvature="0" />
      <path
         style="fill:#e55d2e;stroke-width:0.08819444"
         d="m 129.02105,166.72936 c -5.88316,-0.46248 -11.34042,-2.78601 -15.4159,-6.56362 -0.52556,-0.48714 -0.90316,-0.9632 -0.62121,-0.78319 0.0649,0.0414 0.63395,0.41531 1.26455,0.83081 8.56039,5.64056 17.66354,6.74893 25.3259,3.0836 9.03965,-4.32415 12.00327,-16.22045 5.82871,-23.39712 -0.58247,-0.67701 -0.67561,-0.64085 -0.22712,0.0882 7.34217,11.93515 -4.50707,25.61125 -20.03548,23.12445 -3.90159,-0.62483 -10.67875,-3.10571 -13.37752,-4.89705 -0.68803,-0.45669 -0.61129,-0.61903 0.15931,-0.33707 12.97069,4.74589 18.20568,5.41403 24.22027,3.09119 6.57278,-2.53841 9.72834,-6.84441 10.1246,-13.81573 0.31892,-5.6108 -1.6592,-8.48975 -6.27875,-9.1381 l -1.06785,-0.14987 -0.75625,0.23578 c -0.85625,0.26697 -0.80914,0.21955 -1.1307,1.13782 -0.86481,2.46956 -3.03901,4.3866 -4.97506,4.3866 -0.57115,0 -0.50741,-0.0941 -1.22532,1.80798 -0.92796,2.45854 -2.47907,6.30307 -3.11351,7.71702 -0.3156,0.70335 -0.75043,1.67322 -0.96631,2.15527 -0.94352,2.10688 -1.53253,2.43324 -3.44548,1.90908 -2.49864,-0.68466 -4.32416,-2.09012 -6.80234,-5.2371 -0.22262,-0.28269 0.009,-0.30357 1.57935,-0.14213 3.89441,0.40048 4.53034,0.24873 4.67473,-1.11549 0.4922,-4.65034 0.47628,-4.89134 -0.44496,-6.73251 -0.90809,-1.81489 -1.17885,-2.90576 -0.92204,-3.71487 0.0624,-0.19661 -0.0619,-0.23439 -0.20473,-0.0623 -0.0515,0.062 -0.21878,0.45871 -0.37176,0.88151 -0.61691,1.70491 -2.10598,2.52882 -3.72156,2.05916 -1.10883,-0.32234 -1.00906,0.10764 0.24067,1.0372 1.13681,0.84556 1.14263,0.8839 0.15434,1.0163 -2.0619,0.27624 -2.75023,0.21652 -3.56998,-0.30974 -0.50906,-0.3268 -0.57179,-0.29654 -0.42759,0.20625 0.0876,0.30532 1.00436,1.61685 1.371,1.96128 0.55455,0.52098 0.27495,0.5658 -1.34843,0.21619 -1.95888,-0.42186 -2.80989,-0.8733 -3.33484,-1.76907 -0.41038,-0.70026 -0.73527,0.0541 -1.09487,2.54206 -0.17795,1.23117 -0.17232,1.23162 -1.10943,-0.0892 -3.06723,-4.32323 -1.33023,-9.33612 3.67265,-10.59903 4.37603,-1.10468 6.40257,-2.76904 7.19451,-5.90871 0.7164,-2.8402 2.35711,-3.86204 5.23952,-3.26319 0.46081,0.0957 0.89812,0.17459 0.9718,0.17523 0.0737,6.2e-4 0.39118,-0.36464 0.70555,-0.81173 3.72431,-5.29643 11.2878,-8.23028 16.89701,-6.55429 0.65582,0.19595 2.90458,1.70444 2.75856,1.85046 -0.0194,0.0194 -0.61105,0.0757 -1.31477,0.12505 -1.27018,0.0891 -2.63701,0.40404 -2.78366,0.64134 -0.0373,0.0604 10e-4,0.0764 0.10672,0.0439 0.53585,-0.16524 2.02905,-0.33921 3.25219,-0.37891 l 1.41111,-0.0458 0.32675,0.27566 c 0.53261,0.4493 0.41078,0.51126 -1.01546,0.51642 -2.33228,0.008 -4.27519,0.51099 -6.89601,1.78372 -1.1103,0.53919 -3.13091,1.76271 -3.13091,1.89584 0,0.0289 0.0298,0.0365 0.0661,0.0168 2.81396,-1.52109 7.30258,-2.64042 10.65288,-2.65652 1.99075,-0.01 1.83913,-0.0706 2.88569,1.16102 0.39978,0.47047 0.88368,1.00639 1.07533,1.19094 0.70047,0.6745 0.78047,1.02741 0.23607,1.04143 -0.27088,0.007 -0.0851,0.11344 0.36846,0.21113 1.11334,0.23982 3.62968,6.52408 4.15084,10.36624 0.0691,0.50932 0.13594,0.86651 0.14856,0.79375 0.0473,-0.27274 0.15007,1.14332 0.16063,2.21336 0.013,1.31484 -0.079,2.7772 -0.16581,2.63673 -0.0338,-0.0546 -0.0883,0.19103 -0.12117,0.54594 -0.98199,10.60252 -11.92591,21.32688 -21.76349,21.32688 -0.14485,0 -0.33022,0.0346 -0.41191,0.0769 -0.21212,0.10977 -2.64022,0.17386 -3.63223,0.0959 z m -4.26448,-11.44155 c 0.10413,-0.0838 0.27641,-0.32654 0.38284,-0.53941 0.338,-0.676 2.73907,-6.86672 2.73299,-7.04652 -0.001,-0.0346 -0.48734,0.91162 -1.08038,2.10278 -2.10623,4.23052 -2.47395,4.54341 -4.87062,4.14441 -0.57498,-0.0957 -0.60139,-0.0491 -0.17639,0.31142 1.01308,0.85935 2.56323,1.38815 3.01156,1.02732 z m 8.16181,-13.77533 c 2.65063,-0.58616 3.76235,-3.91099 2.32333,-6.9484 -0.38306,-0.80853 -0.39888,-0.80234 -0.33858,0.13229 0.1704,2.64084 -0.99232,5.2636 -2.92291,6.59325 -0.69036,0.47547 -0.45597,0.53115 0.93816,0.22286 z m -2.46825,-16.95063 c 3.06431,-1.82212 5.90585,-2.63001 10.23213,-2.90918 0.53624,-0.0346 -1.00868,-0.14532 -2.13621,-0.15309 -3.68613,-0.0254 -5.86819,0.76355 -8.73125,3.15698 -0.67475,0.56407 -0.93896,0.88708 -0.47675,0.58285 0.14095,-0.0928 0.64138,-0.39767 1.11208,-0.67756 z"
         id="path6875"
         inkscape:connector-curvature="0" />
      <path
         style="fill:#8f6862;stroke-width:0.08819444"
         d="m 129.12802,166.76062 c -0.55196,-0.0206 -0.88668,-0.0672 -0.85469,-0.11893 0.0296,-0.0478 -0.0702,-0.0851 -0.22794,-0.0851 -0.15428,0 -0.70233,-0.0611 -1.21788,-0.13587 -4.58789,-0.66504 -9.05472,-2.708 -12.60855,-5.76669 -0.82141,-0.70696 -0.76085,-0.76079 0.17377,-0.15443 9.36859,6.07818 19.99535,6.72984 27.50471,1.68667 7.60377,-5.10657 9.21099,-16.69407 3.16459,-22.81562 -1.14956,-1.16385 -1.3425,-1.2129 -0.5204,-0.13229 4.8876,6.42443 2.78644,16.42315 -4.38601,20.87165 -5.56495,3.45149 -11.97567,4.10345 -19.14335,1.94686 -3.60318,-1.08412 -10.03837,-3.94085 -9.68142,-4.29781 0.03,-0.03 0.24234,0.009 0.47186,0.0859 0.22952,0.0773 2.06433,0.7023 4.07737,1.38899 10.33609,3.52581 14.66651,3.89673 20.26248,1.73557 6.57278,-2.53841 9.72834,-6.84441 10.1246,-13.81573 0.31892,-5.6108 -1.6592,-8.48975 -6.27875,-9.1381 l -1.06785,-0.14987 -0.75625,0.23578 c -0.85625,0.26697 -0.80914,0.21955 -1.1307,1.13782 -0.86481,2.46956 -3.03901,4.3866 -4.97506,4.3866 -0.57115,0 -0.50741,-0.0941 -1.22532,1.80798 -0.92796,2.45854 -2.47907,6.30307 -3.11351,7.71702 -0.3156,0.70335 -0.75043,1.67322 -0.96631,2.15527 -0.94352,2.10688 -1.53253,2.43324 -3.44548,1.90908 -2.49864,-0.68466 -4.32416,-2.09012 -6.80234,-5.2371 -0.22262,-0.28269 0.009,-0.30357 1.57935,-0.14213 3.89441,0.40048 4.53034,0.24873 4.67473,-1.11549 0.4922,-4.65034 0.47628,-4.89134 -0.44496,-6.73251 -0.90809,-1.81489 -1.17885,-2.90576 -0.92204,-3.71487 0.0624,-0.19661 -0.0619,-0.23439 -0.20473,-0.0623 -0.0515,0.062 -0.21878,0.45871 -0.37176,0.88151 -0.61691,1.70491 -2.10598,2.52882 -3.72156,2.05916 -1.10883,-0.32234 -1.00906,0.10764 0.24067,1.0372 1.13681,0.84556 1.14263,0.8839 0.15434,1.0163 -2.0619,0.27624 -2.75023,0.21652 -3.56998,-0.30974 -0.50906,-0.3268 -0.57179,-0.29654 -0.42759,0.20625 0.0876,0.30532 1.00436,1.61685 1.371,1.96128 0.55455,0.52098 0.27495,0.5658 -1.34843,0.21619 -1.95888,-0.42186 -2.80989,-0.8733 -3.33484,-1.76907 -0.41038,-0.70026 -0.73527,0.0541 -1.09487,2.54206 -0.17795,1.23117 -0.17232,1.23162 -1.10943,-0.0892 -3.06723,-4.32323 -1.33023,-9.33612 3.67265,-10.59903 4.37603,-1.10468 6.40257,-2.76904 7.19451,-5.90871 0.7164,-2.8402 2.35711,-3.86204 5.23952,-3.26319 0.46081,0.0957 0.89812,0.17459 0.9718,0.17523 0.0737,6.2e-4 0.39118,-0.36464 0.70555,-0.81173 3.72431,-5.29643 11.2878,-8.23028 16.89701,-6.55429 0.65582,0.19595 2.90458,1.70444 2.75856,1.85046 -0.0194,0.0194 -0.61105,0.0757 -1.31477,0.12505 -1.27018,0.0891 -2.63701,0.40404 -2.78366,0.64134 -0.0373,0.0604 10e-4,0.0764 0.10672,0.0439 0.53585,-0.16524 2.02905,-0.33921 3.25219,-0.37891 l 1.41111,-0.0458 0.33527,0.28267 c 0.44791,0.37764 0.41142,0.39275 -0.98199,0.40673 -2.41176,0.0242 -4.59997,0.60804 -7.28141,1.94279 -0.95848,0.4771 -3.58125,2.18575 -3.58125,2.33307 0,0.13391 0.10356,0.093 1.32369,-0.52335 2.97941,-1.50499 6.56777,-2.38719 10.01967,-2.46337 l 1.95066,-0.043 0.371,0.33518 c 0.20404,0.18434 0.67208,0.695 1.04007,1.1348 0.36799,0.43979 0.739,0.82697 0.82447,0.86039 0.68148,0.26653 0.64589,0.86527 -0.0514,0.86527 -0.7909,0 -0.78139,0.13217 0.0223,0.3098 0.92169,0.20371 0.90598,0.19162 1.45758,1.12117 1.86125,3.13657 3.07962,6.94253 3.35336,10.47528 l 0.0308,0.39687 0.0293,-0.48507 0.0293,-0.48507 0.0634,0.61737 c 0.0817,0.79573 0.0817,3.08482 0,3.88055 l -0.0634,0.61736 -0.0293,-0.48507 -0.0293,-0.48507 -0.03,0.39688 c -0.68543,9.08 -6.7202,17.20399 -15.3586,20.6757 -2.0283,0.81517 -5.44324,1.63749 -6.8001,1.63749 -0.16456,0 -0.25799,0.0365 -0.22602,0.0882 0.0345,0.0559 -0.19766,0.0884 -0.6342,0.0888 -0.37879,3.5e-4 -0.94668,0.0142 -1.26198,0.0307 -0.31529,0.0166 -0.98153,0.0149 -1.48053,-0.004 z m -4.48321,-11.26229 c 0.37748,-0.15772 0.53853,-0.43508 1.18368,-2.03859 1.19724,-2.97569 3.37926,-8.82992 3.36485,-9.02769 -0.008,-0.11226 -0.47233,0.84891 -1.18588,2.45576 -3.04633,6.86006 -3.63738,7.50053 -6.35056,6.88154 -0.83468,-0.19042 -0.43844,0.384 0.75429,1.09348 1.16157,0.69096 1.72038,0.84995 2.23362,0.6355 z m 8.37946,-13.86931 c 2.6948,-0.60778 3.81119,-4.11913 2.28042,-7.17251 -0.57727,-1.15145 -0.59509,-1.13237 -0.59509,0.6367 0,2.86267 -0.93228,4.82014 -2.95335,6.20108 -0.92301,0.63067 -0.51806,0.73756 1.26802,0.33473 z m -3.7712,-16.16115 c 3.74666,-2.48996 6.676,-3.40345 11.79518,-3.67821 1.3968,-0.075 1.28173,-0.16563 -0.38744,-0.30525 -5.2167,-0.43634 -8.44671,0.64099 -11.93101,3.97947 -0.91542,0.87711 -0.79193,0.87805 0.52327,0.004 z"
         id="path6873"
         inkscape:connector-curvature="0" />
      <path
         style="fill:#e02625;stroke-width:0.08819444"
         d="m 129.12802,166.76062 c -0.55196,-0.0206 -0.88668,-0.0672 -0.85469,-0.11893 0.0296,-0.0478 -0.0702,-0.0851 -0.22794,-0.0851 -0.15428,0 -0.70233,-0.0611 -1.21788,-0.13587 -4.58789,-0.66504 -9.05472,-2.708 -12.60855,-5.76669 -0.82141,-0.70696 -0.76085,-0.76079 0.17377,-0.15443 9.36859,6.07818 19.99535,6.72984 27.50471,1.68667 7.60377,-5.10657 9.21099,-16.69407 3.16459,-22.81562 -1.14956,-1.16385 -1.3425,-1.2129 -0.5204,-0.13229 4.8876,6.42443 2.78644,16.42315 -4.38601,20.87165 -7.39748,4.58805 -16.18218,4.21441 -26.83318,-1.14131 -2.48938,-1.25175 -2.3414,-1.24803 1.37524,0.0346 8.23373,2.84145 10.47081,3.36482 14.36747,3.36131 7.0518,-0.006 13.36412,-3.41409 15.7831,-8.5206 2.07901,-4.38885 2.10396,-10.90032 0.0522,-13.6179 -1.34218,-1.7777 -4.98963,-2.91659 -7.00474,-2.18718 l -0.69447,0.25137 -0.29272,0.82431 c -0.86804,2.4444 -2.78832,4.21916 -4.67207,4.31804 -0.89153,0.0468 -0.77491,-0.0896 -1.44744,1.69272 -1.85677,4.92071 -4.26289,10.58495 -4.83375,11.37912 -0.85209,1.1854 -2.98993,0.91375 -5.39349,-0.68535 -1.55124,-1.03205 -4.35465,-4.06609 -3.64537,-3.94527 1.47578,0.25139 4.31091,0.36894 5.05409,0.20956 0.80524,-0.17269 0.89802,-0.38297 1.04655,-2.37195 0.0525,-0.70335 0.13372,-1.70756 0.18045,-2.23159 0.13892,-1.55817 0.0485,-1.97708 -0.78453,-3.63277 -0.93765,-1.86371 -1.11921,-2.67861 -0.8319,-3.73381 0.0497,-0.18249 0.0292,-0.20221 -0.18302,-0.17639 -0.28073,0.0342 -0.3848,0.19806 -0.75888,1.19517 -0.61211,1.63159 -2.08278,2.32184 -3.81571,1.79091 -0.48023,-0.14714 -0.58667,-0.0805 -0.58921,0.36912 -0.001,0.20054 0.14284,0.3485 0.8888,0.91342 1.0233,0.77496 1.02354,0.77303 -0.1133,0.90717 -1.69815,0.20037 -2.47648,0.0871 -3.20152,-0.46591 -1.09439,-0.83473 -0.38171,1.17568 0.86019,2.42655 0.34961,0.35213 0.25754,0.35477 -1.22111,0.0351 -1.90394,-0.41164 -2.73936,-0.88092 -3.20978,-1.80302 -0.41209,-0.80776 -0.81764,-0.10041 -1.20147,2.09552 -0.21563,1.23369 -0.26108,1.41762 -0.32938,1.33308 -3.57592,-4.42622 -2.29429,-9.89854 2.60286,-11.11372 4.66858,-1.15846 6.85626,-2.88236 7.6578,-6.03436 0.73462,-2.88889 2.22132,-3.81121 5.1904,-3.22001 1.12066,0.22314 1.04793,0.24487 1.5232,-0.455 2.96847,-4.37126 8.1953,-7.15655 13.43842,-7.1611 2.76079,-0.002 3.57173,0.22092 5.37308,1.4797 0.80432,0.56205 0.81163,0.55416 -0.56648,0.61188 -0.7374,0.0309 -1.22626,0.10521 -1.79101,0.2723 -1.70883,0.50558 -2.29465,1.0877 -0.72254,0.71796 0.82669,-0.19443 2.27968,-0.38213 3.45492,-0.44633 l 1.07368,-0.0587 0.3255,0.2983 0.3255,0.2983 -1.17869,0.008 c -3.10228,0.0198 -6.33502,1.14162 -9.52574,3.30549 -1.16364,0.78916 -1.46708,1.04393 -1.24332,1.04393 0.0368,0 0.60235,-0.27046 1.25677,-0.60102 2.98688,-1.50876 6.56663,-2.38723 10.0396,-2.46373 l 1.97057,-0.0434 0.5918,0.60599 c 0.64772,0.66323 2.03754,2.37307 2.03754,2.5067 0,0.046 -0.23578,0.0837 -0.52396,0.0837 -0.75501,0 -0.72829,0.13532 0.0612,0.3098 0.92169,0.20371 0.90598,0.19162 1.45758,1.12117 1.84582,3.11058 3.28124,7.60523 3.33132,10.43118 0.006,0.32856 0.0271,0.39601 0.0836,0.26458 0.0456,-0.10603 0.0777,0.57991 0.0807,1.7198 0.003,1.25466 -0.0241,1.85142 -0.0807,1.76388 -0.0617,-0.0954 -0.0859,-0.0125 -0.0868,0.29737 -0.0228,7.24668 -5.83724,15.92483 -13.15901,19.63995 -2.86152,1.45196 -6.90065,2.64046 -8.97362,2.64046 -0.16456,0 -0.25799,0.0365 -0.22602,0.0882 0.0345,0.0559 -0.19766,0.0884 -0.6342,0.0888 -0.37879,3.5e-4 -0.94668,0.0142 -1.26198,0.0307 -0.31529,0.0166 -0.98153,0.0149 -1.48053,-0.004 z m -4.48321,-11.26229 c 0.37748,-0.15772 0.53853,-0.43508 1.18368,-2.03859 1.19724,-2.97569 3.37926,-8.82992 3.36485,-9.02769 -0.008,-0.11226 -0.47233,0.84891 -1.18588,2.45576 -3.04633,6.86006 -3.63738,7.50053 -6.35056,6.88154 -0.83468,-0.19042 -0.43844,0.384 0.75429,1.09348 1.16157,0.69096 1.72038,0.84995 2.23362,0.6355 z m 8.37946,-13.86931 c 2.6948,-0.60778 3.81119,-4.11913 2.28042,-7.17251 -0.57727,-1.15145 -0.59509,-1.13237 -0.59509,0.6367 0,2.86267 -0.93228,4.82014 -2.95335,6.20108 -0.92301,0.63067 -0.51806,0.73756 1.26802,0.33473 z m -3.7712,-16.16115 c 3.74666,-2.48996 6.676,-3.40345 11.79518,-3.67821 1.3968,-0.075 1.28173,-0.16563 -0.38744,-0.30525 -5.2167,-0.43634 -8.44671,0.64099 -11.93101,3.97947 -0.91542,0.87711 -0.79193,0.87805 0.52327,0.004 z"
         id="path6871"
         inkscape:connector-curvature="0" />
      <path
         style="fill:#9e2c25;stroke-width:0.08819444"
         d="m 127.14527,163.28834 c -4.0767,-0.36202 -9.03165,-1.91043 -13.82283,-4.31962 -2.48938,-1.25175 -2.3414,-1.24803 1.37524,0.0346 8.23373,2.84145 10.47081,3.36482 14.36747,3.36131 7.0518,-0.006 13.36412,-3.41409 15.7831,-8.5206 2.07901,-4.38885 2.10396,-10.90032 0.0522,-13.6179 -1.34218,-1.7777 -4.98963,-2.91659 -7.00474,-2.18718 l -0.69447,0.25137 -0.29272,0.82431 c -0.86804,2.4444 -2.78832,4.21916 -4.67207,4.31804 -0.89153,0.0468 -0.77491,-0.0896 -1.44744,1.69272 -1.85677,4.92071 -4.26289,10.58495 -4.83375,11.37912 -0.85209,1.1854 -2.98993,0.91375 -5.39349,-0.68535 -1.55124,-1.03205 -4.35465,-4.06609 -3.64537,-3.94527 1.47578,0.25139 4.31091,0.36894 5.05409,0.20956 0.80524,-0.17269 0.89802,-0.38297 1.04655,-2.37195 0.0525,-0.70335 0.13372,-1.70756 0.18045,-2.23159 0.13892,-1.55817 0.0485,-1.97708 -0.78453,-3.63277 -0.93765,-1.86371 -1.11921,-2.67861 -0.8319,-3.73381 0.0497,-0.18249 0.0292,-0.20221 -0.18302,-0.17639 -0.28073,0.0342 -0.3848,0.19806 -0.75888,1.19517 -0.61211,1.63159 -2.08278,2.32184 -3.81571,1.79091 -0.48023,-0.14714 -0.58667,-0.0805 -0.58921,0.36912 -0.001,0.20054 0.14284,0.3485 0.8888,0.91342 1.0233,0.77496 1.02354,0.77303 -0.1133,0.90717 -1.69815,0.20037 -2.47648,0.0871 -3.20152,-0.46591 -1.09439,-0.83473 -0.38171,1.17568 0.86019,2.42655 0.34961,0.35213 0.25754,0.35477 -1.22111,0.0351 -1.90394,-0.41164 -2.73936,-0.88092 -3.20978,-1.80302 -0.41209,-0.80776 -0.81764,-0.10041 -1.20147,2.09552 -0.21563,1.23369 -0.26108,1.41762 -0.32938,1.33308 -3.57592,-4.42622 -2.29429,-9.89854 2.60286,-11.11372 4.66858,-1.15846 6.85626,-2.88236 7.6578,-6.03436 0.73462,-2.88889 2.22132,-3.81121 5.1904,-3.22001 1.12066,0.22314 1.04793,0.24487 1.5232,-0.455 2.96847,-4.37126 8.1953,-7.15655 13.43842,-7.1611 2.76079,-0.002 3.57173,0.22092 5.37308,1.4797 0.80432,0.56205 0.81163,0.55416 -0.56648,0.61188 -0.7374,0.0309 -1.22626,0.10521 -1.79101,0.2723 -1.70883,0.50558 -2.29465,1.0877 -0.72254,0.71796 0.82669,-0.19443 2.27968,-0.38213 3.45492,-0.44633 l 1.07368,-0.0587 0.3255,0.2983 0.3255,0.2983 -1.17869,0.008 c -3.07187,0.0196 -6.35285,1.14934 -9.4469,3.25271 -1.55467,1.05689 -1.56338,1.0553 -0.92707,-0.16864 1.51274,-2.90976 3.86325,-4.53122 7.01086,-4.83632 0.59332,-0.0575 1.06175,-0.12158 1.04097,-0.14237 -0.60343,-0.60342 -5.9611,-0.85605 -7.9525,-0.37498 -3.10756,0.75071 -6.64015,3.45253 -8.92413,6.82544 l -0.58768,0.86788 -0.5739,-0.0574 c -0.31564,-0.0316 -1.10989,-0.13386 -1.76499,-0.22732 -2.23958,-0.31948 -2.57815,-0.0216 -3.61902,3.18392 -1.20092,3.69845 -2.09046,4.48618 -6.42724,5.69165 -3.75667,1.04421 -4.08329,1.23322 -4.84582,2.8041 -0.73742,1.51917 -1.06231,3.17425 -0.8155,4.15442 0.11589,0.46025 0.6322,1.65659 0.69,1.59879 0.0208,-0.0208 0.1675,-0.41516 0.32604,-0.87639 0.72797,-2.11792 2.21054,-3.20125 2.21414,-1.61791 0.002,1.06546 0.4206,1.61161 1.47619,1.92791 0.42369,0.12696 0.44944,0.0924 0.28194,-0.37825 -0.45731,-1.28492 0.38416,-3.86927 0.87631,-2.69138 0.30114,0.72073 1.09648,1.32963 1.87637,1.43652 0.38175,0.0523 0.40666,0.0441 0.33959,-0.11189 -0.5365,-1.24798 -0.51545,-2.04352 0.0696,-2.62854 l 0.21291,-0.2129 0.69594,0.16567 c 1.90347,0.45314 1.88383,0.46053 3.22801,-1.2144 0.90451,-1.12706 0.95766,-1.16909 1.94444,-1.53749 1.95664,-0.73049 2.90143,-0.80681 4.15968,-0.33604 0.77331,0.28933 0.61148,0.34777 -0.96302,0.34777 h -1.45495 l -0.35875,0.3241 c -0.95474,0.86256 -0.87977,2.44319 0.2217,4.67433 0.73692,1.49268 0.7371,1.49371 0.64925,3.73282 -0.195,4.96997 -0.46029,5.5402 -2.58528,5.55698 -0.92317,0.007 -1.44074,0.2454 -1.32514,0.60963 0.47312,1.49066 3.86588,3.1489 4.85339,2.37212 0.34435,-0.27086 1.13483,-2.0579 4.20269,-9.50099 1.83203,-4.44479 1.61466,-4.06036 2.26261,-4.00161 2.77909,0.252 5.12761,-2.70519 5.131,-6.46083 0.001,-1.43513 -0.23813,-2.09436 -1.40086,-3.85723 -0.85715,-1.29956 -0.82404,-1.3245 0.58738,-0.44257 1.9242,1.20234 3.37305,2.90633 3.91246,4.60144 0.2352,0.73912 0.13255,0.67061 1.57612,1.0519 2.84512,0.75148 3.99494,1.98006 5.18918,5.54464 3.63756,10.85738 -6.44364,21.45206 -19.32399,20.30825 z m 27.81191,-19.36095 c 0.004,-0.10274 0.0251,-0.12364 0.0533,-0.0533 0.0255,0.0637 0.0223,0.13974 -0.007,0.16904 -0.0293,0.0293 -0.0502,-0.0228 -0.0463,-0.11575 z m 0.007,-3.38814 c 0,-0.12127 0.02,-0.17088 0.0445,-0.11024 0.0245,0.0606 0.0245,0.15985 0,0.22048 -0.0245,0.0606 -0.0445,0.011 -0.0445,-0.11024 z m -45.03875,-0.003 c -0.11514,-0.18631 1.75174,-1.04252 2.03559,-0.93359 0.57144,0.21928 0.0116,0.81469 -0.83372,0.88664 -0.36913,0.0314 -0.77651,0.0776 -0.90528,0.10256 -0.1292,0.0251 -0.26213,1.7e-4 -0.29659,-0.0556 z m 10.23449,-5.72627 c -0.0251,-0.0406 0.1259,-0.3068 0.33553,-0.59156 0.65503,-0.8898 1.07154,-1.64955 1.51179,-2.75767 0.58451,-1.47122 0.80918,-0.97434 0.7315,1.61781 l -0.0236,0.78596 -0.98555,0.41576 c -1.27864,0.53942 -1.51452,0.61901 -1.56971,0.5297 z m 29.09951,-6.44572 c -0.0384,-0.0622 0.0942,-0.26235 0.33061,-0.49872 l 0.39483,-0.39483 0.27783,0.3778 c 0.36636,0.49817 0.35818,0.51943 -0.20003,0.51943 -0.26282,0 -0.53662,0.0225 -0.60844,0.0501 -0.0718,0.0276 -0.15948,0.003 -0.1948,-0.0538 z"
         id="path6869"
         inkscape:connector-curvature="0" />
      <path
         style="fill:#6a3027;stroke-width:0.08819444"
         d="m 127.14527,163.20015 c -4.11693,-0.3656 -9.06398,-1.91955 -13.93942,-4.37861 -0.81598,-0.41156 -1.46741,-0.76448 -1.44763,-0.78427 0.0198,-0.0198 1.34225,0.41483 2.93881,0.9658 8.23445,2.84169 10.47138,3.36504 14.36812,3.36153 7.0518,-0.006 13.36412,-3.41409 15.7831,-8.5206 2.07901,-4.38885 2.10396,-10.90032 0.0522,-13.6179 -1.34218,-1.7777 -4.98963,-2.91659 -7.00474,-2.18718 l -0.69447,0.25137 -0.29272,0.82431 c -0.86804,2.4444 -2.78832,4.21916 -4.67207,4.31804 -0.89153,0.0468 -0.77491,-0.0896 -1.44744,1.69272 -1.85677,4.92071 -4.26289,10.58495 -4.83375,11.37912 -0.85209,1.1854 -2.98993,0.91375 -5.39349,-0.68535 -1.55124,-1.03205 -4.35465,-4.06609 -3.64537,-3.94527 1.47578,0.25139 4.31091,0.36894 5.05409,0.20956 0.80524,-0.17269 0.89802,-0.38297 1.04655,-2.37195 0.0525,-0.70335 0.13372,-1.70756 0.18045,-2.23159 0.13892,-1.55817 0.0485,-1.97708 -0.78453,-3.63277 -0.93765,-1.86371 -1.11921,-2.67861 -0.8319,-3.73381 0.0497,-0.18249 0.0292,-0.20221 -0.18302,-0.17639 -0.28073,0.0342 -0.3848,0.19806 -0.75888,1.19517 -0.61211,1.63159 -2.08278,2.32184 -3.81571,1.79091 -0.48023,-0.14714 -0.58667,-0.0805 -0.58921,0.36912 -0.001,0.20054 0.14284,0.3485 0.8888,0.91342 1.0233,0.77496 1.02354,0.77303 -0.1133,0.90717 -1.69815,0.20037 -2.47648,0.0871 -3.20152,-0.46591 -1.09439,-0.83473 -0.38171,1.17568 0.86019,2.42655 0.34961,0.35213 0.25754,0.35477 -1.22111,0.0351 -1.90394,-0.41164 -2.73936,-0.88092 -3.20978,-1.80302 -0.41209,-0.80776 -0.81764,-0.10041 -1.20147,2.09552 -0.21563,1.23369 -0.26108,1.41762 -0.32938,1.33308 -3.57592,-4.42622 -2.29429,-9.89854 2.60286,-11.11372 4.66858,-1.15846 6.85626,-2.88236 7.6578,-6.03436 0.73462,-2.88889 2.22132,-3.81121 5.1904,-3.22001 1.12066,0.22314 1.04793,0.24487 1.5232,-0.455 2.96847,-4.37126 8.1953,-7.15655 13.43842,-7.1611 2.76079,-0.002 3.57173,0.22092 5.37308,1.4797 0.80432,0.56205 0.81163,0.55416 -0.56648,0.61188 -0.7374,0.0309 -1.22626,0.10521 -1.79101,0.2723 -1.70883,0.50558 -2.29465,1.0877 -0.72254,0.71796 1.90878,-0.44892 4.41208,-0.59559 4.77154,-0.27957 l 0.25555,0.22466 -0.57327,0.003 c -3.27131,0.0163 -6.89733,1.20083 -9.77155,3.19204 -1.4291,0.99006 -1.459,0.97486 -0.68385,-0.34772 1.63666,-2.79254 4.281,-4.3378 7.42753,-4.34039 1.17258,-9.6e-4 1.20002,-0.14791 0.0954,-0.51095 -1.89295,-0.62214 -6.61461,-0.63656 -8.43772,-0.0258 -3.22477,1.0804 -6.33284,3.57752 -8.55645,6.87452 l -0.37876,0.56159 -0.62907,-0.0598 c -0.34599,-0.0329 -1.01577,-0.11697 -1.48839,-0.18677 -2.42147,-0.35762 -2.96197,0.10258 -3.94248,3.35677 -0.62878,2.08681 -1.21093,3.05052 -2.36788,3.91983 -0.92638,0.69606 -1.54363,0.92535 -5.35394,1.98877 -2.3263,0.64925 -2.77794,0.98428 -3.58669,2.66062 -1.0518,2.18014 -1.10767,3.71779 -0.20015,5.5087 0.28272,0.55792 0.38021,0.52157 0.5826,-0.21726 0.40474,-1.47752 1.37197,-2.79226 2.0542,-2.79226 0.0262,0 0.0478,0.32743 0.0479,0.72761 4.8e-4,1.07015 0.4374,1.62539 1.55665,1.9782 0.62876,0.1982 0.7265,0.10687 0.50446,-0.47141 -0.46122,-1.20121 0.15483,-3.51386 0.66806,-2.50786 0.39051,0.76546 1.14934,1.28768 2.02116,1.39093 0.54651,0.0647 0.59712,-0.0247 0.30733,-0.5432 -0.29388,-0.52582 -0.38635,-1.46565 -0.18291,-1.85906 0.28127,-0.54391 0.37522,-0.57515 1.16633,-0.38782 0.388,0.0919 0.94896,0.19332 1.24656,0.22542 l 0.5411,0.0584 0.40823,-0.37629 c 0.22453,-0.20697 0.72967,-0.77753 1.12254,-1.26792 1.24868,-1.55863 3.77572,-2.43881 5.45683,-1.90062 0.39576,0.1267 0.39353,0.12718 -0.79375,0.17115 -2.55453,0.0946 -3.0551,1.94427 -1.42014,5.24757 0.76963,1.55499 0.72749,1.29415 0.61985,3.83646 -0.20451,4.83025 -0.27709,4.98606 -2.43695,5.23191 -1.57861,0.1797 -1.77052,0.36048 -1.24108,1.16912 1.00404,1.5335 3.64861,2.76381 4.73418,2.20244 0.46333,-0.2396 0.93725,-1.29086 4.67266,-10.36499 l 1.32419,-3.21673 0.73215,-0.004 c 2.76504,-0.0146 4.85892,-2.58236 5.07089,-6.21858 0.0922,-1.58125 -0.1624,-2.40717 -1.2568,-4.07748 -0.7011,-1.07004 -0.70051,-1.07102 0.2726,-0.46008 1.92985,1.2116 3.14626,2.65282 3.78579,4.48546 l 0.27421,0.78576 0.96703,0.24101 c 2.95294,0.73596 3.68649,1.31871 4.93446,3.92012 5.29727,11.04224 -4.91886,23.03684 -18.5873,21.82305 z m -16.21389,-23.1098 c 0.88115,-0.40572 0.99983,-0.41975 0.96485,-0.11404 -0.0333,0.29098 -0.23687,0.3631 -1.04323,0.36958 l -0.48507,0.004 0.56345,-0.25944 z m 9.53481,-5.53368 c 0,-0.039 0.15876,-0.28376 0.35279,-0.54382 0.38008,-0.50943 1.07986,-1.83749 1.41463,-2.68474 0.26778,-0.6777 0.31942,-0.51618 0.36196,1.13203 0.0347,1.34516 0.0672,1.27149 -0.70252,1.59241 -1.09893,0.45816 -1.42686,0.57402 -1.42686,0.50412 z m 29.01598,-6.33777 c 0,-0.31044 0.5907,-0.62124 0.76346,-0.4017 0.34901,0.44351 0.33926,0.46302 -0.2312,0.46302 -0.29274,0 -0.53226,-0.0276 -0.53226,-0.0613 z"
         id="path6867"
         inkscape:connector-curvature="0" />
    </g>
  </g>
</svg>
EOF
}



app::Okteta ()
{
    Meta --desc "Binary editor"

    apt::AddPackages okteta
    gui::AddAppFolder Code org.kde.okteta

    # NACT: Expert > Binary
    local actions=/usr/share/gnome/file-manager/actions
    [[ -d "$actions" ]] || return
    sys::Write <<'EOF' $actions/expert_binary.desktop
[Desktop Entry]
Type=Action
Name=Binary
Icon=nautilus
TargetLocation=true
ToolbarLabel=Binary
Profiles=profile-zero;

[X-Action-Profile profile-zero]
Name=Default profile
Exec=/usr/bin/okteta %F
MimeTypes=all/allfiles;
EOF

}
