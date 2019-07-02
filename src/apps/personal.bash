########
# FUNC #  BUNDLES::PERSONAL
########



PACKAGES_PERSONAL="
    app::Android
    app::Electrum
    app::Evolution
    app::Google
    app::Keepassxc
    app::Keybase
    app::Liferea
    app::Qownnotes
    app::Rambox
    "
    # OLD BROKEN app::Authenticator
    # app::Zcash
    # TODO GnuCash



app::Zcash ()
{
    # TOCHECK https://github.com/zcash-community/electrum-zec
    # TOCHECK https://github.com/miguelmarco/pyzcto

    apt::AddSource zcash \
        "[arch=amd64] https://apt.z.cash/" \
        "jessie main" \
        "https://apt.z.cash/zcash.asc"

    apt::AddPackages zcash

    # zcash-fetch-params

    sys::Write <<EOF $HOME/.zcash/zcash.conf
rpcuser=username
rpcpassword=$( head -c 32 /dev/urandom | base64 )
mainnet=1
addnode=mainnet.z.cash
EOF

    # TIP: create a shielded address (z-addr):
    # zcash-cli z_getnewaddress
    # TIP: send funds to this z-addr from a transparent address
    # zcash-cli z_sendmany "$TADDR" "[{\"amount\": 0.8, \"address\": \"$ZADDR\"}]"
}



app::Qownnotes ()
{
    Meta --desc "Markdown notepad" \
         --no-default true

    apt::AddPpaPackages pbek/qownnotes qownnotes

    gui::AddAppFolder Personal PBE.QOwnNotes

    gui::SetAppProp PBE.QOwnNotes StartupWMClass QOwnNotes

    sys::Write <<'EOF' "$HOME/.config/PBE/QOwnNotes.conf"
[General]
darkMode=true
darkModeColors=true
notesPath=/data/user/Notes

[Editor]
CurrentSchemaKey=EditorColorSchema-6d7d03f9-ffac-4e75-a57b-847fd4871eac

[appMetrics]
disableAppHeartbeat=true
disableTracking=true
notificationShown=true
EOF

    # owncloud sync client
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddSource ownclound \
            "http://download.opensuse.org/repositories/isv:/ownCloud:/desktop/Ubuntu_16.04/" \
            "/" \
            "https://download.opensuse.org/repositories/isv:ownCloud:desktop/Ubuntu_16.04/Release.key"
    else
        apt::AddSource ownclound \
            "http://download.opensuse.org/repositories/isv:/ownCloud:/desktop/Ubuntu_18.04/" \
            "/" \
            "https://download.opensuse.org/repositories/isv:ownCloud:desktop/Ubuntu_18.04/Release.key"
    fi
    apt::AddPackages owncloud-client # owncloud-client-nautilus
    gui::AddAppFolder Transfer owncloud
    gui::SetAppName owncloud ownCloud
}



app::Rambox ()
{
    Meta --desc "Universal Web Chat client"

    apt::AddPackages libappindicator1

    # BROKEN "https://getrambox.herokuapp.com/download/linux_64?filetype=deb"

    net::InstallGithubLatestRelease ramboxapp/community-edition '-amd64\\.deb$'

    gui::AddAppFolder Personal rambox


    # TOCHECK $HOME/.config/Rambox/config.json

    # TODO Firejail launcher
    # https://github.com/netblue30/firejail/blob/master/etc/rambox.profile
}



app::Keybase ()
{
    Meta --desc "Key directory, storage & chat" \
         --no-default true

    apt::AddRemotePackages "https://prerelease.keybase.io/keybase_amd64.deb"
    gui::AddAppFolder Personal keybase

    # BUG keybase: protocol can’t be used for submodules
    # TODO git config --global --add protocol.keybase.allow always

    # TODO run_keybase
    # TOCHECK autostart: $HOME/.config/autostart/keybase_autostart.desktop
}



