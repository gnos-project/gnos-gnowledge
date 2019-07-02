
#   ▞▀▖▙ ▌▞▀▖▞▀▖  ▞▀▖   ▗
#   ▌▄▖▌▌▌▌ ▌▚▄   ▌▄▖▌ ▌▄
#   ▌ ▌▌▝▌▌ ▌▖ ▌  ▌ ▌▌ ▌▐
#   ▝▀ ▘ ▘▝▀ ▝▀   ▝▀ ▝▀▘▀▘


com::Gui  ()
{
    apt::Update

    for i in \
        InstallGnomeShell       \
        InstallFonts            \
        InstallKdeRuntime       \
        InstallJavaRuntime      \
        InstallGnomeExtensions  \
        InstallGnomeFixes       \
        InstallGnomeTheme       \
        InstallGnomeHelpers     \
        InstallBrowserHelper    \
        InstallCodecs           \
        InstallDrivers          ;
    do
        sys::Msg --color "0;34" "Installing ${i}"
        $i
    done

    # ZFS DEBUG
    # str::InList ZFS $STORAGE_OPTIONS && zfs::CreateSnapshot $ZFS_POOL_NAME/$ZFS_ROOT_DSET $PRODUCT_NAME-gui

}

InstallJavaRuntime()
{
    Meta --desc "OpenJDK 8 "

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then

         # TOCHECK more JAVA FONT WORK
         # https://github.com/achaphiv/ppa-fonts/tree/master/openjdk-fontfix
         # http://askubuntu.com/questions/564358/openjdk-8-oracle-jdk-8-font-patches-for-ubuntu

        apt::AddPpaPackages justinludwig/tzdata  tzdata-java # WORKAROUND tzdata-java missing package

        apt::AddPpaPackages --priority 501 \
            no1wantdthisname/openjdk-fontfix \
            openjdk-8-jre openjdk-8-jre-headless

        chown -hv 1000:1000 $HOME/.wget-hsts

    # TODO SKEL

    else
        apt::AddRemotePackages \
            https://launchpad.net/ubuntu/+archive/primary/+files/libpng12-0_1.2.54-1ubuntu1_amd64.deb
        apt::AddPpaPackages --release xenial --priority 501 \
            no1wantdthisname/openjdk-fontfix \
            openjdk-8-jre openjdk-8-jre-headless

        chown -hv 1000:1000 $HOME/.wget-hsts

    fi

    # gui::AddAppFolder Engines openjdk-8-policytool
    gui::HideApps openjdk-8-policytool
    gui::HideApps openjdk-11-policytool

    # BASH env
    local bashrc=$HOME/.bashrc
    [[ -d "$HOME/.bashrc.d" ]] && bashrc=$HOME/.bashrc.d/env.java
    sys::Write --append <<'EOF' "$bashrc" 1000:1000 700
export _JAVA_OPTIONS="-Dawt.useSystemAAFontSettings=lcd -Dsun.java2d.xrender=true -Dswing.aatext=true -Dswing.defaultlaf=com.sun.java.swing.plaf.gtk.GTKLookAndFeel"
export JAVA_FONTS=/usr/share/fonts/truetype

# TIP: Font rendering options:
# -Dawt.useSystemAAFontSettings=on|lcd|gasp
# -Dsun.java2d.xrender=true
# -Dsun.java2d.dpiaware=false
# -Dswing.aatext=true
# -Dswing.defaultlaf=com.sun.java.swing.plaf.gtk.GTKLookAndFeel
EOF

    # Default jvm
    update-alternatives --set java /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java

    # TIPS
    # xdg-mime query default application/x-java-archive
    # xdg-mime query filetype my_app.jar

}


InstallKdeRuntime ()
{
    apt::AddPackages kdelibs-bin kdelibs5-plugins kde-runtime kde-runtime-data

    # Disable KDE deamons
    for bin in                  \
        /usr/bin/knotify4       \
        /usr/bin/kuiserver      \
        /usr/bin/kwalletd       \
        /usr/bin/kwalletd5      \
        /usr/bin/kded4          \
        /usr/bin/kded5          \
        /usr/bin/kdeinit5       \
        /usr/bin/kdeinit4       \
    ; do [[ -x "$bin" ]] && chmod -x $bin ; done

    # Mask kmailservice
    gui::HideApps kde4-kmailservice kmailservice5 # kmailservice

    sys::Write <<EOF $HOME/.kde/share/config/kdeglobals 1000:1000
[\$Version]
update_info=kdeui.upd:kde4/migrate_from_kde3_icon_theme

[KDE]
ShowIconsInMenuItems=true
ShowIconsOnPushButtons=true

[Appmenu Style]
Style=InApplication
contrast=0

[Toolbar style]
ToolButtonStyle=TextBesideIcon
ToolButtonStyleOtherToolbars=TextBesideIcon

[General]
widgetStyle=gtk+
XftHintStyle=hintmedium
shadeSortColumn=true
EOF
    # $HOME/.config/kdeglobals
    pushd $HOME/.config/
    ln -s ../.kde/share/config/kdeglobals
    chown -hR 1000:1000 kdeglobals
    popd

    # SKEL
    mkdir -p /etc/skel/.kde/share/config
    cp $HOME/.kde/share/config/kdeglobals /etc/skel/.kde/share/config
    chown -hR 0:0 /etc/skel/.kde/share/config/kdeglobals

    # POSTINST
    sys::Write <<'EOF' --append "$POSTINST_USER_SESSION_SCRIPT"
which kbuildsycoca4 && kbuildsycoca4 --noincremental --nosignal
which kbuildsycoca5 && kbuildsycoca5 --noincremental --nosignal
# update-desktop-database -v /usr/local/share/applications
EOF

}


InstallGnomeShell ()
{
    # DOC: gnome-shell versions
    # RELEASE   UG-PPA   REPO
    # bionic             3.26
    # xenial    3.20     3.19
    # trusty    3.14     3.12*

    mkdir -p /usr/local/share/applications

    # TOCHECK groups: adm dialout cdrom floppy plugdev # scanner
    # adduser $( id -nu 1000 )

    # Fresh graphics
    if ! grep -q VirtualBox /proc/bus/input/devices ; then  # WORKAROUND: Virtualbox MESA issues

        apt::AddPpa oibaf/graphics-drivers

        [[ "$INSTALL_FREE" != "1" ]] && apt::AddPpa graphics-drivers/ppa

    fi

    # Fresh gnome
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpa gnome3-team/gnome3-staging
    fi


    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then

# TOCHECK
# xserver-xorg-hwe-16.04
# xserver-xorg-video-all-hwe-16.04
# xserver-xorg-video-intel-hwe-16.04
# xserver-xorg-input-all-hwe-16.04 OR xserver-xorg-input-synaptics-hwe-16.04 # TOCHECK xserver-xorg-input-mtrack-hwe-16.04

        apt::AddPackages \
            xserver-xorg xserver-xorg-core \
            x11-xserver-utils x11-utils xinput xvfb \
            xserver-xorg-video-all xserver-xorg-video-intel xserver-xorg-input-evdev \
            gnome-shell gnome-session session-migration \
            libglib2.0-bin libcanberra-gtk-module libcanberra-gtk3-module \
            gtk2-engines-pixbuf gtk2-engines-murrine gnome-themes-standard-data \
            policykit-1-gnome policykit-desktop-privileges gksu \
            notification-daemon gir1.2-notify-0.7 libnotify-bin \
            gvfs-bin network-manager-gnome iputils-arping avahi-daemon \
            upower rtkit dconf-cli \
            pulseaudio-module-x11
    else

        apt::AddPackages \
            xserver-xorg xserver-xorg-core \
            x11-xserver-utils x11-utils xinput xvfb \
            xserver-xorg-video-all xserver-xorg-video-intel xserver-xorg-input-evdev \
            gnome-shell gnome-session session-migration \
            libglib2.0-bin libcanberra-gtk-module libcanberra-gtk3-module \
            gtk2-engines-pixbuf gtk2-engines-murrine gnome-themes-standard-data \
            policykit-1-gnome policykit-desktop-privileges \
            notification-daemon gir1.2-notify-0.7 libnotify-bin \
            gvfs-bin network-manager-gnome iputils-arping avahi-daemon \
            upower rtkit dconf-cli \
            pulseaudio
    fi

    # Mask services
    systemctl mask avahi-daemon.socket
    systemctl mask avahi-daemon.service


    # nodm
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPackages nodm
        sys::Write /etc/X11/default-display-manager <<<"/usr/sbin/nodm"
        sys::SedInline 's#^(NODM_USER=).*#\1'"$USER_USERNAME"'#' /etc/default/nodm
        sys::SedInline 's#^(NODM_ENABLED=).*#\1true#' /etc/default/nodm
        sys::Write <<'EOF' /lib/systemd/system/nodm.service 644 # FROM bionic
[Unit]
Description=Display manager for automatic session logins
Documentation=man:nodm(8)
After=plymouth-quit.service systemd-user-sessions.service

[Service]
EnvironmentFile=-/etc/default/nodm
# 77 is EX_NOPERM, and doesn't seem to be used by nodm itself
# Don't respawn or mark as failed if disabled via /etc/default/nodm
RestartPreventExitStatus=77
SuccessExitStatus=77
ExecStart=/bin/sh -c 'if test ${NODM_ENABLED} = no || test ${NODM_ENABLED} = false; then exit 77; else exec /usr/sbin/nodm $NODM_OPTIONS; fi'
Restart=always
KillMode=mixed
TimeoutStopSec=10
# Debian-specific change until all display managers participate in /etc/X11/default-display-manager
ExecStartPre=/bin/sh -c '[ "$(cat /etc/X11/default-display-manager 2>/dev/null)" = "/usr/sbin/nodm" ]'
EOF
        ln -s /lib/systemd/system/nodm.service /etc/systemd/system/display-manager.service
        sys::Chk
    else
        apt::AddSelection "nodm nodm/user string $USER_USERNAME"
        apt::AddSelection "nodm nodm/enabled boolean true"

        # DOC: nodm selections
        # # X session to use:
        # nodm nodm/xsession string /etc/X11/Xsession
        # # Maximum time (in seconds) to wait for X to start:
        # nodm nodm/x_timeout string 300
        # # Options for the X server:
        # nodm nodm/x_options string -nolisten tcp
        # # Default display manager:
        # nodm shared/default-x-display-manager select  nodm
        # # Minimum time (in seconds) for a session to be considered OK:
        # nodm nodm/min_session_time string 60
        # # Lowest numbered vt on which X may start:
        # nodm nodm/first_vt string 7

        apt::AddPackages nodm
    fi


    apt::Upgrade

    mkdir -p \
        $HOME/.cache/dconf \
        $HOME/.config/autostart/ \
        $HOME/.local/share/gnome-shell/extensions/
    chown -hR 1000:1000  $HOME/{.cache,.config,.local}


    sys::Write $HOME/.config/gtk-3.0/settings.ini <<<"[Settings]" 1000:1000

    sys::Touch $HOME/.Xauthority 1000:1000 700
    sudo --set-home -u \#1000 xauth generate :0 . trusted


    # xterm
    apt::AddPackages xterm
    gui::HideApps debian-xterm debian-uxterm
    sys::Write <<'EOF' /usr/local/share/applications/terminal.desktop 1000:1000 750
[Desktop Entry]
Name=Terminal
Exec=uxterm
Terminal=false
Type=Application
Icon=terminal
Categories=System;TerminalEmulator;Utility;
EOF

    sys::Write --append <<'EOF' $HOME/.Xresources 1000:1000 750
xterm*saveLines: 64000
xterm*VT100.translations: #override <Btn1Up>: select-end(PRIMARY, CLIPBOARD, CUT_BUFFER0)
EOF


    # Default AppFolders
    gui::AddAppFolder Settings      gnome-session-properties
    gui::AddAppFolder Code          vim
    gui::AddAppFolder Accessories   htop
    gui::AddAppFolder Accessories   terminal



    # Create migration script (all users)
    sys::Write <<'EOF' "$POSTINST_USER_SESSION_SCRIPT" 0:0 755
#!/bin/bash

# DEV: This script runs once to configure some gsettings before Gnome Shell starts

# DEBUG
exec &>/tmp/$(basename "$0" .sh)_$$.log
set -x

EOF

    # First login script launcher
    # DEV: auto-disable
    sys::Write <<EOF "$POSTINST_USER_START_LAUNCHER" 1000:1000 755
[Desktop Entry]
Type=Application
Exec=bash -c 'sleep 2 ; bash "$POSTINST_USER_START_SCRIPT" && mv "$POSTINST_USER_START_LAUNCHER"{,.DISABLED} ; '
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=$( basename "$POSTINST_USER_START_SCRIPT" .sh )
Comment=
EOF
    # First login script
    apt::AddPackages toilet toilet-fonts
    sys::Write <<EOF "$POSTINST_USER_START_SCRIPT" 0:0 644  # DEV: not executable
#!/bin/bash

# DEV: This script is used to configure some gsettings - otherwise unreachable -
# once gnome started, then restart Gnome Shell on completion, then run
# PostInstallAdditional

# Register EXIT trap: Gnome Shell restart via dbus
trap "
    dbus-send --type=method_call --print-reply --dest=org.gnome.Shell \\
        /org/gnome/Shell org.gnome.Shell.Eval string:'global.reexec_self()' ;
    gnome-terminal --full-screen -e \\
        bash -c 'sleep 5 ; paste /usr/share/themes/$THEME_GS/branding/logo.ansi /dev/fd/0 < <(echo ;toilet --font smblock POST INSTALL ; echo ▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃▃; echo ; echo Enter password to proceed ) ; sudo /usr/local/sbin/gnowledge --config /etc/$PRODUCT_NAME.conf Internal PostInstallAdditional'
    " \
    EXIT

# DEBUG
exec &>/tmp/\$(basename "\$0" .sh)_\$\$.log

# WAIT for extensions loading
sleep 5

# WORKAROUND: pref panel opens at first run
killall gnome-shell-extension-prefs 2>/dev/null

set -x
EOF

    # Create a dconf local Profile (defaults for all users)
    # DEV: allows configuring defaults for relocatables schemes
    if ! [[ -f /etc/dconf/profile/user ]] ; then
        sys::Write <<EOF /etc/dconf/profile/user
user-db:user
system-db:local
EOF
        sys::Mkdir /etc/dconf/db/
    fi


}

