########
# FUNC #  BUNDLES::LEARN
########



PACKAGES_LEARN="
    app::Maps
    app::Earth_NONFREE
    app::Stellarium
    app::TunesViewer
    app::Gcompris
    app::Geogebra
    app::Scratch_NONFREE
    "
    # app::Kiwix
    # ALT WebArchives https://github.com/birros/web-archives
    # TODO WebArchives as soon as DEB packages are available



app::AdobeAir_NONFREE ()
{
    Meta --desc "Adobe Air Runtime" \
     --no-default true

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        sys::Msg Adobe Air Runtime UNSUPPORTED for xenial
        return 1
    fi

    local airpath=/opt/adobe-air-sdk

    [[ -d "$airpath" ]] && return

    # DEV: https://askubuntu.com/questions/913892/how-to-install-scratch-2-on-ubuntu-16-10-or-17-04-64bit/913912#913912

    # 32bit support
    dpkg --add-architecture i386
    sys::Chk
    apt::Update

    sys::Mkdir "$airpath"

    # DEPS
    local airdeps="libgtk2.0-0:i386 libstdc++6:i386 libxml2:i386 libxslt1.1:i386 libcanberra-gtk-module:i386 gtk2-engines-murrine:i386 libqt4-qt3support:i386 libgnome-keyring0:i386 libnss-mdns:i386 libnss3:i386"
    apt::AddPackages $airdeps

    # FIX: gnome-keyring
    ln -s /usr/lib/i386-linux-gnu/libgnome-keyring.so.0 /usr/lib/libgnome-keyring.so.0
    sys::Chk
    ln -s /usr/lib/i386-linux-gnu/libgnome-keyring.so.0.2.0 /usr/lib/libgnome-keyring.so.0.2.0
    sys::Chk

    net::DownloadUntarBzip \
        "http://airdownload.adobe.com/air/lin/download/2.6/AdobeAIRSDK.tbz2" \
        "$airpath"

    local tmptgz=$( mktemp )
    net::Download https://aur.archlinux.org/cgit/aur.git/snapshot/adobe-air.tar.gz "$tmptgz"
    tar --directory "$airpath" -xzvf "$tmptgz"
    sys::Chk
    chmod +x "$airpath"/adobe-air/adobe-air
    sys::Chk
}



app::Scratch_NONFREE ()
{
    Meta --desc "Code for kids" \
         --no-default true

    app::AdobeAir_NONFREE || return
    local airpath=/opt/adobe-air-sdk

    net::Download \
        "https://scratch.mit.edu/scratchr2/static/sa/Scratch-456.0.1.air" \
        "$airpath"/scratch/

   sys::Write <<EOF /usr/local/share/applications/scratch.desktop
[Desktop Entry]
Type=Application
Terminal=false
Name=Scratch
Exec=$airpath/adobe-air/adobe-air $airpath/scratch/Scratch-456.0.1.air
Icon=scratch
StartupWMClass=Adl
EOF
    gui::AddAppFolder Learn scratch
}



app::Maps ()
{
    Meta --desc "Online maps (OpenStreetMaps)" \
         --no-default true

    apt::AddPackages gnome-maps

    gui::AddAppFolder Learn org.gnome.Maps
}



app::Gcompris ()
{
    Meta --desc "Kids suite" \
         --no-default true

    apt::AddPackages gcompris-qt
    gui::SetAppName org.kde.gcompris GCompris
    gui::SetAppIcon org.kde.gcompris gcompris
    gui::AddAppFolder Learn org.kde.gcompris
}



app::Stellarium ()
{
    Meta --desc "Online planetarium" \
         --no-default true

    apt::AddPpaPackages stellarium/stellarium-releases \
        stellarium stellarium-data

    gui::AddAppFolder Learn stellarium

}