app::Electrum ()
{
    Meta --desc "Bitcoin wallet" \
         --no-default true

    apt::AddPackages python-jsonrpclib zbar-tools

    pip::Install \
        "https://download.electrum.org/3.2.3/Electrum-3.2.3.tar.gz"

    sys::Write <<EOF /usr/local/share/applications/electrum.desktop
[Desktop Entry]
Type=Application
Terminal=false
Name=Electrum
Exec=electrum
Icon=electrum
StartupWMClass=electrum
EOF
    gui::AddAppFolder Personal electrum

    # Enforce TOR proxy
    sys::Write <<'EOF' $HOME/.electrum/config 1000:1000 750
{
    "proxy": "socks5:127.0.0.1:9050::"
}
EOF
}



app::Authenticator ()
{

    Meta --desc "Two-factor auth code generator" \
         --no-default true

    # DEP: zbar
    apt::AddPackages python-dev libzbar0 libzbar-dev
    pip::Install zbarlight

    # DEP: gnome-screenshot
    apt::AddPackages gnome-screenshot
    gui::HideApps org.gnome.Screenshot

    apt::AddPackages gir1.2-gnomekeyring-1.0

    # NO PPA, ALT
    apt::AddRemotePackages \
        "http://mirrors.dotsrc.org/getdeb/ubuntu/pool/apps/g/gnome-twofactorauth/gnome-twofactorauth_0.1.1-1~getdeb1_all.deb" \
        "http://mirrors.dotsrc.org/getdeb/ubuntu/pool/apps/z/zbarlight/python-zbarlight_1.2-1~getdeb1_amd64.deb"
    rm -fv /etc/apt/sources.list.d/getdeb.src.*

    gui::SetAppName gnome-twofactorauth Authenticator
    gui::AddAppFolder Personal gnome-twofactorauth
}



app::Keepassxc ()
{
    Meta --desc "Password manager"

    apt::AddPpaPackages phoerious/keepassxc keepassxc
    gui::AddAppFolder Personal org.keepassxc.KeePassXC
    gui::AddKeybinding keypassxc "<Super>p" \
        'bash -c "xdotool windowactivate \\$( comm -13 <( xdotool search -maxdepth 1 --class keepassxc | sort) <( xdotool search --class keepassxc | sort ) | tail -1 ) 2>/dev/null || keepassxc"'

    sys::Write <<EOF $HOME/.config/keepassxc/keepassxc.ini 1000:1000
[General]
AutoSaveAfterEveryChange=true
GlobalAutoTypeKey=80
GlobalAutoTypeModifiers=402653184
RememberLastKeyFiles=false

[security]
autotypeask=true
passwordsrepeat=true
EOF
# GlobalAutoTypeKey=75 # K
# GlobalAutoTypeKey=80 # P
# GlobalAutoTypeModifiers=167772160 # ALT SHIFT
# GlobalAutoTypeModifiers=335544320 # CTRL META
# GlobalAutoTypeModifiers=402653184 # ALT META

}