post::GuiCustomCorner ()
{
    chmod a+w /usr/share/gnome-shell/extensions/customcorner@eccheng.gitlab.com/command_errors.log
    sys::Chk
}


InstallGnomeExtensions ()
{


    ###########
    # THEMING #
    ###########

    # EXT:  User Themes
    gui::AddShellExtensionsById 19


    ############
    # MONITORS #
    ############

    # EXT: fix-multi-monitors
    # DEV: only usefull for old gnome on xenial (monitor.xml version 1)
    # DEV: not needed on bionic (monitor.xml version 2)
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then

        sudo --set-home -u \#1000 gnome-shell-extension-installer --yes 1066

        local umpScript="/usr/local/bin/update-monitor-position"
        local umpLaunch="$HOME/.local/share/gnome-shell/extensions/fix-multi-monitors@kirby_33@hotmail.fr/update-monitor-position"
        sys::Write <<EOF $umpLaunch 1000:1000 775
#!/bin/bash
exec $umpScript
EOF
        sys::Write <<'EOF' $umpScript 0:0 755
#!/bin/bash
# DESC  Get monitors configuration from monitor.xml and apply it for current user session.
# DOC   http://bernaerts.dyndns.org/linux/74-ubuntu/309-ubuntu-dual-display-monitor-position-lost

# INIT
MONITOR_XML="$HOME/.config/monitors.xml"
[[ -f "$MONITOR_XML" ]] || exit 1
[[ "$( xmllint --xpath 'string(//monitors/@version)' $MONITOR_XML )" == "1" ]] || exit 1

# MAIN

NUM=$(xmllint --xpath 'count(//monitors/configuration['1']/output)' $MONITOR_XML)
[[ -n "$NUM" ]] || exit 1

# loop thru declared monitors to create the command line parameters
for (( i=1; i<=$NUM; i++)); do

  # get attributes of current monitor (name and x & y positions)
  NAME=$(xmllint --xpath 'string(//monitors/configuration['1']/output['$i']/@name)' $MONITOR_XML 2>/dev/null)
  POS_X=$(xmllint --xpath '//monitors/configuration['1']/output['$i']/x/text()' $MONITOR_XML 2>/dev/null)
  POS_Y=$(xmllint --xpath '//monitors/configuration['1']/output['$i']/y/text()' $MONITOR_XML 2>/dev/null)
  ROTATE=$(xmllint --xpath '//monitors/configuration['1']/output['$i']/rotation/text()' $MONITOR_XML 2>/dev/null)
  WIDTH=$(xmllint --xpath '//monitors/configuration['1']/output['$i']/width/text()' $MONITOR_XML 2>/dev/null)
  HEIGHT=$(xmllint --xpath '//monitors/configuration['1']/output['$i']/height/text()' $MONITOR_XML 2>/dev/null)
  RATE=$(xmllint --xpath '//monitors/configuration['1']/output['$i']/rate/text()' $MONITOR_XML 2>/dev/null)
  PRIMARY=$(xmllint --xpath '//monitors/configuration['1']/output['$i']/primary/text()' $MONITOR_XML 2>/dev/null)

  # if position is defined for current monitor, add its position and orientation to command line parameters
  [ -n "$POS_X" ] && PARAM_ARR=("${PARAM_ARR[@]}" "--output" "$NAME" "--pos" "${POS_X}x${POS_Y}" "--fbmm" "${WIDTH}x${HEIGHT}" "--rate" "$RATE" "--rotate" "$ROTATE")

  # if monitor is defined as primary, adds it to command line parameters
  [ "$POS_X" == "0" ] && [ "$POS_Y" == "0" ] && PARAM_ARR=("${PARAM_ARR[@]}" "--primary")

done

# if needed, wait for some seconds (for X to finish initialisation)
[ -n "$1" ] && sleep $1

# position all monitors
xrandr "${PARAM_ARR[@]}"
EOF
    fi

    ###########
    # CORNERS #
    ###########

    # EXT: CustomCorner
    gui::AddShellExtensionsById 1037
    cp /usr/share/gnome-shell/extensions/customcorner@eccheng.gitlab.com/settings/*.gschema.xml \
        /usr/share/glib-2.0/schemas/
    glib-compile-schemas /usr/share/glib-2.0/schemas/
    RegisterPostInstall post::GuiCustomCorner 99
    sys::Write <<'EOF' --append "$POSTINST_USER_START_SCRIPT"
gsettings set org.gnome.shell.extensions.CustomCorner   top-left-action                       'Show Apps Grid'
gsettings set org.gnome.shell.extensions.CustomCorner   top-right-action                      'Show Overview'
gsettings set org.gnome.shell.extensions.CustomCorner   bottom-right-action                   'Show Desktop'
gsettings set org.gnome.shell.extensions.CustomCorner   bottom-left-action                    'Run Command...'
gsettings set org.gnome.shell.extensions.CustomCorner   bottom-left-command                   'xset dpms force off'
EOF
    # gui::AddExtensionSwitch hotcorners "customcorner@eccheng.gitlab.com" 0



    ###########
    # WINDOWS #
    ###########

    # EXT: Focus my window
    gui::AddShellExtensionsById 1005

    # EXT: instant-switcher-popups
    gui::AddShellExtensionsById 1199

    # EXT: Alternate tab
    gui::AddShellExtensionsById 15

    # EXT: ShellTile
    gui::AddShellExtensionsById 657
    sys::Write <<EOF --append "$POSTINST_USER_SESSION_SCRIPT"
gsettings set org.gnome.shell.extensions.shelltile gap-between-windows 0
EOF

    # EXT: Window Corner Preview
    gui::AddShellExtensionsById --nodefault 1227


    ##############
    # WORKSPACES #
    ##############

    # EXT: Workspace Switch Wraparound
    gui::AddShellExtensionsById 1116

    # EXT: Workspace Switcher
    gui::AddShellExtensionsByUrl \
        "https://github.com/Tomha/gnome-shell-extension-workspace-switcher/archive/master.zip"
    sys::Write <<EOF --append "$POSTINST_USER_SESSION_SCRIPT"
gsettings set org.gnome.shell.extensions.workspace-switcher index 3
gsettings set org.gnome.shell.extensions.workspace-switcher show-names false
gsettings set org.gnome.shell.extensions.workspace-switcher click-action 'POPUP'
gsettings set org.gnome.shell.extensions.workspace-switcher background-colour-active '#00000000'
gsettings set org.gnome.shell.extensions.workspace-switcher padding-horizontal 5
gsettings set org.gnome.shell.extensions.workspace-switcher border-radius 5
gsettings set org.gnome.shell.extensions.workspace-switcher font-active "$THEME_FONT_WINDOW_NAME 9"
EOF


    ############
    # OVERVIEW #
    ############


    # EXT: switcher
    gui::AddShellExtensionsById 973
    sys::Write <<'EOF' --append "$POSTINST_USER_SESSION_SCRIPT"
gsettings set org.gnome.shell.extensions.switcher activate-immediately true
gsettings set org.gnome.shell.extensions.switcher font-size 16
gsettings set org.gnome.shell.extensions.switcher icon-size 20
gsettings set org.gnome.shell.extensions.switcher matching 1
gsettings set org.gnome.shell.extensions.switcher max-width-percentage 100
gsettings set org.gnome.shell.extensions.switcher onboarding-1 1
gsettings set org.gnome.shell.extensions.switcher onboarding-2 1
gsettings set org.gnome.shell.extensions.switcher onboarding-3 1
gsettings set org.gnome.shell.extensions.switcher onboarding-4 1
gsettings set org.gnome.shell.extensions.switcher onboarding-5 1
gsettings set org.gnome.shell.extensions.switcher onboarding-6 1
gsettings set org.gnome.shell.extensions.switcher only-current-workspace false
gsettings set org.gnome.shell.extensions.switcher ordering 1
gsettings set org.gnome.shell.extensions.switcher show-launcher "['<Super>space']"
gsettings set org.gnome.shell.extensions.switcher show-switcher "['<Shift><Super>space']"
gsettings set org.gnome.shell.extensions.switcher workspace-indicator false
EOF

    # EXT: windowoverlay-icons
    gui::AddShellExtensionsById 302
    sys::Write <<'EOF' --append "$POSTINST_USER_SESSION_SCRIPT"
# UNUSED gsettings set org.gnome.shell.extensions.windowoverlay-icons background-color '#cece5c5c0000'
gsettings set org.gnome.shell.extensions.windowoverlay-icons background-alpha 0
gsettings set org.gnome.shell.extensions.windowoverlay-icons icon-opacity-blur 255
gsettings set org.gnome.shell.extensions.windowoverlay-icons icon-opacity-focus 255
gsettings set org.gnome.shell.extensions.windowoverlay-icons icon-size 64
gsettings set org.gnome.shell.extensions.windowoverlay-icons icon-horizontal-alignment 'right'
gsettings set org.gnome.shell.extensions.windowoverlay-icons icon-vertical-alignment 'bottom'
EOF

    # EXT: applications-overview-tooltip
    gui::AddShellExtensionsById 1071
    sys::Write <<'EOF' --append "$POSTINST_USER_SESSION_SCRIPT"
gsettings set org.gnome.shell.extensions.applications-overview-tooltip appdescription false
gsettings set org.gnome.shell.extensions.applications-overview-tooltip alwaysshow false
gsettings set org.gnome.shell.extensions.applications-overview-tooltip borders false
gsettings set org.gnome.shell.extensions.applications-overview-tooltip hoverdelay 0
gsettings set org.gnome.shell.extensions.applications-overview-tooltip labelhidetime 0
gsettings set org.gnome.shell.extensions.applications-overview-tooltip labelshowtime 0
EOF
    sed -E -i \
        -e 's/^(\s*background-color:) .*/\1rgba('"$THEME_COLOR_SELECT_RGB"',1);/' \
        -e 's/^(\s*border-radius:) .*/\12px;/' \
        -e 's/^(\s*font-weight:) .*/\1normal;/' \
        -e 's/^(\s*font-size:) .*/\112pt;/' \
        "/usr/share/gnome-shell/extensions/applications-overview-tooltip@RaphaelRochet/stylesheet.css"


    # EXT appfolders-manager
    gui::AddShellExtensionsById 1217



    #############
    # TOP PANEL #
    #############


    # EXT: extend-panel-menu
    gui::AddShellExtensionsById 1201
    sys::Write <<'EOF' --append "$POSTINST_USER_SESSION_SCRIPT"
gsettings set org.gnome.shell.extensions.extend-panel-menu autohide-notification            true
gsettings set org.gnome.shell.extensions.extend-panel-menu items                            'Night Light Indicator [GNOME Shell>=3.24];0;0;nightlight|Volume Indicator;1;0;volume|Network Indicator;1;0;network|Power(Brightness) Indicator;1;0;power|User Indicator;1;0;user|Calendar Indicator;1;0;calendar|Notification Indicator;1;0;notification'
gsettings set org.gnome.shell.extensions.extend-panel-menu spacing                          0
gsettings set org.gnome.shell.extensions.extend-panel-menu user-icon                        true
EOF
    # BUG: lost GSConnect
    # BUG: lost Calendard events
    # BUG: null Wifi list
    # BUG: duplicate Sound+Laine
    # LAINE gsettings set org.gnome.shell.extensions.extend-panel-menu items                            'Night Light Indicator [GNOME Shell>=3.24];0;0;nightlight|Volume Indicator;0;0;volume|Network Indicator;1;0;network|Power(Brightness) Indicator;1;0;power|User Indicator;1;0;user|Calendar Indicator;1;0;calendar|Notification Indicator;1;0;notification'
    #gnome-shell-extension-tool -d extend-panel-menu@julio641742



    # EXT: No Title Bar
    gui::AddShellExtensionsById 1267
    sys::Write <<EOF --append "$POSTINST_USER_SESSION_SCRIPT"
gsettings set org.gnome.shell.extensions.no-title-bar app-menu-width    1000
gsettings set org.gnome.shell.extensions.no-title-bar automatic-theme   false
gsettings set org.gnome.shell.extensions.no-title-bar button-position   'after-app-menu'
gsettings set org.gnome.shell.extensions.no-title-bar hide-buttons      false
gsettings set org.gnome.shell.extensions.no-title-bar only-main-monitor false
gsettings set org.gnome.shell.extensions.no-title-bar theme             '$THEME_GTK'
EOF


    # EXT: Lock Keys
    gui::AddShellExtensionsById 36
    sys::Write <<'EOF' --append "$POSTINST_USER_SESSION_SCRIPT"
gsettings set org.gnome.shell.extensions.lockkeys style 'show-hide'
EOF

    # EXT Datetime Format
    gui::AddShellExtensionsById 1173
    sys::Write <<'EOF' --append "$POSTINST_USER_SESSION_SCRIPT"
gsettings set org.gnome.shell.extensions.datetime-format datemenudate-format    '%F %T'
gsettings set org.gnome.shell.extensions.datetime-format datemenuday-format     '%A, %B %-e'
gsettings set org.gnome.shell.extensions.datetime-format statusbar-format       '%a %-d %H:%M'
EOF
    cp  /usr/share/gnome-shell/extensions/datetime-format@Daniel-Khodabakhsh.github.com/settings.gschema.xml \
        /usr/share/glib-2.0/schemas/


    # EXT: icon-hider
    gui::AddShellExtensionsById 351
    sys::Write <<'EOF' --append "$POSTINST_USER_SESSION_SCRIPT"
gsettings set org.gnome.shell.extensions.icon-hider hidden               "['a11y','keyboard','activities']"
gsettings set org.gnome.shell.extensions.icon-hider is-indicator-shown   false
EOF

    # EXT: NetSpeed
    gui::AddShellExtensionsById --nodefault 104
    sys::Write <<'EOF' --append "$POSTINST_USER_SESSION_SCRIPT"
gsettings set org.gnome.shell.extensions.netspeed show-sum                      true
EOF


    # EXT: system-monitor config
    apt::AddPackages gir1.2-gtop-2.0 lm-sensors # gir1.2-networkmanager-1.0
    # OLD gui::AddShellExtensionsById 120
    gui::AddShellExtensionsByUrl \
        "https://github.com/paradoxxxzero/gnome-shell-system-monitor-applet/archive/master.zip"

    sed -E -i 's#gnome-system-monitor(\.desktop)+#htop\1#' \
        /usr/share/gnome-shell/extensions/system-monitor@paradoxxx.zero.gmail.com/extension.js

    sys::Write <<EOF --append "$POSTINST_USER_START_SCRIPT"
gsettings set org.gnome.shell.extensions.system-monitor background '#${THEME_COLOR_BACKGD_HEX}00'
gsettings set org.gnome.shell.extensions.system-monitor center-display false
gsettings set org.gnome.shell.extensions.system-monitor compact-display true
gsettings set org.gnome.shell.extensions.system-monitor icon-display false
gsettings set org.gnome.shell.extensions.system-monitor show-tooltip false

gsettings set org.gnome.shell.extensions.system-monitor cpu-display true
gsettings set org.gnome.shell.extensions.system-monitor cpu-graph-width 40
gsettings set org.gnome.shell.extensions.system-monitor cpu-individual-cores false
gsettings set org.gnome.shell.extensions.system-monitor cpu-iowait-color '#${THEME_COLOR_HOTHOT_HEX}'
gsettings set org.gnome.shell.extensions.system-monitor cpu-nice-color '#${THEME_COLOR_HOTHOT_HEX}'
gsettings set org.gnome.shell.extensions.system-monitor cpu-other-color '#${THEME_COLOR_HOTHOT_HEX}'
gsettings set org.gnome.shell.extensions.system-monitor cpu-refresh-time 1500
gsettings set org.gnome.shell.extensions.system-monitor cpu-show-menu true
gsettings set org.gnome.shell.extensions.system-monitor cpu-show-text false
gsettings set org.gnome.shell.extensions.system-monitor cpu-style 'graph'
gsettings set org.gnome.shell.extensions.system-monitor cpu-system-color '#${THEME_COLOR_HOTHOT_HEX}'
gsettings set org.gnome.shell.extensions.system-monitor cpu-user-color '#${THEME_COLOR_SELECT_HEX}'

gsettings set org.gnome.shell.extensions.system-monitor memory-display true
gsettings set org.gnome.shell.extensions.system-monitor memory-graph-width 6
gsettings set org.gnome.shell.extensions.system-monitor memory-refresh-time 1500
gsettings set org.gnome.shell.extensions.system-monitor memory-buffer-color '#${THEME_COLOR_HOTHOT_HEX}'
gsettings set org.gnome.shell.extensions.system-monitor memory-cache-color '#${THEME_COLOR_HOTHOT_HEX}'
gsettings set org.gnome.shell.extensions.system-monitor memory-program-color '#${THEME_COLOR_OKOKOK_HEX}'
gsettings set org.gnome.shell.extensions.system-monitor memory-show-text false

gsettings set org.gnome.shell.extensions.system-monitor swap-display false
gsettings set org.gnome.shell.extensions.system-monitor swap-graph-width 6
gsettings set org.gnome.shell.extensions.system-monitor swap-show-text false


gsettings set org.gnome.shell.extensions.system-monitor net-display false
gsettings set org.gnome.shell.extensions.system-monitor net-collisions-color '#${THEME_COLOR_HOTHOT_HEX}'
gsettings set org.gnome.shell.extensions.system-monitor net-down-color '#${THEME_COLOR_OKOKOK_HEX}'
gsettings set org.gnome.shell.extensions.system-monitor net-downerrors-color '#${THEME_COLOR_HOTHOT_HEX}'
gsettings set org.gnome.shell.extensions.system-monitor net-graph-width 40
gsettings set org.gnome.shell.extensions.system-monitor net-refresh-time 1500
gsettings set org.gnome.shell.extensions.system-monitor net-show-menu false
gsettings set org.gnome.shell.extensions.system-monitor net-show-text false
gsettings set org.gnome.shell.extensions.system-monitor net-speed-in-bits false
gsettings set org.gnome.shell.extensions.system-monitor net-style 'graph'
gsettings set org.gnome.shell.extensions.system-monitor net-up-color '#${THEME_COLOR_MANAGE_HEX}'
gsettings set org.gnome.shell.extensions.system-monitor net-uperrors-color '#${THEME_COLOR_HOTHOT_HEX}'

gsettings set org.gnome.shell.extensions.system-monitor battery-display false
gsettings set org.gnome.shell.extensions.system-monitor disk-display false
gsettings set org.gnome.shell.extensions.system-monitor disk-show-menu false
gsettings set org.gnome.shell.extensions.system-monitor disk-usage-style 'bar'
gsettings set org.gnome.shell.extensions.system-monitor fan-display false
gsettings set org.gnome.shell.extensions.system-monitor freq-display false
gsettings set org.gnome.shell.extensions.system-monitor memory-display false
gsettings set org.gnome.shell.extensions.system-monitor thermal-display false
gsettings set org.gnome.shell.extensions.system-monitor thermal-sensor-file '/dev/null'
gsettings set org.gnome.shell.extensions.system-monitor thermal-graph-width 6
EOF


    # EXT: Dash to panel
    gui::AddShellExtensionsById 1160
    sys::Write <<EOF --append "$POSTINST_USER_SESSION_SCRIPT"
gsettings set org.gnome.shell.extensions.dash-to-panel animate-app-switch                   false
gsettings set org.gnome.shell.extensions.dash-to-panel animate-show-apps                    false
gsettings set org.gnome.shell.extensions.dash-to-panel animate-window-launch                false
gsettings set org.gnome.shell.extensions.dash-to-panel appicon-margin                       0
gsettings set org.gnome.shell.extensions.dash-to-panel appicon-padding                      0
gsettings set org.gnome.shell.extensions.dash-to-panel dot-color-override                   true
gsettings set org.gnome.shell.extensions.dash-to-panel dot-color-1                          '#${THEME_COLOR_BACKGD_HEX}00'
gsettings set org.gnome.shell.extensions.dash-to-panel dot-color-2                          '#$THEME_COLOR_BACKGD_HEX'
gsettings set org.gnome.shell.extensions.dash-to-panel dot-color-3                          '#$THEME_COLOR_BACKGD_HEX'
gsettings set org.gnome.shell.extensions.dash-to-panel dot-color-4                          '#$THEME_COLOR_BACKGD_HEX'
gsettings set org.gnome.shell.extensions.dash-to-panel dot-color-unfocused-different        true
gsettings set org.gnome.shell.extensions.dash-to-panel dot-color-unfocused-1                '#${THEME_COLOR_HOTHOT_HEX}00'
gsettings set org.gnome.shell.extensions.dash-to-panel dot-color-unfocused-2                '#$THEME_COLOR_HOTHOT_HEX'
gsettings set org.gnome.shell.extensions.dash-to-panel dot-color-unfocused-3                '#$THEME_COLOR_HOTHOT_HEX'
gsettings set org.gnome.shell.extensions.dash-to-panel dot-color-unfocused-4                '#$THEME_COLOR_HOTHOT_HEX'
gsettings set org.gnome.shell.extensions.dash-to-panel dot-position                         'TOP'
gsettings set org.gnome.shell.extensions.dash-to-panel dot-position                         'TOP'
gsettings set org.gnome.shell.extensions.dash-to-panel dot-style-focused                    'DOTS'
gsettings set org.gnome.shell.extensions.dash-to-panel dot-style-unfocused                  'DOTS'
gsettings set org.gnome.shell.extensions.dash-to-panel dot-size                             2
gsettings set org.gnome.shell.extensions.dash-to-panel enter-peek-mode-timeout              0
gsettings set org.gnome.shell.extensions.dash-to-panel focus-highlight                      true
gsettings set org.gnome.shell.extensions.dash-to-panel focus-highlight-color                '#$THEME_COLOR_HOTHOT_HEX'
gsettings set org.gnome.shell.extensions.dash-to-panel focus-highlight-opacity              100
gsettings set org.gnome.shell.extensions.dash-to-panel isolate-workspaces                   true
gsettings set org.gnome.shell.extensions.dash-to-panel leave-timeout                        0
gsettings set org.gnome.shell.extensions.dash-to-panel leftbox-padding                      0
gsettings set org.gnome.shell.extensions.dash-to-panel leftbox-size                         0
gsettings set org.gnome.shell.extensions.dash-to-panel middle-click-action                  'QUIT'
gsettings set org.gnome.shell.extensions.dash-to-panel panel-position                       'TOP'
gsettings set org.gnome.shell.extensions.dash-to-panel panel-size                           28
gsettings set org.gnome.shell.extensions.dash-to-panel peek-mode-opacity                    0
gsettings set org.gnome.shell.extensions.dash-to-panel secondarymenu-contains-showdetails   false
gsettings set org.gnome.shell.extensions.dash-to-panel shift-click-action                   'MINIMIZE'
gsettings set org.gnome.shell.extensions.dash-to-panel shift-middle-click-action            'LAUNCH'
gsettings set org.gnome.shell.extensions.dash-to-panel show-activities-button               false
gsettings set org.gnome.shell.extensions.dash-to-panel show-apps-icon-file                  '/usr/share/themes/$THEME_GS/branding/logo.svg'
gsettings set org.gnome.shell.extensions.dash-to-panel show-apps-icon-side-padding          0
gsettings set org.gnome.shell.extensions.dash-to-panel show-appmenu                         true
gsettings set org.gnome.shell.extensions.dash-to-panel show-favorites                       true
gsettings set org.gnome.shell.extensions.dash-to-panel show-showdesktop-button              false
gsettings set org.gnome.shell.extensions.dash-to-panel show-window-previews-timeout         0
gsettings set org.gnome.shell.extensions.dash-to-panel status-icon-padding                  1
gsettings set org.gnome.shell.extensions.dash-to-panel trans-bg-color                       '#$THEME_COLOR_BACKGD_HEX'
gsettings set org.gnome.shell.extensions.dash-to-panel trans-dynamic-anim-time              0
gsettings set org.gnome.shell.extensions.dash-to-panel trans-dynamic-anim-target            1.0
gsettings set org.gnome.shell.extensions.dash-to-panel trans-dynamic-behavior               'MAXIMIZED_WINDOWS'
gsettings set org.gnome.shell.extensions.dash-to-panel trans-use-dynamic-opacity            true
gsettings set org.gnome.shell.extensions.dash-to-panel trans-panel-opacity                  0.4
gsettings set org.gnome.shell.extensions.dash-to-panel trans-use-custom-bg                  true
gsettings set org.gnome.shell.extensions.dash-to-panel trans-use-custom-opacity             true
gsettings set org.gnome.shell.extensions.dash-to-panel tray-padding                         1
gsettings set org.gnome.shell.extensions.dash-to-panel window-preview-padding               5
gsettings set org.gnome.shell.extensions.dash-to-panel window-preview-height                180
gsettings set org.gnome.shell.extensions.dash-to-panel window-preview-width                 300
EOF
    # Theming
    sys::Write --append <<EOF /usr/share/gnome-shell/extensions/dash-to-panel@jderose9.github.com/stylesheet.css

/* $PRODUCT_NAME theming */

#dashtopanelTaskbar .show-apps .overview-icon
{
    border-radius: 0px;
    padding-left: 2px;
    padding-right: 2px;
}

#dashtopanelScrollview .dtp-icon-container {
    padding: 2px;
}