# TIP: https://wiki.kiwix.org/wiki/Content_in_all_languages
app::Kiwix ()
{
    Meta --desc "Offline Learning" \
         --no-default true

    # net::Download "https://download.kiwix.org/bin/kiwix-linux-x86_64.tar.bz2" \
    net::DownloadUntarBzip \
        "http://download.kiwix.org/bin/0.10/kiwix-0.10-linux-x86_64.tar.bz2" \
        /opt

    mv /opt/kiwix-* /opt/kiwix

    [[ -d "/opt/kiwix" ]] || sys::Die "Failed to install kiwix"

    # Fix perms
    find /opt/kiwix      -executable -exec chmod 0755 {} \;
    find /opt/kiwix -not -executable -exec chmod 0644 {} \;

    # WORKAROUND https://github.com/kiwix/kiwix-xulrunner/issues/477
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        :
    else
        apt::AddPackages zlib1g
        ln -sf /lib/x86_64-linux-gnu/libz.so.1 /opt/kiwix/xulrunner/
        sys::Chk
    fi

    # CONF: BUG NO EFFECT
    sys::Write --append <<'EOF' /opt/kiwix/defaults/preferences/preferences.js
/* Inverted colors */
pref("kiwix.invertedColors", true);
EOF


    sys::Write <<'EOF' /usr/local/share/applications/kiwix.desktop
[Desktop Entry]
Name=Kiwix
Exec=/opt/kiwix/kiwix
Terminal=false
Type=Application
Icon=kiwix
EOF

    gui::AddAppFolder Learn kiwix
}



app::Geogebra ()
{
    Meta --desc "Math Learning" \
         --no-default true

    # DEV deb SRC sometimes broken
    apt::AddSource --force-name geogebra \
        "http://www.geogebra.net/linux/" \
        "stable main" \
        "https://static.geogebra.org/linux/office@geogebra.org.gpg.key"
    apt::AddPackages geogebra-classic
    # ALT apt::AddRemotePackages "http://www.geogebra.org/download/deb.php?arch=amd64&ver=6"
    gui::SetAppIcon geogebra-classic geogebra
    gui::AddAppFolder Learn geogebra-classic
}



app::TunesViewer ()
{
    Meta --desc "iTunes-University client" \
         --no-default true

       apt::AddRemotePackages \
        "https://sourceforge.net/projects/tunesviewer/files/tunesviewer_2.1.deb/download" \
    || return 1

    gui::AddAppFolder Learn TunesViewer
    gui::SetAppProp TunesViewer StartupWMClass tunesviewer

    sys::Write --append <<EOF $HOME/.config/tunesviewer/tunesviewer.conf 1000:1000 600
[TunesViewerPrefs]
defaultmode = 2
openers = .m4a:vlc --http-user-agent=iTunes/10.6.3.25
    .mov:vlc --http-user-agent=iTunes/10.6.3.25
    .pdf:xdg-open
    .3gp:vlc --http-user-agent=iTunes/10.6.3.25
    .m4v:vlc --http-user-agent=iTunes/10.6.3.25
    .m4p:vlc --http-user-agent=iTunes/10.6.3.25
    .mp3:vlc --http-user-agent=iTunes/10.6.3.25
    .aiff:vlc --http-user-agent=iTunes/10.6.3.25
    .aif:vlc --http-user-agent=iTunes/10.6.3.25
    .aifc:vlc --http-user-agent=iTunes/10.6.3.25
    .mp4:vlc --http-user-agent=iTunes/10.6.3.25

downloadfolder = $HOME/Downloads
downloadfile = %p/%n %l%t
downloadsafefilename = True
toolbar = True
statusbar = True
notifyseconds = 7
podcastprog = clementine %i
imagesize = 48
iconsize = 16
throbber = False
home = http://itunes.apple.com/WebObjects/MZStore.woa/wa/viewGenre?id=40000000
releasedcol = True
modifiedcol = True
zoomall = True
zoom = 1.0
enablesentry = False
enableadblock = True

EOF
}



app::Earth_NONFREE ()
{
    Meta --desc "Online earth explorer (Google)" \
         --no-default true

    # ALT: deb http://dl.google.com/linux/earth/deb/ stable main

    apt::AddRemotePackages \
        "https://dl.google.com/dl/earth/client/current/google-earth-stable_current_amd64.deb"

    gui::AddAppFolder Learn google-earth-pro

    gui::SetAppIcon google-earth-pro googleearth

    gui::SetAppProp google-earth-pro StartupWMClass googleearth-bin

    # FIX BUG apt i386
cat  /etc/apt/sources.list.d/google-earth-pro.list # DBG
    sleep 5 #
cat  /etc/apt/sources.list.d/google-earth-pro.list # DBG
    sys::SedInline 's#^(deb)#\1 [arch=amd64]#' \
        /etc/apt/sources.list.d/google-earth-pro.list
cat  /etc/apt/sources.list.d/google-earth-pro.list # DBG

    # FIX BUG Qt4 coordinates
    # https://productforums.google.com/forum/?hl=en#!category-topic/earth/problems-and-errors/h4H2KR5i3qE
    sys::SedInline  's#( ./googleearth-bin)# LC_ALL=us_US.UTF-8\1#' \
        /opt/google/earth/pro/googleearth

}