app::Android ()
{
    Meta --desc "Android sync" \
         --no-default true

    rm $HOME/.local/share/dbus-1/services/org.gtk.vfs.MTPVolumeMonitor.service

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages webupd8team/indicator-kdeconnect kdeconnect indicator-kdeconnect
        gui::AddAppFolder Personal indicator-kdeconnect
        gui::AddAppFolder Settings org.kde.kdeconnect.kcm
        gui::HideApps indicator-kdeconnect-settings org.kde.kdeconnect.nonplasma

        # ALT mconnect
        # apt::AddPackages kdeconnect
        # gui::AddShellExtensionsById 1272

        apt::AddPpaPackages samoilov-lex/aftl-stable  android-file-transfer aft-mtp-cli
        gui::AddAppFolder Transfer android-file-transfer
    else
        # gsconnect
        apt::AddPackages sshfs libfolks-dev libfolks-eds25
        # gui::AddShellExtensionsByUrl \
        #     "https://github.com/andyholmes/gnome-shell-extension-gsconnect/releases/download/v9/gsconnect.andyholmes.github.io.zip"
        # gui::AddShellExtensionsById --nodefault 1319

        sudo --set-home -u \#1000 gnome-shell-extension-installer --yes 1319
        # DEV: seems buggy when installed *globally* (in /usr/share/gnome-shell/extensions/)
        gui::FixShellExtension --nodefault gsconnect@andyholmes.github.io
        # FIX perms
        chmod +x $HOME/.local/share/gnome-shell/extensions/gsconnect@andyholmes.github.io/service/daemon.js

        # DEV: notice WRONG Uppercase dconf path
        sys::Write <<EOF --append "$POSTINST_USER_SESSION_SCRIPT"
gsettings set org.gnome.Shell.Extensions.GSConnect  public-name           $HOST_HOSTNAME
gsettings set org.gnome.Shell.Extensions.GSConnect  show-indicators       true
EOF

        # TODO .local/share/gnome-shell/extensions/gsconnect@andyholmes.github.io/metadata.json
        # "gschemadir": "/usr/share/glib-2.0/schemas",

        sys::Write <<'EOF' /usr/local/share/applications/gsconnect.desktop 1000:1000 750
[Desktop Entry]
Name=Android KDE
Exec=gnome-shell-extension-prefs gsconnect@andyholmes.github.io
Terminal=false
Type=Application
Icon=androidstudio
EOF
        gui::AddAppFolder Personal gsconnect

        gui::AddExtensionSwitch gsconnect "gsconnect@andyholmes.github.io" 1


        # Android MTP
        apt::AddPpaPackages --release xenial samoilov-lex/aftl-stable  android-file-transfer aft-mtp-cli
        gui::AddAppFolder Personal android-file-transfer
        gui::SetAppName android-file-transfer "Android MTP"

    fi
}



app::Evolution ()
{
    Meta --desc "Mail & personal manager"

    rm $HOME/.local/share/dbus-1/services/org.gnome.evolution.dataserver.*

    apt::AddPackages evolution \
        evolution-plugins evolution-ews evolution-plugins-experimental \
        evolution-data-server-online-accounts

    gui::AddAppFolder Personal evolution
    gui::AddAppFolder Personal org.gnome.Evolution # BIONIC


    # local-mail
    if [[ -d "$HOME/.local/share/localhost.Maildir" ]] ; then
        sys::Write --append <<'EOF' "$POSTINST_USER_SESSION_SCRIPT"
# Configure gnome.evolution.dataserver to handle local-mail via dbus

maildir="$HOME/.local/share/localhost.Maildir"
uid=$( date -d now "+%s" ).1

val1="[Data Source]
DisplayName=root@localhost
Enabled=true
Parent=$uid.2@localhost

[Mail Composition]
Bcc=
Cc=
DraftsFolder=folder://local/Drafts
ReplyStyle=default
SignImip=true
TemplatesFolder=folder://local/Templates

[Mail Identity]
Address=root@localhost
Name=root@localhost
Organization=
ReplyTo=
SignatureUid=none

[Mail Submission]
SentFolder=folder://local/Sent
TransportUid=$uid.3@localhost
RepliesToOriginFolder=false
"

val2="[Data Source]
DisplayName=root@localhost
Enabled=true
Parent=

[Refresh]
Enabled=true
IntervalMinutes=1

[Mail Account]
BackendName=maildir
IdentityUid=$uid.1@localhost
ArchiveFolder=
NeedsInitialSetup=true

[Maildir Backend]
FilterInbox=true
Path=$maildir
"

val3="[Data Source]
DisplayName=root@localhost
Enabled=true
Parent=$uid.2@localhost

[Mail Transport]
BackendName=sendmail

[Sendmail Backend]
UseCustomBinary=false
UseCustomArgs=false
CustomBinary=
CustomArgs=
SendInOffline=true
"

# DOC: https://developer.gnome.org/libedbus-private/stable/gdbus-org.gnome.evolution.dataserver.SourceManager.html
dbus-send \
    --type=method_call \
    --print-reply \
    --dest=org.gnome.evolution.dataserver.Sources5 \
    /org/gnome/evolution/dataserver/SourceManager \
    org.gnome.evolution.dataserver.SourceManager.CreateSources \
    dict:string:string:"$uid.1@localhost","$val1","$uid.2@localhost","$val2","$uid.3@localhost","$val3"

# Configure gnome.evolution.dataserver to handle disable "On This Computer" datasource

## Identify sub nodes
ids=$( dbus-send --print-reply --dest=org.gnome.evolution.dataserver.Sources5 \
        /org/gnome/evolution/dataserver/SourceManager \
        org.freedesktop.DBus.Introspectable.Introspect \
    | awk -F '"' 'NR==2{$1="" ; $0=$0 ; print substr($1, 2) } NR>2' \
    | head --lines=-1 \
    | tail --lines=+3 \
    | xmlstarlet sel --template -v '/node/node/@name' \
    | grep 'Source_' \
    | sed 's/^Source_//' \
    | sort -n
    )

for id in $ids ; do

    ## Read UID
    uid=$( dbus-send --print-reply \
            --dest=org.gnome.evolution.dataserver.Sources5 \
            /org/gnome/evolution/dataserver/SourceManager/Source_$id \
            org.freedesktop.DBus.Properties.Get \
            string:org.gnome.evolution.dataserver.Source \
            string:UID \
        | awk -F '"' 'NR==2{print $2}' )

    if [[ $uid == "local" ]] ; then

        # Read config
        cnf=$( dbus-send --print-reply \
                --dest=org.gnome.evolution.dataserver.Sources5 \
                /org/gnome/evolution/dataserver/SourceManager/Source_$id \
                org.freedesktop.DBus.Properties.Get \
                string:org.gnome.evolution.dataserver.Source \
                string:Data \
            | awk -F '"' 'NR==2{$1="" ; $0=$0 ; print substr($1, 2) } NR>2' \
            | head --lines=-1 )

        # Set config: Disable
        dbus-send --print-reply \
                --dest=org.gnome.evolution.dataserver.Sources5 \
                /org/gnome/evolution/dataserver/SourceManager/Source_$id \
                org.gnome.evolution.dataserver.Source.Writable.Write \
                string:"$( sed -E 's/^(Enabled=).*/\1false/' <<<"$cnf" )"
        break
    fi
done
EOF
    fi
}



