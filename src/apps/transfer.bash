########
# FUNC #  BUNDLES::TRANSFER
########



PACKAGES_TRANSFER="
    app::Grsync
    app::Filezilla
    app::Nitroshare
    app::Sftpman
    app::Transmission

    app::Sparkleshare
    app::Syncthing
    app::Rclonebrowser

    app::Dropbox_NONFREE
    app::Mega_NONFREE
    "



app::Grsync ()
{
    Meta --no-default true \
         --desc "Rsync GUI"

    apt::AddPackages rsync grsync
    gui::AddAppFolder Transfer grsync
}



app::Mega_NONFREE ()
{
    Meta --desc "Sync client (Mega)" \
         --no-default true

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddSource mega \
            "https://mega.nz/linux/MEGAsync/xUbuntu_16.04/" \
            "./"
        apt::AddPackages megacmd megasync nautilus-megasync
    else
        apt::AddSource mega \
            "https://mega.nz/linux/MEGAsync/xUbuntu_18.04/" \
            "./"
        apt::AddPackages megacmd megasync nautilus-megasync
    fi

    gui::AddAppFolder Transfer megasync

    # FIX duplicate source
    rm -f /etc/apt/sources.list.d/mega.src.list
    # FIX update-notifier
    rm -f /var/lib/update-notifier/user.d/megasync-install-notify

    # TOCHECK https://github.com/tonikelope/megadown
}



app::Dropbox_NONFREE ()
{
    Meta --desc "Sync client (Dropbox)" \
         --no-default true

    apt::AddPackages nautilus-dropbox python-gpg
    gui::AddAppFolder Transfer dropbox

    rm /var/lib/update-notifier/user.d/dropbox-*

# TODO POSTINST UI??? : `dropbox update` downloads ~/.dropbox-dist/dropboxd
# TIP: `dropbox autostart`
}



app::Transmission ()
{
    Meta --desc "Torrent client"

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages transmissionbt/ppa \
            transmission transmission-common transmission-gtk
    else
        apt::AddPackages transmission transmission-gtk
    fi

    gui::AddAppFolder Transfer transmission-gtk

# TOCHECK    https://extensions.gnome.org/extension/365/transmission-daemon-indicator/

# TODO CONF .config/transmission/settings.json
    # { "encryption": 2 }
    # "blocklist-enabled": true,
    # "blocklist-url": "http://john.bitsurge.net/public/biglist.p2p.gz",
    # "peer-port": 51413,
}



app::Syncthing ()
{
    Meta --desc "File sync" \
         --no-default true

    apt::AddSource syncthing \
        "https://apt.syncthing.net/" \
        "syncthing stable" \
        "https://syncthing.net/release-key.txt"
    apt::AddPackages syncthing
    gui::HideApps syncthing-start syncthing-ui

    # syncthing daemon
    local url="$( net::GetGithubLatestRelease syncthing/syncthing '/syncthing-linux-amd64-.*\\.tar\\.gz$' )"
    [[ -n "$url" ]] || sys::Die "Failed to identify Syncthing daemon url"
    net::DownloadUntarGzip "$url" /usr/local/bin --strip-components=1 "$( basename "$url" .tar.gz )/syncthing"

    # DEPRACATED
    # syncthing-inotify for CLI
    #   net::Download "https://github.com/syncthing/syncthing-inotify/releases/download/v0.8.7/syncthing-inotify-linux-amd64-v0.8.7.tar.gz" \
    # | tar xz --directory /usr/local/bin
    # sys::Chk

    # syncthing-gtk, includes inotify for GUI
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages nilarimogard/webupd8 syncthing-gtk
    else
        # BIONIC missing
        apt::AddPpaPackages --release xenial nilarimogard/webupd8 syncthing-gtk
    fi
    gui::SetAppName syncthing-gtk "Syncthing"


    gui::AddAppFolder Transfer syncthing-gtk

    # TOCHECK https://extensions.gnome.org/extension/989/syncthing-icon/

    # CONF
    mkdir $HOME/.config/syncthing
    chown 1000:1000 $HOME/.config/syncthing

}