#dashtopanelScrollview .app-well-app {
    spacing: 0px;
}

#dashtopanelScrollview .app-well-app .overview-label {
    padding-left: 0px;
    padding-right: 0px;
    margin: 0;
}

#dashtopanelScrollview .app-well-app:hover {
    background-color: #$THEME_COLOR_SELECT_HEX;
}

.app-well-menu {
    border-image: none;
    background-color: #$THEME_COLOR_SELECT_HEX;
  }

.app-well-menu .popup-menu-item:active, .app-well-menu .popup-menu-item.selected {
    background-color: rgba(255, 255, 255, .15);
    border-image: none;
}

EOF



    # EXT: topicons plus
    # BUG: CPU hanging with system-monitor
    gui::AddShellExtensionsById 1031
    sys::Write <<'EOF' --append "$POSTINST_USER_SESSION_SCRIPT"
gsettings set org.gnome.shell.extensions.topicons icon-spacing         0
gsettings set org.gnome.shell.extensions.topicons icon-size            20
gsettings set org.gnome.shell.extensions.topicons tray-pos             'right'
gsettings set org.gnome.shell.extensions.topicons icon-saturation      0.3
gsettings set org.gnome.shell.extensions.topicons icon-brightness      -0.2
gsettings set org.gnome.shell.extensions.topicons icon-contrast        0.4
EOF
    # PATCH panel position
    sys::SedInline 's#(box\.insert_child_at_index\(iconsContainer\.actor,) index\)#\1 3)#' \
        /usr/share/gnome-shell/extensions/TopIcons@phocean.net/extension.js


    # EXT: appindicator-support
    # BUG: synergy not handled
    # gui::AddShellExtensionsById 615



    # gnos-wallpaper
    net::CloneGitlabRepo gnos/gnos-wallpaper /opt
    ln -s /opt/gnos-wallpaper/wallpaper /usr/local/bin/
    sys::Chk
    ln -s /opt/gnos-wallpaper/wallpaper-selector /usr/local/bin/
    sys::Chk


    # EXT: quick-toggler
    # https://github.com/Shihira/gnome-extension-quicktoggler/
    gui::AddShellExtensionsById 1077

    # PATCH panel position
    sys::SedInline 's/(addToStatusArea\([^,]+,[^,]+)\)/\1, 3)/' \
        /usr/share/gnome-shell/extensions/quicktoggler@shihira.github.com/extension.js

    sys::Write <<'EOF' --append "$POSTINST_USER_SESSION_SCRIPT"