app::Liferea ()
{

    Meta --desc "Feed aggregator" \
         --no-default true

    apt::AddPpaPackages ubuntuhandbook1/apps liferea

    gui::AddAppFolder Personal net.sourceforge.liferea

    # TODO /home/user/.local/share/liferea/liferea.db
    # SQLITE3 node subscription subscription_metadata
    # TODO plugins: +HeaderBar -TrayIcon +BoldUnread
}



app::Google ()
{

    Meta --desc "Google desktop integration" \
         --no-default true

    # BUG evolution msg:
    # failed to lookup credentials
    # google authentication is not supported

    # UNSTUB dbus
    rm $HOME/.local/share/dbus-1/services/org.gnome.evolution.dataserver.*
    rm $HOME/.local/share/dbus-1/services/org.gnome.Shell.CalendarServer.service
    rm $HOME/.local/share/dbus-1/services/org.gnome.keyring.*
    rm $HOME/.local/share/dbus-1/services/org.gtk.vfs.GoaVolumeMonitor.service

    # gnome-keyring: UNSTUB autostart
    pushd /etc/xdg/autostart/
    for i in gnome-keyring-secrets ; do # gnome-keyring-gpg gnome-keyring-pkcs11 gnome-keyring-ssh
        mv $i.desktop.ORIG $i.desktop
    done
    popd

    # GOA
    apt::AddPackages \
        gnome-online-accounts evolution-data-server-online-accounts
        # gir1.2-goa-1.0 gir1.2-gdata-0.0
        # account-plugin-google
    # libaccount-plugin-generic-oauth
    # seahorse ?


    # Google Drive over FUSE
    # DOC https://github.com/astrada/google-drive-ocamlfuse/wiki
    apt::AddPpaPackages alessandro-strada/ppa google-drive-ocamlfuse
}