app::Rclonebrowser ()
{
    Meta --desc "Cloud sync"

    cli::Rclone

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages nilarimogard/webupd8 rclone-browser
    else
        # BIONIC missing
        apt::AddPpaPackages --release xenial nilarimogard/webupd8 rclone-browser
    fi

    gui::AddAppFolder Transfer rclone-browser
    gui::SetAppIcon rclone-browser web-jolicloud
    gui::SetAppName rclone-browser "Rclone"
}



app::Sparkleshare ()
{
    Meta --desc "Git sync" \
         --no-default true

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages rebuntu16/sparkleshare+unofficial sparkleshare
    else
        apt::AddPackages sparkleshare
    fi
    gui::AddAppFolder Transfer sparkleshare

    # TODO install Dazzle on servers
    # https://github.com/hbons/Dazzle
}



app::Filezilla ()
{
    Meta --desc "Sftp client"

    apt::AddPackages filezilla
    gui::AddAppFolder Transfer filezilla

    sys::Write --append <<EOF "$HOME/.config/filezilla/filezilla.xml" 1000:1000
<?xml version="1.0" encoding="UTF-8"?>
<FileZilla3 platform="*nix">
  <Settings>
    <Setting name="Greeting version">99</Setting>
    <Setting name="Disable update check">1</Setting>
    <Setting name="Update Check">0</Setting>
    <Setting name="Show message log">0</Setting>
    <Setting name="Show queue">0</Setting>
    <Setting name="File Pane Layout">3</Setting>
    <Setting name="Theme">flatzilla/</Setting>
    <Setting name="Theme icon size">24x24</Setting>
    <Setting name="Date Format">1</Setting>
    <Setting name="Time Format">1</Setting>
    <Setting name="Default editor">1</Setting>
  </Settings>
</FileZilla3>
EOF

}



app::Nitroshare ()
{
    Meta --desc "Lan share"

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages george-edison55/nitroshare nitroshare
        apt::AddPackages nitroshare-nautilus
    else
        apt::AddPackages nitroshare nitroshare-nautilus
    fi
    gui::AddAppFolder Transfer nitroshare

    sys::Write <<'EOF' "$HOME/.config/Nathan Osman/NitroShare.conf" 1000:1000
[General]
ApplicationSplash=true
EOF
# BehaviorQuarantine=false
}



app::Sftpman ()
{
    Meta --desc "Sshfs client"

    # DEPS: pip
    cli::Python

    pip::Install sftpman-gtk

    # .desktop launcher
    sys::Write <<'EOF' /usr/share/applications/sftpman.desktop
[Desktop Entry]
Encoding=UTF-8
Name=SftpMan
Comment=sshfs/sftp mount
Exec=sftpman-gtk
Terminal=false
Type=Application
StartupNotify=true
Icon=knetattach
Categories=Network;FileTransfer;GTK;
EOF
    gui::AddAppFolder Transfer sftpman

    # FIX /mnt/sshfs/ writable by sudo group
    mkdir -p /mnt/sshfs
    chown :sudo /mnt/sshfs
    chmod 770 /mnt/sshfs

    # CONF: FUSE user_allow_other
    sed -E -i 's/^#user_allow_other$/user_allow_other/' /etc/fuse.conf

    # CONF: PATCH default options
    sys::PatchText <<'EOPATCH' /usr/local/lib/python3.?/dist-packages/sftpman_gtk/gui.py
@@ -93,7 +93,7 @@
         system.id = ''
         system.user = shell_exec('whoami').strip()
         system.mount_point = '/home/%s/' % system.user
-        system.mount_opts = ['follow_symlinks', 'workaround=rename']
+        system.mount_opts = ['follow_symlinks', 'workaround=rename', 'idmap=user', 'uid=1000', 'gid=1000', 'allow_other']
         RecordRenderer(self, system, added=False).render()

     def handler_edit(self, btn, system_id):
EOPATCH


    # ssh-askpass-gnome ???
    # SSH_ASKPASS=/usr/lib/openssh/gnome-ssh-askpass sftpman-gtk
}