gsettings set org.gnome.shell.extensions.quicktoggler detection-interval 30000
gsettings set org.gnome.shell.extensions.quicktoggler entries-file '.config/quicktoggler.json'
gsettings set org.gnome.shell.extensions.quicktoggler notification-cond "['proc','ext','state']"
gsettings set org.gnome.shell.extensions.quicktoggler menu-shortcut "['<Super>m']"
EOF

    sys::Write <<'EOF' --append $HOME/.config/quicktoggler.json 1000:1000
{
    "DOC": "https://github.com/Shihira/gnome-extension-quicktoggler/",


    "entries": [

        {
            "title": "Gui",
            "type": "submenu",
            "entries": [
                {
                    "title": "caffeine",
                    "type": "gsettings_int",
                    "path": "org.gnome.desktop.session idle-delay",
                    "value": "4294967295"
                },
                {
                    "title": "light theme",
                    "type": "gsettings_string",
                    "path": "org.gnome.desktop.interface gtk-theme",
                    "value": "Gnome-OSC"
                },
                {
                    "title": "mouse focus",
                    "type": "gsettings_string",
                    "path": "org.gnome.desktop.wm.preferences focus-mode",
                    "value": "mouse"
                },
                {
                  "title": "night light",
                  "type": "gsettings_bool",
                  "path": "org.gnome.settings-daemon.plugins.color night-light-enabled"
                },
                {
                  "title": "notifications",
                  "type": "gsettings_bool",
                  "path": "org.gnome.desktop.notifications show-banners"
                },
                {
                  "title": "privacy",
                  "type": "toggler",
                  "command_on": "bash -c \"gsettings set org.gnome.shell.extensions.datetime-format statusbar-format \\\" \\\" ; gsettings set org.gnome.desktop.notifications show-banners false ; gsettings set org.gnome.desktop.background show-desktop-icons false\"",
                  "command_off": "bash -c \"gsettings set org.gnome.shell.extensions.datetime-format statusbar-format \\\"%a %-d %H:%M\\\" ; gsettings set org.gnome.desktop.notifications show-banners true ; gsettings set org.gnome.desktop.background show-desktop-icons true\"",
                  "detector": "gsettings get org.gnome.shell.extensions.datetime-format statusbar-format | grep -q % || echo ON"
                },
                {
                  "title": "restart",
                  "type": "launcher",
                  "command": "grestart"
                }
            ]
        },

        {
            "title": "Net",
            "type": "submenu",
            "entries": [
            ]
        },

        {
            "title": "Sys",
            "type": "submenu",
            "entries": [
                {
                  "title": "updates",
                  "type": "toggler",
                  "command_on":  "pkexec bash -c \"sed -Ei 's#^(APT::Periodic::Update-Package-Lists \\\")0#\\11#' /etc/apt/apt.conf.d/10periodic\"",
                  "command_off": "pkexec bash -c \"sed -Ei 's#^(APT::Periodic::Update-Package-Lists \\\")1#\\10#' /etc/apt/apt.conf.d/10periodic\"",
                  "detector": "grep '^APT::Periodic::Update-Package-Lists \"1' /etc/apt/apt.conf.d/10periodic"
                }
            ]
        },

        {
            "title": "Virt",
            "type": "submenu",
            "entries": [
            ]
        },

        {
          "title": "Wall",
          "type": "submenu",
          "entries": [
            {
              "title": "default",
              "type": "launcher",
              "command": "bash -c \"gsettings reset org.gnome.desktop.background picture-uri ; gsettings reset org.gnome.desktop.background picture-options ; gsettings reset org.gnome.desktop.background primary-color\""
            },
            {
              "title": "pick art",
              "type": "launcher",
              "command": "wallpaper-selector -p 4 -r museum+ArtPorn -f '[^0-9a-z\\\\[]+1[4-7][0-9][0-9][^0-9a-z\\\\]]'"
            },
            {
              "title": "pick nature",
              "type": "launcher",
              "command": "wallpaper-selector -p 2"
            },
            {
              "title": "pick sundry",
              "type": "launcher",
              "command": "wallpaper-selector -p 2 -r wallpaper"
            },
            {
              "title": "random art",
              "type": "launcher",
              "command": "wallpaper -z -r r/museum+ArtPorn -f '[^0-9a-z\\\\[]+1[4-7][0-9][0-9][^0-9a-z\\\\]]'"
            },
            {
              "title": "random nature",
              "type": "launcher",
              "command": "wallpaper -z"
            },
            {
              "title": "random sundry",
              "type": "launcher",
              "command": "wallpaper -z -r r/wallpaper"
            }
          ]
        },

        {
            "type": "separator"
        },

        {
            "title": "Edit",
            "type": "launcher",
            "command": "e $HOME/.config/quicktoggler.json"
        }

    ],


    "deftype": {

        "ssh": {
            "base": "launcher",
            "vars": ["args"],
            "command": "konsole -e ssh ${args}"
        },
        "dconf_bool": {
            "base": "toggler",
            "vars": ["path"],
            "command_on": "dconf write ${path} true",
            "command_off": "dconf write ${path} false",
            "detector": "dconf read ${path} | grep true"
        },
        "gsettings_bool": {
            "base": "toggler",
            "vars": [ "path" ],
            "command_on":  "gsettings set ${path} true",
            "command_off": "gsettings set ${path} false",
            "detector": "gsettings get ${path} | grep true"
        },
        "gsettings_int": {
            "base": "toggler",
            "vars": [ "path", "value" ],
            "command_on":  "gsettings set ${path} ${value}",
            "command_off": "gsettings reset ${path}",
            "detector": "gsettings get ${path} | awk -v p=${value} '$0==p'"
        },
        "gsettings_string": {
            "base": "toggler",
            "vars": [ "path", "value" ],
            "command_on":  "gsettings set ${path} \"${value}\"",
            "command_off": "gsettings reset ${path}",
            "detector": "gsettings get ${path} | awk -v p=\"${value}\" 'substr($0,2,length($0)-2)==p'"
        },
        "gnome_shell_extension": {
          "base": "toggler",
          "vars": [
            "name"
          ],
          "command_on": "gnome-shell-extension-tool -e \"${name}\"",
          "command_off": "gnome-shell-extension-tool -d \"${name}\"",
          "detector": "gsettings get org.gnome.shell enabled-extensions | awk -F \"'\" -v e=\"${name}\" '{for(i=1;i<=NF;i++) if ($i ~ e){print $i}}'"
        },
        "systemd_mask": {
          "base": "toggler",
          "vars": [
            "unit",
            "user",
            "pre_start",
            "pre_stop",
            "post_start",
            "post_stop"
          ],
          "command_on":  "env ${pre_start} ; p=pkexec; s=systemctl; [[ -n \"${user}\" ]] && { p= ; s=\"systemctl --user\" ; } ; $p bash -c 'for i in '\"${unit}\"'                         ; do '\"$s\"' unmask $i ; '\"$s\"' start $i ; done' ; env ${post_start}",
          "command_off": "env ${pre_stop}  ; p=pkexec; s=systemctl; [[ -n \"${user}\" ]] && { p= ; s=\"systemctl --user\" ; } ; $p bash -c 'for i in $( tac -s\" \" <<<\"'\"${unit}\"'\" ) ; do '\"$s\"' stop   $i ; '\"$s\"' mask  $i ; done' ; env ${post_stop}",
          "detector": "s=systemctl ; [[ -n \"${user}\" ]] && s=\"systemctl --user\" ; $s status ${unit} | grep '^ *Active: activ'"
        }
    }

 }
EOF
        # OLD
        # "systemd_mask": {
        #     "base": "toggler",
        #     "vars": ["unit"],
        #     "command_on": "pkexec  bash -c 'for i in '\"${unit}\"'                         ; do systemctl unmask $i ; systemctl start $i ; done'",
        #     "command_off": "pkexec bash -c 'for i in $( tac -s\" \" <<<\"'\"${unit}\"'\" ) ; do systemctl stop   $i ; systemctl mask  $i ; done'",
        #     "detector": "systemctl status ${unit} | grep '^ *Active: activ'"
        # }


    # Hotcorners switch
    if [[ -d /usr/share/gnome-shell/extensions/customcorner@eccheng.gitlab.com ]]; then
        gui::AddExtensionSwitch hotcorners "customcorner@eccheng.gitlab.com" 0
    fi

    # Privacy switch
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        gui::AddGsettingsBoolSwitch "mouse raise" \
            "org.gnome.desktop.wm.preferences raise-on-click" \
            0
    else
        # DEV: BIONIC needs raise-on-click + auto-raise
        gui::AddSwitch "mouse raise" \
            'gsettings get org.gnome.desktop.wm.preferences raise-on-click | grep true' \
            'bash -c \"gsettings set org.gnome.desktop.wm.preferences raise-on-click true  ; gsettings set org.gnome.desktop.wm.preferences auto-raise true\"' \
            'bash -c \"gsettings set org.gnome.desktop.wm.preferences raise-on-click false ; gsettings set org.gnome.desktop.wm.preferences auto-raise false\"' \
            0
    fi

    # avahi
       [[ -e /lib/systemd/system/avahi-daemon.service ]] \
    && gui::AddSystemdSwitch "avahi" "avahi-daemon.socket avahi-daemon.service" 1

    # bluetooth
       [[ -e /lib/systemd/system/bluetooth.service ]] \
    && gui::AddSystemdSwitch "blue" bluetooth 1

    # nfs
       [[ -e /etc/systemd/system/nfs-kernel-server.service ]] \
    &&  gui::AddSystemdSwitch "nfs" "rpcbind.socket rpcbind.service nfs-kernel-server.service nfs-server.service nfs-config.service proc-fs-nfsd.mount" 1

    # samba
       [[ -e /etc/systemd/system/smbd.service ]] \
    && gui::AddSystemdSwitch "smb" "nmbd.service smbd.service samba-ad-dc.service" 1

    # ssh
       [[ -e /etc/systemd/system/sshd.service ]] \
    && gui::AddSystemdSwitch "ssh" ssh 1

    # softether vpnclient
       [[ -e /lib/systemd/system/vpnclient.service ]] \
    && gui::AddSystemdSwitch "vpnclient" "vpnclient.service" 1

    # softether vpnserver
       [[ -e /lib/systemd/system/vpnserver.service ]] \
    && gui::AddSystemdSwitch "vpnserver" "vpnserver.service" 1



    # apt-daily
    gui::AddSystemdSwitch "apt-daily" "apt-daily.timer apt-daily-upgrade.timer apt-daily.service apt-daily-upgrade.service" 2

    # cups
    gui::AddSystemdSwitch "cups" "cups.socket cups.service" 2

    # sanoid
       [[ -e /lib/systemd/system/sanoid.service ]] \
    && gui::AddSystemdSwitch "sanoid" "sanoid.service sanoid.timer" 2

    # snappy
       [[ -e /etc/systemd/system/snapd.service ]] \
    && gui::AddSystemdSwitch "snapd" "snapd.socket snapd.service" 2
    # snapd.refresh.timer

    # osquery
       [[ -e /usr/lib/systemd/system/osqueryd.service ]] \
    && gui::AddSystemdSwitch "osquery" "osqueryd.service" 2


    ########
    # MISC #
    ########


    # EXT: Emoji Selector
    gui::AddShellExtensionsById 1162
    sys::Write <<EOF --append "$POSTINST_USER_SESSION_SCRIPT" # POSTINST_USER_START_SCRIPT
gsettings set org.gnome.shell.extensions.emoji-selector always-show         false
gsettings set org.gnome.shell.extensions.emoji-selector use-keybinding      true
gsettings set org.gnome.shell.extensions.emoji-selector emoji-keybinding    "['<Super>j']"
EOF
    # WORKAROUND https://github.com/maoschanz/emoji-selector-for-gnome/issues/75
    for i in \
        emoji-body-symbolic.svg \
        emoji-people-symbolic.svg \
        emoji-nature-symbolic.svg \
        emoji-food-symbolic.svg \
        emoji-travel-symbolic.svg \
        emoji-activities-symbolic.svg \
        emoji-objects-symbolic.svg \
        emoji-symbols-symbolic.svg \
        emoji-flags-symbolic.svg ;
    do
        net::Download \
            https://raw.githubusercontent.com/GNOME/adwaita-icon-theme/master/Adwaita/scalable/categories/$i \
            /usr/share/icons/Adwaita/scalable/categories/$i
    done


    # EXT: Refresh Wifi Connections
    gui::AddShellExtensionsById 905


    glib-compile-schemas /usr/share/glib-2.0/schemas/


    # EXT: Argos
    gui::AddShellExtensionsById --nodefault 1176
#     sys::Write <<'EOF' $HOME/.config/argos/.sample.sh 1000:1000
# #!/usr/bin/env bash
# URL="github.com/p-e-w/argos"
# DIR=$(dirname "$0")

# echo "Sample|iconName=help-faq-symbolic"
# echo "---"
# echo "$URL | iconName=help-faq-symbolic href='https://$URL'"
# echo "$DIR | iconName=folder-symbolic href='file://$DIR'"
# EOF


    # UNUSED EXT GPaste
#     apt::AddPackages gpaste gnome-shell-extensions-gpaste
#     cat <<'EOF' >/usr/share/glib-2.0/schemas/$PRODUCT_NAME-gpaste.gschema.override
# [org.gnome.GPaste]
# primary-to-history=true
# synchronize-clipboards=true
# track-changes=true
# track-extension-state=true
# EOF


}



InstallBrowserHelper ()
{
    # gnos-browser-factory
    net::CloneGitlabRepo gnos/gnos-browser-factory /opt
    ln -s /opt/gnos-browser-factory/gnos-browser-factory /usr/local/bin/
    sys::Chk

    # gnos-browser-selector
    net::CloneGitlabRepo gnos/gnos-browser-selector /opt
    ln -s /opt/gnos-browser-selector/browser /usr/local/bin/
    sys::Chk

    pushd /usr/local/bin/
    ln -s browser browse
    sys::Chk
    popd

    # DEPS
    apt::AddPackages crudini

    # CONFIG
    sys::Touch "$HOME/.config/browser/config.csv"


    # Register as default browser

    ## alternatives
    for alt in x-www-browser gnome-www-browser ; do
        update-alternatives --install /usr/bin/$alt $alt /usr/local/bin/browser 250
        sys::Chk
        update-alternatives --set $alt /usr/local/bin/browser
        sys::Chk
    done

    ## ENV: $BROWSER
        local bashrc=$HOME/.bashrc
    [[ -d "$HOME/.bashrc.d" ]] && bashrc=$HOME/.bashrc.d/env.browser
        sys::Write --append <<'EOF' "$bashrc" 1000:1000 700
export BROWSER="/usr/local/bin/browser"
EOF

    ## XDG: default-web-browser
    sys::Write <<EOF /usr/local/share/applications/browser.desktop
[Desktop Entry]
Type=Application
Terminal=false
Name=Select browser
Exec=/usr/local/bin/browser %U
Icon=browser
NoDisplay=true
EOF
    sudo --set-home -u \#1000 \
        DE=gnome3 xdg-settings set default-web-browser "browser.desktop"

    # XDG: scheme handler
    sudo --set-home -u \#1000 \
        xdg-mime default "browser.desktop" x-scheme-handler/http
    sudo --set-home -u \#1000 \
        xdg-mime default "browser.desktop" x-scheme-handler/https
    sudo --set-home -u \#1000 \
        xdg-mime default "browser.desktop" x-scheme-handler/about
    sudo --set-home -u \#1000 \
        xdg-mime default "browser.desktop" x-scheme-handler/unknown
    sudo --set-home -u \#1000 \
        xdg-mime default "browser.desktop" x-scheme-handler/mailto


    ## KDE: BrowserApplication
    sed -i -E \
        's/\[General]/[General]\nBrowserApplication[$e]=!browser/' \
        $HOME/.kde/share/config/kdeglobals


    # Cliboard
    sys::Write <<EOF $HOME/.config/browser/copyurl.desktop
[Desktop Entry]
Name=Clipboard
Exec=bash $HOME/.config/browser/copy.sh %U
Terminal=false
Type=Application
Icon=gtk-copy
EOF
    sys::Write <<'EOF' $HOME/.config/browser/copy.sh
#!/bin/bash
echo -n "$*" | xsel -ib
notify-send -i browser -u low "Copied to clipboard" "$*"
EOF
}


InstallGnomeHelpers ()
{
    cli::Sugar

    # YAD
    apt::AddPpaPackages webupd8team/y-ppa-manager yad
    gui::HideApps yad-icon-browser

    local script_grun="/usr/local/bin/grun"
    local script_gkill="/usr/local/bin/gkill"
    local script_grestart="/usr/local/bin/grestart"

    gui::AddKeybinding grestart "<Primary><Super>r" grestart


    # GS run as
    sys::Write <<'EOF' "$script_grun" 0:0 755
#!/bin/bash
# DESC Run command as Gnome Shell user
# ARGS [ -i ] [ -u USER | -a ] COMMAND [ARG...]

# ARGS
Usage () { echo >&2 "USAGE: $(basename "$BASH_SOURCE") [ -i ] [ -u USER | -a ] COMMAND [ARG...]" ; exit 1; }
while getopts aiu: opt "$@" &>/dev/null ; do
    case "$opt" in
        u)     [[ $( id -u )  != "0"  ]] \
            && [[ $( id -nu ) != "$2" ]] \
            && { echo "ERROR: Not allowed" ; exit 1; }
            activeUser="$OPTARG";;
        a)     [[ $( id -u )  != "0"  ]] \
            && { echo "ERROR: Not allowed" ; exit 1; }
            mode="$opt";;
        i)  interactive="1";;
        [?])Usage;;
    esac
done
shift $((OPTIND-1))
[[ $# -lt 1 ]] && Usage

# INIT
if [[ "$mode" == "a" ]] ; then
    pids=$( pgrep --full gnome-session-binary )
else
    if [[ -n "$activeUser" ]] ; then
           id -u "$activeUser" &>/dev/null \
        || { echo "ERROR: Invalid user $activeUser" ; exit 1; }
    elif [[ $( id -u )  == "0" ]] ; then
        uid=${PKEXEC_UID:-$SUDO_UID}
        [[ -n "$uid" ]]        && activeUser="$( getent passwd $uid | cut -f 1 -d ":" )"
        [[ -z "$activeUser" ]] && activeUser=$( who | awk -v tty=$( fgconsole ) '$2=="tty"tty{print $1}' )
        [[ -z "$activeUser" ]] && { echo "ERROR: Failed to identify Gnome Shell session" ; exit 1; }
    else
        activeUser=$( id -nu )
    fi
    pids=$( pgrep --full --uid $activeUser gnome-session-binary )
fi
[[ -z "$pids" ]] && { echo "ERROR: Failed to identify target Gnome Shell session" ; exit 1; }

# MAIN
for pid in $pids ; do

    user=$( ps --no-headers --format user -p $pid )

    [[ "$mode" == "a" ]] && [[ "$user" == gdm ]] && continue

    (
        source <( xargs -0 bash -c 'printf "export %q\n" "$@"' -- \
                    </proc/$pid/environ
                )

        echo "INFO: Running $1 as $user"

        if [[ $( id -u ) == "0" ]] ; then
            if [[ -n "$interactive" ]] ; then
                sudo -u "$user" --preserve-env "$@"
            else
                sudo -u "$user" --preserve-env --background\
                    nohup "$@" \
                    >/dev/null 2>/dev/null </dev/null &
            fi
        else
            if [[ -n "$interactive" ]] ; then
                "$@"
            else
                nohup "$@" \
                    >/dev/null 2>/dev/null </dev/null &
            fi
        fi
    )

done
EOF



    # GS kill
    sys::Write <<'EOF' "$script_gkill" 0:0 755
#!/bin/bash
# DESC Restart user's Gnome Shell instance and killing applications
# ARGS [ -u USER | -a ]

# ARGS
args="$@"
Usage () { echo >&2 "USAGE: $(basename "$BASH_SOURCE") [ -u USER | -a ] COMMAND [ARG...]" ; exit 1; }
while getopts aiu: opt "$@" &>/dev/null ; do
    case "$opt" in
        u)     [[ $( id -u )  != "0"  ]] \
            && [[ $( id -nu ) != "$2" ]] \
            && { echo "ERROR: Not allowed" ; exit 1; }
            activeUser="$OPTARG";;
        a)     [[ $( id -u )  != "0"  ]] \
            && { echo "ERROR: Not allowed" ; exit 1; }
            mode="$opt";;
        [?])Usage;;
    esac
done
shift $((OPTIND-1))

# INIT
if [[ "$mode" == "a" ]] ; then
    pids=$( pgrep --full gnome-shell )
else
    if [[ -n "$activeUser" ]] ; then
           id -u "$activeUser" &>/dev/null \
        || { echo "ERROR: Invalid user $activeUser" ; exit 1; }
    elif [[ $( id -u )  == "0" ]] ; then
        activeUser=$( who | awk -v tty=$( fgconsole ) '$2=="tty"tty{print $1}' )
        [[ -z "$activeUser" ]] && { echo "ERROR: Failed to identify Gnome Shell session" ; exit 1; }
    else
        activeUser=$( id -nu )
    fi
    pids=$( pgrep --full --uid $activeUser gnome-shell )
fi
[[ -z "$pids" ]] && { echo "ERROR: Failed to identify target Gnome Shell session" ; exit 1; }

# MAIN
pidList=$( tr ' ' ',' <<<$pids )
users=$( ps --no-headers -o user -p $pidList \
       | sort -u
       )

kill -9 $pids
EOF
    sys::Write --append <<EOF "$script_gkill"
"$script_grun" \$args gnome-shell
EOF



    # GS restart
    sys::Write <<'EOF' "$script_grestart" 0:0 755
#!/bin/bash
# DESC Restart user's Gnome Shell instance without killing applications
# ARGS [ -u USER | -a ]

# ARGS
Usage () { echo >&2 "USAGE: $(basename "$BASH_SOURCE") [ -u USER | -a ]" ; exit 1; }
args="$@"
while getopts au: opt "$@" &>/dev/null ; do [[ "$opt" == "?" ]] && Usage; done
shift $((OPTIND-1))
[[ $# -ne 0 ]] && Usage

# MAIN
EOF
    sys::Write --append <<EOF "$script_grestart"
"$script_grun" \$args \\
    dbus-send \\
        --type=method_call \\
        --print-reply \\
        --dest=org.gnome.Shell \\
        /org/gnome/Shell \\
        org.gnome.Shell.Eval \\
        string:'global.reexec_self()'
EOF


    # GS speak EN
    local script_gspeak="/usr/local/bin/gspeak"
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then

# UNAVAILABLE
#         apt::AddPackages festival festlex-poslex festlex-cmu festvox-us2 mbrola-us2
#         sys::Write <<'EOF' "$script_gspeak" 0:0 755
# #!/bin/bash
# # DESC Text-to-speech
# # ARGS [ TEXT ]
# # DESC If no args read from stdin

# if [[ $# -gt 0 ]]; then
#         festival --batch '(voice_us2_mbrola)' '(tts_file "/dev/fd/0" nil)' <<<"$@"
# else
#     while IFS= read -r str || [[ -n "$str" ]]; do
#         festival --batch '(voice_us2_mbrola)' '(tts_file "/dev/fd/0" nil)' <<<"$str"
#     done
# fi
# EOF

        apt::AddPackages espeak mbrola mbrola-us2
        sys::Write <<'EOF' "$script_gspeak" 0:0 755
#!/bin/bash
# DESC Text-to-speech
# ARGS [ TEXT ]
# DESC If no args read from stdin

if [[ $# -gt 0 ]]; then
        espeak --stdin -v mb/mb-us2 <<<"$@"
else
    while IFS= read -r str || [[ -n "$str" ]]; do
        espeak --stdin -v mb/mb-us2 <<<"$str"
    done
fi
EOF

    else
        apt::AddPackages festival festlex-poslex festlex-cmu festvox-us-slt-hts
        sys::Write <<'EOF' "$script_gspeak" 0:0 755
#!/bin/bash
# DESC Text-to-speech
# ARGS [ TEXT ]
# DESC If no args read from stdin

if [[ $# -gt 0 ]]; then
        festival --batch '(voice_cmu_us_slt_arctic_hts)' '(tts_file "/dev/fd/0" nil)' <<<"$@"
else
    while IFS= read -r str || [[ -n "$str" ]]; do
        festival --batch '(voice_cmu_us_slt_arctic_hts)' '(tts_file "/dev/fd/0" nil)' <<<"$str"
    done
fi
EOF
    fi

    # GS speak FR
    local script_gparle="/usr/local/bin/gparle"
    if [[ "$KEYBOARD_LAYOUT"  == "fr" ]] ; then
        if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
            :
            # UNAVAILABLE
        else
            apt::AddPackages espeak-ng mbrola mbrola-fr1
            sys::Write <<'EOF' "$script_gparle" 0:0 755
#!/bin/bash
# DESC Text-to-speech
# ARGS [ TEXT ]
# DESC If no args read from stdin

if [[ $# -gt 0 ]]; then
        espeak-ng --stdin -v mb/mb-fr1 -s 140 <<<"$@"
else
    while IFS= read -r str || [[ -n "$str" ]]; do
        espeak-ng --stdin -v mb/mb-fr1 -s 140 <<<"$str"
    done
fi
EOF
        fi
    fi
}



InstallGnomeFixes ()
{

    gui::AddFavoriteApp

    apt::AddPackages wmctrl xdotool

    # FIX udiskctl raw PAGER
    local bashrc=$HOME/.bashrc
    [[ -d "$HOME/.bashrc.d" ]] && bashrc=$HOME/.bashrc.d/55_aliases
    sys::Write --append <<'EOF' "$bashrc" 1000:1000 700
alias udisksctl='PAGER="less -R" udisksctl'
EOF



    # polkit

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then

        # polkit power.backlight-helper
        sys::Write --append <<EOF /etc/polkit-1/localauthority/50-local.d/org.gnome.settings-daemon.plugins.power.pkla
[org.gnome.settings-daemon.plugins.power.backlight-helper]
Identity=unix-group:users
Action=org.gnome.settings-daemon.plugins.power.backlight-helper
ResultAny=yes
EOF

        # polkit login1
        for i in \
            org.freedesktop.login1.attach-device \
            org.freedesktop.login1.flush-devices \
            org.freedesktop.login1.power-off \
            org.freedesktop.login1.reboot \
            org.freedesktop.login1.suspend \
            org.freedesktop.login1.hibernate \
        ; do
            sys::Write --append <<EOF /etc/polkit-1/localauthority/50-local.d/org.freedesktop.login1.pkla
[$i]
Identity=unix-group:users
Action=$i
ResultAny=yes

EOF
        done

        # polkit udisks2
        for i in \
            org.freedesktop.udisks2.filesystem-mount \
            org.freedesktop.udisks2.filesystem-mount-system \
            org.freedesktop.udisks2.filesystem-mount-other-seat \
            org.freedesktop.udisks2.encrypted-unlock \
            org.freedesktop.udisks2.encrypted-unlock-system \
            org.freedesktop.udisks2.encrypted-unlock-other-seat \
            org.freedesktop.udisks2.eject-media \
            org.freedesktop.udisks2.eject-media-system \
            org.freedesktop.udisks2.eject-media-other-seat \
        ; do
            sys::Write --append <<EOF /etc/polkit-1/localauthority/50-local.d/org.freedesktop.udisks2.pkla
[$i]
Identity=unix-group:users
Action=$i
ResultAny=yes

EOF
        done

        # polkit color-manager
        sys::Write <<'EOF' /etc/polkit-1/localauthority/50-local.d/org.freedesktop.color-manager.pkla
[org.freedesktop.color-manager]
Identity=unix-group:users
Action=org.freedesktop.color-manager.*
ResultAny=yes
EOF

        # polkit apt
        sys::Write <<'EOF' /etc/polkit-1/localauthority/50-local.d/org.debian.apt.update-cache.pkla
[org.debian.apt.update-cache]
Identity=unix-group:users
Action=org.debian.apt.update-cache
ResultAny=yes
EOF


        # polkit gnome-control-center
        for i in \
            org.gnome.controlcenter.datetime \
            org.gnome.controlcenter.user-accounts \
            org.opensuse.cupspkhelper.mechanism \
        ; do
            sys::Write --append <<EOF /etc/polkit-1/localauthority/50-local.d/$i.pkla
[$i]
Identity=unix-group:users
Action=$i.*
ResultAny=yes

EOF
        done


    else # bionic



        # TODO bionic polkit power.backlight-helper
        sys::Write <<'EOF' /etc/polkit-1/localauthority.d/02-allow-backlight-helper.conf
polkit.addRule(function(action, subject) {
   if ( (   action.id == "org.gnome.settings-daemon.plugins.power.backlight-helper" ) &&
        subject.isInGroup("users") ) {
      return polkit.Result.YES;
   }
});
EOF

        # TODO bionic polkit login1
        sys::Write <<'EOF' /etc/polkit-1/localauthority.d/02-allow-login1.conf
polkit.addRule(function(action, subject) {
   if ( (   action.id == "org.freedesktop.login1.attach-device" ||
            action.id == "org.freedesktop.login1.flush-devices" ||
            action.id == "org.freedesktop.login1.power-off"     ||
            action.id == "org.freedesktop.login1.reboot"        ||
            action.id == "org.freedesktop.login1.suspend"       ||
            action.id == "org.freedesktop.login1.hibernate"      ) &&
        subject.isInGroup("users") ) {
      return polkit.Result.YES;
   }
});
EOF
        # TODO bionic polkit udisks2
        sys::Write <<'EOF' /etc/polkit-1/localauthority.d/02-allow-udisks2.conf
polkit.addRule(function(action, subject) {
   if ( (   action.id == "org.freedesktop.udisks2.filesystem-mount"         ||
            action.id == "org.freedesktop.udisks2.filesystem-mount-system"  ||
            action.id == "org.freedesktop.udisks2.eject-media"              ||
            action.id == "org.freedesktop.udisks2.eject-media-system"       ||
            action.id == "org.freedesktop.udisks2.encrypted-unlock"         ||
            action.id == "org.freedesktop.udisks2.encrypted-unlock-system"   ) &&
        subject.isInGroup("users") ) {
      return polkit.Result.YES;
   }
});
EOF

        # polkit color-manager
        sys::Write <<'EOF' /etc/polkit-1/localauthority.d/02-allow-colord.conf
polkit.addRule(function(action, subject) {
   if ( (   action.id == "org.freedesktop.color-manager.create-device"   ||
            action.id == "org.freedesktop.color-manager.create-profile"  ||
            action.id == "org.freedesktop.color-manager.delete-device"   ||
            action.id == "org.freedesktop.color-manager.delete-profile"  ||
            action.id == "org.freedesktop.color-manager.modify-device"   ||
            action.id == "org.freedesktop.color-manager.modify-profile"   ) &&
        subject.isInGroup("users") ) {
      return polkit.Result.YES;
   }
});
EOF
        # polkit apt
        sys::Write <<'EOF' /etc/polkit-1/localauthority.d/02-allow-apt-update.conf
polkit.addRule(function(action, subject) {
   if ( ( action.id == "org.debian.apt.update-cache" ) &&
        subject.isInGroup("sudo") ) {
      return polkit.Result.YES;
   }
});
EOF
    fi



    # RELEASE-SPECIFIC
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then

        # Remove some legacy icons
        apt::RemovePackages \
            ubuntu-mono \
            humanity-icon-theme
            # breeze-icon-theme # RDEP: kde-runtime okular
            # gnome-icon-theme  # RDEP: gdebi sparkleshare
        sys::Chk

    else

        # NetworkManager: manage ethernet interfaces
        sys::Write --append <<'EOF' /etc/NetworkManager/NetworkManager.conf

[keyfile]
unmanaged-devices=*,except:type:wifi,except:type:wwan,except:type:ethernet
EOF
    fi



    # Disable at-spi2-core gnome-keyring
    # BUG: nautilus pulls libgail-3-0 > at-spi2-core after InstallGnomeFixes
    # BUG: software-center pulls gnome-keyring after InstallGnomeFixes
    # WORKAROUND: install it first to disable it
    apt::AddPackages at-spi2-core gnome-keyring

    for launcher in                                         \
        /etc/xdg/autostart/at-spi-dbus-bus.desktop          \
        /etc/xdg/autostart/gnome-keyring-gpg.desktop        \
        /etc/xdg/autostart/gnome-keyring-pkcs11.desktop     \
        /etc/xdg/autostart/gnome-keyring-secrets.desktop    \
        /etc/xdg/autostart/gnome-keyring-ssh.desktop        \
        /etc/xdg/autostart/pulseaudio-kde.desktop           ;
    do
           [[ -f "$launcher" ]] && mv $launcher{,.ORIG}
    done

    # Disable a11y, Telepathy, Keyring
    local disabledServices="
            org.a11y.atspi.Registry
            org.a11y.Bus
            org.freedesktop.Telepathy.AccountManager
            org.freedesktop.Telepathy.MissionControl5
            org.freedesktop.secrets
            org.gnome.keyring.PrivatePrompter
            org.gnome.keyring
            org.gnome.keyring.SystemPrompter
            org.gtk.vfs.AfcVolumeMonitor
            org.gtk.vfs.GoaVolumeMonitor
            org.gtk.vfs.GPhoto2VolumeMonitor
            org.gtk.vfs.MTPVolumeMonitor
            org.gnome.evolution.dataserver.Calendar7
            org.gnome.evolution.dataserver.Sources5
            org.gnome.evolution.dataserver.AddressBook9
            org.gnome.evolution.dataserver.UserPrompter0
            ""
            org.gnome.Shell.CalendarServer
            org.gnome.evolution.dataserver.Calendar
            org.gnome.evolution.dataserver.Sources
            org.gnome.evolution.dataserver.AddressBook
            org.gnome.evolution.dataserver.UserPrompter
            "
            # org.gtk.vfs.Metadata

    # KDE
    if dpkg -S kdelibs-bin &>/dev/null ; then
        # Disable Knotify
        disabledServices="$disabledServices
            org.kde.kded5
            org.kde.kglobalaccel
            org.kde.kiod5
            org.kde.knotify
            org.kde.kuiserver
            org.kde.kwalletd
            org.kde.kwalletd5
            "

          [[ -f "/etc/xdg/autostart/pulseaudio-kde.desktop" ]] \
       && mv /etc/xdg/autostart/pulseaudio-kde.desktop{,.ORIG}
    fi

    #
    gui::DisableDbusServices $disabledServices


    # XDG user dirs

    if [[ -n "$ZFS_DATA_DSET" ]] ; then
        for i in Desktop Documents ; do
            [[ -d "$HOME/$i" ]] && rm -d "$HOME/$i"
# BADZ
            # mkdir "/$ZFS_DATA_DSET/$USER_USERNAME/$i"
            # chown 1000:1000 "/$ZFS_DATA_DSET/$USER_USERNAME/$i"
            # ln -s "/$ZFS_DATA_DSET/$USER_USERNAME/$i" "$HOME/$i"
            mkdir "/$( basename $ZFS_DATA_DSET )/$USER_USERNAME/$i"
            chown 1000:1000 "/$( basename $ZFS_DATA_DSET )/$USER_USERNAME/$i"
            ln -s "/$( basename $ZFS_DATA_DSET )/$USER_USERNAME/$i" "$HOME/$i"

            chown --no-dereference 1000:1000 "/$HOME/$i"
        done
    fi

    mkdir $HOME/Downloads
    chown 1000:1000 $HOME/Downloads

    sys::Write --append $HOME/.config/user-dirs.dirs 1000:1000 \
        <<<'XDG_TEMPLATES_DIR="$HOME/.templates"'

    cp $HOME/.config/user-dirs.dirs /etc/skel/.config/user-dirs.dirs


    # XDG Bookmarks
    sys::Write <<EOF $HOME/.config/gtk-3.0/bookmarks 1000:1000
$( [[ -n "$ZFS_DATA_DSET" ]] && echo "file:///$( basename $ZFS_DATA_DSET ) $( basename ${ZFS_DATA_DSET^} )" )
file:/// Filesystem
EOF

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        sys::Write --append <<EOF $HOME/.config/gtk-3.0/bookmarks
file:///$HOME/Downloads Downloads
EOF
    fi

    # XDG Templates
    sys::Write $HOME/.templates/empty 1000:1000 <<<''

    mkdir -p /etc/skel/.templates
    cp $HOME/.templates/empty       /etc/skel/.templates/empty

    # /media
    mkdir -p /media/$USER_USERNAME
    chgrp $USER_USERNAME /media/$USER_USERNAME
    chmod 770 /media/$USER_USERNAME
    sys::Chk


    # XDG MIME
    mkdir -p $HOME/.local/share/applications/
    ln -s $HOME/.config/mimeapps.list $HOME/.local/share/applications/mimeapps.list
    sys::Chk
    chown -hR 1000:1000 $HOME/.local


    # GTK2 file-chooser config
    local gtk2FcSuffix=.config/gtk-2.0/gtkfilechooser.ini
    sys::Write <<'EOF' $HOME/$gtk2FcSuffix 1000:1000 750
[Filechooser Settings]
StartupMode=cwd
EOF
# LocationMode=filename-entry
# ShowHidden=true
    sys::Write     /root/$gtk2FcSuffix <$HOME/$gtk2FcSuffix
    sys::Write /etc/skel/$gtk2FcSuffix <$HOME/$gtk2FcSuffix


    # GTK3 file-chooser config
    # Populate dconf local Profile keyfile
    sys::Write <<EOF "/etc/dconf/db/local.d/file-chooser.key"
[org/gtk/settings/file-chooser]
startup-mode='cwd'
sort-directories-first=true
EOF
# location-mode='filename-entry'
# show-hidden=true
    rm -rfv /etc/dconf/db/local 2>/dev/null
    dconf update


    # CONF: Desktop icons size
    sys::Write <<'EOF' /usr/share/glib-2.0/schemas/$PRODUCT_NAME-desktop-icons.gschema.override
[org.gnome.nautilus.icon-view]
default-zoom-level='standard'
EOF

    # CONF: Power
    sys::Write <<'EOF' /usr/share/glib-2.0/schemas/$PRODUCT_NAME-power.gschema.override
[org.gnome.desktop.session]
idle-delay=600

[org.gnome.settings-daemon.plugins.power]
sleep-inactive-ac-type='nothing'
sleep-inactive-battery-type='nothing'

[org.gnome.desktop.screensaver]
lock-enabled=false
ubuntu-lock-on-suspend=false
user-switch-enabled=false

[org.gnome.desktop.lockdown]
disable-lock-screen=true
EOF
# lock-delay=300


    # Hide a11y errors
    # WARNING **: Error retrieving accessibility bus address: org.freedesktop.DBus.Error.Spawn.ChildExited: Process org.a11y.Bus exited with status 1
    sys::Write <<'EOF' /etc/X11/Xsession.d/56no-a11y 0:0 644
NO_AT_BRIDGE=1
export NO_AT_BRIDGE
EOF
#     sys::Write <<'EOF' /etc/X11/xinit/xinitrc.d/10-no-a11y.sh 0:0 755
# #!/bin/bash
# export NO_AT_BRIDGE=1
# EOF


    # FEAT: sync clipboards
    apt::AddPackages autocutsel
    sys::Write <<'EOF' /etc/X11/Xsession.d/90autocutsel 0:0 644
autocutsel -fork -selection PRIMARY
EOF

    # FEAT: plotinus
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages nilarimogard/webupd8 libplotinus
    else
        apt::AddPpaPackages --release xenial nilarimogard/webupd8 libplotinus
    fi
    echo "GTK3_MODULES=/usr/lib/x86_64-linux-gnu/libplotinus/libplotinus.so" \
        >>/etc/environment

    # Locker: slock
    apt::AddPackages suckless-tools
    gui::AddKeybinding slock '<Super>l' 'bash -c "{ sleep 1 ; xset dpms force off ; } & slock"'

    # Locker: xtrlock
    apt::AddPackages xtrlock
    gui::AddKeybinding xtrlock         '<Alt><Super>l'      'xtrlock'
    gui::AddKeybinding xtrlock-privacy '<Shift><Super>l'    'bash -c "notif=\$( gsettings get org.gnome.desktop.notifications show-banners ) ; icons=\$( gsettings get org.gnome.desktop.background show-desktop-icons ) ; [[ \"\$notif\" == \"true\" ]] && gsettings set org.gnome.desktop.notifications show-banners false ; [[ \"\$icons\" == \"true\" ]] && gsettings set org.gnome.desktop.background show-desktop-icons false ; gsettings set org.gnome.shell.extensions.dash-to-panel panel-size 0 ;                xtrlock ; gsettings set org.gnome.shell.extensions.dash-to-panel panel-size 29 ; [[ \"\$notif\" == \"true\" ]] && gsettings set org.gnome.desktop.notifications show-banners true ; [[ \"\$icons\" == \"true\" ]] && gsettings set org.gnome.desktop.background show-desktop-icons true"'
    gui::AddKeybinding xtrlock-desktop '<Primary><Super>l'  'bash -c "notif=\$( gsettings get org.gnome.desktop.notifications show-banners ) ; icons=\$( gsettings get org.gnome.desktop.background show-desktop-icons ) ; [[ \"\$notif\" == \"true\" ]] && gsettings set org.gnome.desktop.notifications show-banners false ; [[ \"\$icons\" == \"true\" ]] && gsettings set org.gnome.desktop.background show-desktop-icons false ; gsettings set org.gnome.shell.extensions.dash-to-panel panel-size 0 ; wmctrl -k on ; xtrlock ; gsettings set org.gnome.shell.extensions.dash-to-panel panel-size 29 ; [[ \"\$notif\" == \"true\" ]] && gsettings set org.gnome.desktop.notifications show-banners true ; [[ \"\$icons\" == \"true\" ]] && gsettings set org.gnome.desktop.background show-desktop-icons true"'
    # DOC xtrlock-desktop hides panel, desktop icons & notifications


    # Universal quit
    gui::AddKeybinding windowclose '<Super>q' \
        'bash -c "wmctrl -i -c \\$( printf '0x%%0.8x' \\$( xdotool getactivewindow ) )"'


    # Killing processes
    gui::AddKeybinding kill-sighup '<Super>k' \
        'bash -c "pid=\\$( xdotool getactivewindow getwindowpid ); cmd=\\$(ps -o command --no-headers --pid \\$pid ) ; [[ -n "\\$cmd" ]] && zenity --width=300 --question --text=\\"kill -SIGHUP \\$pid ?\\n\\n\\$cmd\\" && kill -SIGHUP \\$pid"'
    gui::AddKeybinding kill-sigkill '<Primary><Super>k' \
        'bash -c "pid=\\$( xdotool getactivewindow getwindowpid ); cmd=\\$(ps -o command --no-headers --pid \\$pid ) ; [[ -n "\\$cmd" ]] && zenity --width=300 --question --text=\\"kill -9 \\$pid ?\\n\\n\\$cmd\\" && kill -9 \\$pid"'
    gui::AddKeybinding kill-sighup-direct '<Alt><Super>k' \
        'bash -c "pid=\\$( xdotool getactivewindow getwindowpid ); cmd=\\$(ps -o command --no-headers --pid \\$pid ) ; [[ -n "\\$cmd" ]] && kill -SIGHUP \\$pid"'
    gui::AddKeybinding kill-sigkill-direct '<Alt><Primary><Super>k' \
        'bash -c "pid=\\$( xdotool getactivewindow getwindowpid ); cmd=\\$(ps -o command --no-headers --pid \\$pid ) ; [[ -n "\\$cmd" ]] && kill -9 \\$pid"'
    gui::AddKeybinding xkill '<Shift><Super>k' \
        'xkill'
    # gui::AddKeybinding windowclose '<Alt><Super>k' \
    #     'xdotool getactivewindow windowclose'


    # Audio volume control
    gui::AddKeybinding audio-boost '<Primary>AudioRaiseVolume' \
        'bash -c "/usr/bin/pactl set-sink-volume @DEFAULT_SINK@ +10%%"'
    gui::AddKeybinding audio-max '<Primary>AudioMute' \
        'bash -c "/usr/bin/pactl set-sink-volume @DEFAULT_SINK@ 100%%"'
    gui::AddKeybinding audio-mid '<Primary>AudioLowerVolume' \
        'bash -c "/usr/bin/pactl set-sink-volume @DEFAULT_SINK@ 50%%"'


    # Keybindings
    sys::Write <<'EOF' /usr/share/glib-2.0/schemas/$PRODUCT_NAME-gnome-keybindings.gschema.override
[org.gnome.settings-daemon.plugins.media-keys]
screenreader=''
screensaver=''
terminal=''
video-out=''

[org.gnome.shell.keybindings]
focus-active-notification=['<Super>comma']
open-application-menu=['<Super>Escape']
toggle-message-tray=['<Super>n']
toggle-overview=[]

[org.gnome.desktop.wm.keybindings]
switch-input-source=[]
switch-input-source-backward=[]
show-desktop=['<Super>d']
maximize-vertically=['<Alt><Super>Up']
activate-window-menu=['<Alt><Super>space']
switch-group=[]
switch-group-backward=[]
switch-to-workspace-down=['<Super>Page_Down']
switch-to-workspace-up=['<Super>Page_Up']
switch-to-workspace-left=[]
switch-to-workspace-right=[]
switch-to-workspace-1=['<Super>1']
switch-to-workspace-2=['<Super>2']
switch-to-workspace-3=['<Super>3']
switch-to-workspace-4=['<Super>4']
switch-panels=[]
switch-panels-backward=[]
EOF
    if str::InList APPLE $STORAGE_OPTIONS ; then
        sys::Write --append <<'EOF' /usr/share/glib-2.0/schemas/$PRODUCT_NAME-gnome-keybindings.gschema.override
cycle-group=['<Alt>Tab']
cycle-group-backward=['<Alt><Shift>Tab']
switch-applications=['<Super>Tab']
switch-applications-backward=['<Shift><Super>Tab']
EOF
    else
        sys::Write --append <<'EOF' /usr/share/glib-2.0/schemas/$PRODUCT_NAME-gnome-keybindings.gschema.override
cycle-group=['<Super>Tab']
cycle-group-backward=['<Super><Shift>Tab']
switch-applications=['<Alt>Tab']
switch-applications-backward=['<Shift><Alt>Tab']
EOF
    fi


    # CONF: Features
    sys::Write <<'EOF' /usr/share/glib-2.0/schemas/$PRODUCT_NAME-gnome-features.gschema.override
[org.gnome.desktop.wm.preferences]
action-middle-click-titlebar='toggle-maximize-vertically'
auto-raise=true
auto-raise-delay=0

[org.gnome.shell]
always-show-log-out=true

[org.gnome.shell.calendar]
show-weekdate=true

[org.gnome.shell.overrides]
attach-modal-dialogs=false

[org.gnome.desktop.sound]
event-sounds=false
allow-volume-above-100-percent=true

[org.gnome.desktop.privacy]
remember-app-usage=false

[org.gnome.desktop.media-handling]
autorun-x-content-start-app=[]
EOF


    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        :
    else
        # BIONIC specific
        sys::Write <<'EOF' /usr/share/glib-2.0/schemas/$PRODUCT_NAME-bionic.gschema.override
[org.gnome.desktop.calendar]
show-weekdate=true

[org.gnome.mutter.keybindings]
switch-monitor=['XF86Display']
EOF
    fi


    glib-compile-schemas /usr/share/glib-2.0/schemas/

}


InstallGnomeTheme ()
{

    # Xorg
    sys::Write --append <<EOF $HOME/.Xresources 1000:1000 600
*foreground: rgb:$(
    awk '{printf("%s/%s/%s", substr($1,1,2), substr($1,3,2), substr($1,5,2)) }' \
        <<<$THEME_COLOR_FOREGD_HEX )
*background: rgb:$(
    awk '{printf("%s/%s/%s", substr($1,1,2), substr($1,3,2), substr($1,5,2)) }' \
        <<<$THEME_COLOR_BACKGD_HEX )
EOF

    # xterm
    sys::Write --append <<EOF $HOME/.Xresources 1000:1000 600
xterm*foreground: rgb:$(
    awk '{printf("%s/%s/%s", substr($1,1,2), substr($1,3,2), substr($1,5,2)) }' \
        <<<$THEME_COLOR_FOREGD_HEX )
xterm*background: rgb:$(
    awk '{printf("%s/%s/%s", substr($1,1,2), substr($1,3,2), substr($1,5,2)) }' \
        <<<$THEME_COLOR_BACKGD_HEX )
xterm*faceName: $THEME_FONT_FIXED_NAME:size=$THEME_FONT_FIXED_SIZE
EOF

    # gnome-terminal hijack
    sys::Write <<'EOF' /usr/local/bin/gnome-terminal 0:0 755
#!/bin/bash
# Convert common first option from gnome-terminal to xterm usage
# TODO better, really
opt=
while true ; do
    case $1 in
        --window)               shift ;;
        --full-screen)          shift ; opt=-maximized ;;
        --working-directory)    shift ; cd "$1"; shift ;;
        -e|-x)                  shift ; break 2 ;;
        *)                      break 2 ;;
    esac
done
if [[ $# -gt 0 ]] ; then
    exec xterm $opt "$@"
else
    exec xterm $opt
fi
EOF

    # CURSOR themes
    net::DownloadGithubFiles keeferrourke/capitaine-cursors /usr/share/icons/Capitaine/ dist/cursors/


    # ICON theme: Numix-Circle
    apt::AddPpaPackages numix/ppa numix-icon-theme-circle numix-icon-theme

    # PATCH: Change defaut application icon
    sed -i -E \
        's#^(Directories=.*)#\1,scalable/mimetypes#' \
        /usr/share/icons/Numix-Circle/index.theme
    sys::Chk
    sys::Write <<'EOF' --append /usr/share/icons/Numix-Circle/index.theme

[scalable/mimetypes]
Size=16
Context=MimeTypes
MinSize=8
MaxSize=512
Type=Scalable
EOF
    mkdir -p /usr/share/icons/Numix-Circle/scalable/mimetypes
    pushd /usr/share/icons/Numix-Circle/scalable/mimetypes
    for icon in                             \
        application-executable              \
        application-x-executable            \
        binary                              \
        exec                                \
        gnome-fs-executable                 \
        gnome-mime-application-x-executable ;
    do
        ln -s ../../48/apps/glom.svg $icon.svg # DEV ALTERNATIVES: help-contents gnome-window-manager factorio
    done
    popd

    for dir in /usr/share/icons/Numix-Circle/* ; do

        local dst="$dir/mimetypes/application-executable.svg"

        [[ -f "$dst" ]] || continue

        cp "$dst" "$dst.ORIG"
        pushd "$dir/mimetypes"
        ln -sf ../apps/preferences-system-windows-actions.svg $icon.svg # DEV ALTERNATIVES: help-contents gnome-window-manager factorio
        popd

    done


    # Light GNOME THEME: Gnome-OSC
    local tpath="Gnome-OSC-HS-light-menu-- 2-themes/Gnome-OSC-HS-(not-transparent)-light-menu/"
    net::DownloadGithubFiles \
        paullinuxthemer/gnome-osc-themes \
        /usr/share/themes/ \
        "$tpath"
    mv "/usr/share/themes/$( basename "$tpath" )" /usr/share/themes/Gnome-OSC
    sys::Chk


    # CUSTOM GTK/GS theme

    # theme@github
    local themeZip=$( mktemp )
    net::DownloadGithubLatestRelease gnos-project/gnos-theme 'Gnos-theme\\.zip$' "$themeZip"
    unzip "$themeZip" -d /usr/share/themes/
    sys::Chk
    rm "$themeZip"
    
    # ALT theme@gitlab
    # net::DownloadUnzip \
    #     https://gitlab.com/gnos/gnos-theme/uploads/356fbc275e3809e60fda1cad96edc37d/Gnos-theme.zip \
    #     /usr/share/themes/

    # ALT Build
    # local tempbuild=$( mktemp -d )
    # chown -hR 1000:1000 "$tempbuild"
    # pushd "$tempbuild"
    # BuildTheme "$THEME_GS"
    # popd
    # sys::Copy "$tempbuild/$THEME_GS" /usr/share/themes/
    # rm -rf "$tempbuild"


    # PATCH: window buttons from Arc/flatabulous theme
    local wbTheme="/usr/share/themes/$THEME_GS/gnome-shell/extensions/window_buttons.theme"
    if [[ -d "$wbTheme" ]] ; then
        local extWbTheme
        for ext in \
            no-title-bar@franglais125.gmail.com \
        ; do
            # pixel-saver@deadalnix.me \
            # window_buttons@biox.github.com \
            extWbTheme=/usr/share/gnome-shell/extensions/$ext/themes
            if [[ -d "$extWbTheme" ]] ; then
                mkdir -p "$extWbTheme/$THEME_GTK"
                cp -v "$wbTheme"/* "$extWbTheme/$THEME_GTK"
                sys::Chk
                cp -vR "$extWbTheme/$THEME_GTK" "$extWbTheme/Gnome-OSC"
                sys::Chk
            fi
        done
    fi

    # PATCH: GS 3.28 Overview window-caption
    if [[ "$UBUNTU_RELEASE" == "bionic" ]] ; then
        sys::Write <<EOF --append "/usr/share/themes/$THEME_GS/gnome-shell/gnome-shell.css"
.window-caption {
  color: #FFFFFF;
  background-color: #$THEME_COLOR_SELECT_HEX;
}
EOF
    fi

    # GtkSource scheme
    sys::Copy "/usr/share/themes/$THEME_GS/gtk-source/classic-override.xml" \
        /usr/local/share/gtksourceview-3.0/styles/


    # ROOT theme support
    local themeDir="/usr/share/themes/$THEME_GS"

    ## USER GTK3 THEME
    mkdir -p            $HOME/.themes
    ln -s $themeDir     $HOME/.themes/$THEME_GTK
    chown -hR 1000:1000 $HOME/.themes

    ## SKEL GTK3 THEME
    mkdir -p            /etc/skel/.themes
    ln -s $themeDir     /etc/skel/.themes/$THEME_GTK

    ## ROOT GTK THEMES
    mkdir -p                    /root/.themes/$THEME_GTK
    cp -R $themeDir/gtk-{2,3}.0 /root/.themes/$THEME_GTK

    ## ROOT GTK3
    sys::Write <<EOF --append   /root/.themes/$THEME_GTK/gtk-3.0/gtk.css
/* headerbar */
.csd headerbar {
    background-color: #$THEME_COLOR_MANAGE_HEX;
    border-bottom: 1px solid #$THEME_COLOR_MANAGE_HEX;
    color: white; }
/* menubar */
menubar, .menubar {
    background-color: #$THEME_COLOR_MANAGE_HEX;
    border-bottom: 1px solid #$THEME_COLOR_MANAGE_HEX;
    color: white; }
menubar:backdrop, .menubar:backdrop {
    background-color: #$THEME_COLOR_WINDOW_HEX;
    border-bottom: 1px solid #$THEME_COLOR_MANAGE_HEX; }
/* fix nautilus pathbar */
headerbar .linked:not(.vertical).path-bar > button:checked:not(:backdrop) {
    border-color: rgba($THEME_COLOR_WINDOW_RGB,0.6); }
EOF

    ## ROOT GTK2
    sed -i -E \
        -e 's#^(\s*bg\[NORMAL\]\s*=\s*).*#\1"\#'"$THEME_COLOR_MANAGE_HEX"'"#' \
        -e '0,/^(\s*fg\[NORMAL\]\s*=\s*).*/s#^(\s*fg\[NORMAL\]\s*=\s*).*#\1"\#ffffff"#' \
        /root/.themes/$THEME_GTK/gtk-2.0/menubar-toolbar/menubar-toolbar-dark.rc
    # UNUSED
    # -e '0,/^(\s*bg\[NORMAL\]\s*=\s*).*/s#^(\s*bg\[NORMAL\]\s*=\s*).*#\1"\#'"$THEME_COLOR_MANAGE_HEX"'"#' \
    # -e 's#^(\s*fg\[NORMAL\]\s*=\s*).*#\1"\#ffffff'"#' \



    # GTK 3 Configuration
    sys::Write <<EOF /etc/gtk-3.0/settings.ini
[Settings]
gtk-theme-name = $THEME_GTK
gtk-fallback-icon-theme = $THEME_ICON
EOF

    rm $HOME/.config/gtk-3.0/settings.ini
    ln -s /etc/gtk-3.0/settings.ini $HOME/.config/gtk-3.0/settings.ini
    chown -hR 1000:1000 $HOME/.config/gtk-3.0/settings.ini

    sys::Write <<EOF /usr/share/glib-2.0/schemas/$PRODUCT_NAME-theming.gschema.override
[org.gnome.shell.extensions.user-theme]
name='$THEME_GS'

[org.gnome.desktop.wm.preferences]
theme='$THEME_GTK'
titlebar-font='$THEME_FONT_WINDOW_NAME $THEME_FONT_DEFAULT_SIZE'
titlebar-uses-system-font=false
button-layout=':minimize,maximize,close'
audible-bell=false
visual-bell=true

[org.gnome.desktop.screensaver]
picture-uri='file:///dev/null'
picture-options='none'
primary-color='#$THEME_COLOR_BACKGD_HEX'
secondary-color='#$THEME_COLOR_BACKGD_HEX'

[org.gnome.desktop.background]
primary-color='#$THEME_COLOR_BACKGD_HEX'
secondary-color='#$THEME_COLOR_BACKGD_HEX'
color-shading-type='solid'
draw-background=false
picture-uri='file:///usr/share/themes/$THEME_GS/branding/title.svg'
picture-options='centered'
show-desktop-icons=true

[org.gnome.desktop.interface]
gtk-theme='$THEME_GTK'
icon-theme='$THEME_ICON'
cursor-theme='$THEME_CURSOR'
cursor-size=30
font-name='$THEME_FONT_SHORT_NAME $THEME_FONT_DEFAULT_SIZE'
document-font-name='$THEME_FONT_DOCUMENT_NAME $THEME_FONT_DEFAULT_SIZE'
monospace-font-name='$THEME_FONT_FIXED_NAME $THEME_FONT_FIXED_SIZE'
menus-have-icons=true
buttons-have-icons=true
enable-animations=false

[org.gnome.settings-daemon.plugins.xsettings]
overrides={'Gtk/MenuImages': <1>, 'Gtk/ShellShowsAppMenu': <1>}
antialiasing='grayscale'
hinting='slight'

EOF

    glib-compile-schemas /usr/share/glib-2.0/schemas/

    # WORKAROUND: cannot set gnome-shell theme at install time (without dbus ?)
    sys::Write <<EOF --append "$POSTINST_USER_SESSION_SCRIPT"
gsettings set org.gnome.shell.extensions.user-theme name '$THEME_GS'
EOF


    # QT5
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then

        apt::AddPackages libqt5libqgtk2

        sys::Write <<'EOF' /etc/X11/Xsession.d/90qt-gtk 0:0 644
QT_STYLE_OVERRIDE=GTK+
export QT_STYLE_OVERRIDE
EOF

#         sys::Write <<'EOF' /etc/X11/xinit/xinitrc.d/99-qt-gtk.sh 0:0 755
# #!/bin/bash
# export QT_STYLE_OVERRIDE=GTK+
# EOF

    else

        apt::AddPackages qt5-style-plugins

        sys::Write <<'EOF' /etc/X11/Xsession.d/90qt-gtk 0:0 644
QT_QPA_PLATFORMTHEME=gtk2
export QT_QPA_PLATFORMTHEME
EOF
# NEXT: QT integration https://askubuntu.com/a/952571
# qt5ct FROM ppa:mati75/qt5ct
# qt5-style-plugins
# qt5-gtk-platformtheme
    fi


    # QT4
    apt::AddPackages libqtcore4  # qt4-qtconfig
    sys::Write <<EOF /etc/xdg/Trolltech.conf # ORIG $HOME/.config/Trolltech.conf
[Qt]
style=GTK+
font="$THEME_FONT_DEFAULT_NAME,$THEME_FONT_DEFAULT_SIZE,-1,5,50,0,0,0,0,0"
EOF


    # KDE globals
    sys::Write <<EOF --append $HOME/.kde/share/config/kdeglobals
fixed=$THEME_FONT_FIXED_NAME,$THEME_FONT_FIXED_SIZE,-1,5,50,0,0,0,0,0
font=$THEME_FONT_DEFAULT_NAME,$THEME_FONT_DEFAULT_SIZE,-1,5,50,0,0,0,0,0
menuFont=$THEME_FONT_DEFAULT_NAME,$THEME_FONT_DEFAULT_SIZE,-1,5,50,0,0,0,0,0
smallestReadableFont=$THEME_FONT_DEFAULT_NAME,$THEME_FONT_DEFAULT_SIZE,-1,5,50,0,0,0,0,0
taskbarFont=$THEME_FONT_DEFAULT_NAME,$THEME_FONT_DEFAULT_SIZE,-1,5,50,0,0,0,0,0
toolBarFont=$THEME_FONT_DEFAULT_NAME,$THEME_FONT_DEFAULT_SIZE,-1,5,50,0,0,0,0,0
desktopFont=$THEME_FONT_DEFAULT_NAME,$THEME_FONT_DEFAULT_SIZE,-1,5,50,0,0,0,0,0

[Icons]
Theme=$THEME_ICON

EOF

    sys::Write <<EOF --append $HOME/.kde/share/config/kdeglobals

[Colors:Button]
BackgroundNormal=$THEME_COLOR_OBJECT_RGB
BackgroundAlternate=$THEME_COLOR_OBJECT_RGB
DecorationHover=$THEME_COLOR_SELECT_RGB
DecorationFocus=$THEME_COLOR_SELECT_RGB
ForegroundNormal=$THEME_COLOR_FOREGD_RGB

[Colors:Selection]
BackgroundNormal=$THEME_COLOR_SELECT_RGB
BackgroundAlternate=$THEME_COLOR_SELECT_RGB
DecorationHover=$THEME_COLOR_SELECT_RGB
DecorationFocus=$THEME_COLOR_SELECT_RGB
ForegroundNormal=255,255,255
ForegroundActive=$THEME_COLOR_SELECT_RGB


[Colors:View]
BackgroundAlternate=$THEME_COLOR_BACKGD_RGB
BackgroundNormal=$THEME_COLOR_BACKGD_RGB
DecorationHover=$THEME_COLOR_SELECT_RGB
DecorationFocus=$THEME_COLOR_SELECT_RGB
ForegroundNormal=$THEME_COLOR_FOREGD_RGB

[Colors:Window]
BackgroundNormal=$THEME_COLOR_WINDOW_RGB
BackgroundAlternate=$THEME_COLOR_WINDOW_RGB
DecorationHover=$THEME_COLOR_SELECT_RGB
DecorationFocus=$THEME_COLOR_SELECT_RGB
ForegroundNormal=$THEME_COLOR_FOREGD_RGB
ForegroundActive=$THEME_COLOR_SELECT_RGB
EOF

    # ROOT + SKEL
    mkdir -p /root/.kde/share/config /etc/skel/.kde/share/config
    cp $HOME/.kde/share/config/kdeglobals     /root/.kde/share/config/kdeglobals
    cp $HOME/.kde/share/config/kdeglobals /etc/skel/.kde/share/config/kdeglobals


    # KDE4 default icon theme
    if [[ -L /usr/share/icons/default.kde4 ]]; then
        rm /usr/share/icons/default.kde4
        pushd /usr/share/icons
        ln -s $THEME_ICON default.kde4
        popd
    fi

    # wallpaper
    sys::Write <<EOF /usr/local/share/gnome-background-properties/$PRODUCT_NAME-backgrounds.xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">
<wallpapers>
    <wallpaper deleted="false">
        <name>$THEME_GS</name>
        <filename>/usr/share/themes/$THEME_GS/branding/title.svg</filename>
        <options>centered</options>
    <pcolor>#$THEME_COLOR_BACKGD_HEX</pcolor>
    <scolor>#$THEME_COLOR_BACKGD_HEX</scolor>
    </wallpaper>
</wallpapers>
EOF
}



InstallKvantumTheme ()
{
    [[ -d /usr/share/Kvantum ]] && return

    # Kvantum install
    apt::AddPpaPackages krisives/kvantum kvantum
    gui::AddAppFolder Settings kvantummanager
    gui::SetAppName kvantummanager "Kvantum Mgr"

    # Kvantum custom theme
    sys::Copy --rename \
        "/usr/share/themes/$THEME_GS/kvantum/" \
        "/usr/share/Kvantum/$THEME_GTK/"

    sys::Write <<EOF $HOME/.config/Kvantum/kvantum.kvconfig
[General]
theme=$THEME_GTK
EOF
}



InstallCodecs ()
{
    apt::AddPackages \
        lame \
        gstreamer1.0-fluendo-mp3 \
        gstreamer1.0-plugins-bad \
        gstreamer1.0-plugins-ugly \
        gstreamer1.0-libav \
        libavcodec-extra \
        chromium-codecs-ffmpeg-extra \
        libdvdread4

    # DEV: pulls 200 packages (400MB) from kde
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPackages \
            libk3b6-extracodecs
            oxideqt-codecs-extra
    else
        apt::AddPackages libk3b7-extracodecs
    fi


    # libdvdcss
    apt::AddSelection "libdvd-pkg      libdvd-pkg/build        boolean true"
    apt::AddSelection "libdvd-pkg      libdvd-pkg/upgrade      note"
    apt::AddSelection "libdvd-pkg      libdvd-pkg/post-invoke_hook-remove      boolean false"
    apt::AddSelection "libdvd-pkg      libdvd-pkg/post-invoke_hook-install     boolean true"
    apt::AddSelection "libdvd-pkg      libdvd-pkg/first-install        note"
    apt::AddPackages libdvd-pkg
    dpkg-reconfigure -f noninteractive libdvd-pkg
    rm -rf /usr/src/libdvd-pkg/
}

InstallFonts ()
{
    InstallFontsDefault

    if [[ "$INSTALL_FREE" != "1" ]] ; then
        InstallFontsApple_NONFREE
        InstallFontsMicrosoft_NONFREE
    fi

    ## Clear cache
    fc-cache -f -v
}


InstallFontsDefault ()
{
    # Hack: powerline-patched
    local dest="/usr/share/fonts/truetype/hack/"
    for ttf in Hack-Bold.ttf Hack-BoldItalic.ttf Hack-Italic.ttf Hack-Regular.ttf ; do
        net::Download \
            "https://github.com/powerline/fonts/raw/master/Hack/$ttf" \
            "$dest"
    done

    # Hack: Alias as monospace
    sys::Write <<'EOF' /etc/fonts/conf.d/99-hack.conf
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
    <match target="pattern">
        <test qual="any" name="family">
            <string>monospace</string>
        </test>
        <edit name="family" mode="assign" binding="same">
            <string>hack</string>
        </edit>
    </match>
</fontconfig>
EOF

    # Fontawesome
    apt::AddPackages fonts-font-awesome

    # Noto Emoji
    apt::AddPackages fonts-noto-color-emoji
}


InstallFontsApple_NONFREE ()
{

    font::dfont2ttf () # $1:SRC_FILE $2:DST_DIR
    {
        local name=$( basename "$1" .dfont )
        local tempdir=$( mktemp -d )
        cp "$1" "$tempdir/"
        sys::Chk

        local uninstall
        if ! which fondu ; then
            uninstall="$uninstall fondu"
            apt::AddPackages fondu
        fi

        pushd $tempdir
        fondu -show -latin1 "$name.dfont"
        sys::Chk
        popd

        mkdir -p "$2"
        mv "$tempdir/$name"*.ttf "$2"
        sys::Chk

        rm -rf "$tempdir"

        [[ -n "$uninstall" ]] && apt::RemovePackages $uninstall
    }

    local tempdir=$( mktemp -d )

    # Helvetica from Sage/streamline-pdfkit
    # DEV ALT http://sourceforge.net/projects/linuxx/files/?source=navbar
    net::Download \
        "https://github.com/Sage/streamline-pdfkit/raw/master/demo/fonts/Helvetica.dfont" \
        "$tempdir/Helvetica.dfont"
    font::dfont2ttf \
        "$tempdir/Helvetica.dfont" \
        /usr/share/fonts/truetype/apple_helvetica

    # HelveticaNeue from vodik/packages-archlinux
    net::Download \
        "https://github.com/vodik/packages-archlinux/raw/master/ttf-mac/HelveticaNeue.dfont" \
        "$tempdir/HelveticaNeue.dfont"
    font::dfont2ttf \
        "$tempdir/HelveticaNeue.dfont" \
        /usr/share/fonts/truetype/apple_helvetica

    rm -rf $tempdir

    # Menlo from hbin/top-programming-fonts
    for ttf in "Menlo-Regular.ttf" ; do # "Monaco-Linux.ttf" BUGGY at 12px in FF
        net::Download \
            "https://github.com/hbin/top-programming-fonts/raw/master/$ttf" \
            /usr/share/fonts/truetype/apple-programming/
    done

}


InstallFontsMicrosoft_NONFREE ()
{
    apt::AddSelection "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true"
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then

        # apt::AddPackages ttf-mscorefonts-installer
        # BUG https://bugs.launchpad.net/ubuntu/+source/aptitude/+bug/1543280
        # chown _apt /var/lib/update-notifier/package-data-downloads/partial/
        # sys::Chk
        # WORKAROUND

        apt::AddRemotePackages \
            "http://ftp.de.debian.org/debian/pool/contrib/m/msttcorefonts/ttf-mscorefonts-installer_3.7_all.deb"

        apt-mark hold ttf-mscorefonts-installer

    else
        apt::AddPackages ttf-mscorefonts-installer
    fi

    # DEV wingdings is not here :(
    # DEV webdings is not readable https://bugs.launchpad.net/ubuntu/+source/fontconfig/+bug/1195799


    # FROM http://plasmasturm.org/code/vistafonts-installer/vistafonts-installer
    local dest=/usr/share/fonts/truetype/ms-fonts
    local tempppv=$( mktemp )
    local tempdir=$( mktemp -d )
    sys::Mkdir /usr/share/fonts/truetype/ms-fonts/
    net::Download \
        "https://sourceforge.net/projects/mscorefonts2/files/cabs/PowerPointViewer.exe/download" \
        "$tempppv"
    cabextract -L -F ppviewer.cab \
        -d "$tempdir" \
        "$tempppv"
    sys::Chk
    cabextract -L -F '*.TT[FC]' \
        -d "$dest"/ \
        "$tempdir/ppviewer.cab"
    sys::Chk
    mv $dest/cambria.tt{c,f}
    chmod 644 $dest/*.ttf

    # Segoe UI
    net::DownloadGithubFiles xamarin/evolve-presentation-template \
            /usr/share/fonts/truetype/ "Fonts/Segoe UI/"
    mv /usr/share/fonts/truetype/"Segoe UI"/*.ttf /usr/share/fonts/truetype/ms-fonts/
    sys::Chk
    rm -rf /usr/share/fonts/truetype/"Segoe UI"/
}

