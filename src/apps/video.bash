########
# FUNC #  BUNDLES::VIDEO
########



PACKAGES_VIDEO="
    app::Vlc
    app::Handbrake
    app::Kdenlive
    app::Openshot
    app::Blender
    "
    # BROKEN app::Natron
    # TOCHECK http://www.strem.io/
    # TOCHECK Blackmagic Design DaVinci Resolve 14



app::Blender ()
{

    Meta --desc "3D studio" \
         --no-default true

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages thomas-schiex/blender blender
    else
        apt::AddPackages blender
    fi

    gui::AddAppFolder Video blender
}



app::Vlc ()
{
    Meta --desc "Universal media player"

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpa --noupgrade videolan/master-daily
    fi
    # TOCHECK  libaacs0  vlc-plugin-pulse
    apt::AddPackages vlc vlc-plugin-notify vlc-plugin-samba
    gui::SetAppName vlc VLC
    gui::AddAppFolder Video vlc

    # MIME
    gui::SetDefaultAppForMimetypes vlc \
        application/ogg \
        audio/ogg \
        audio/x-oggflac \
        audio/x-speex+ogg \
        audio/x-vorbis+ogg \
        audio/aac \
        audio/ac3 \
        audio/basic \
        audio/flac \
        audio/x-flac+ogg \
        audio/x-flac \
        audio/mpeg \
        audio/mp4 \
        audio/x-mp3 \
        audio/x-aiff \
        audio/x-musepack \
        audio/x-tta \
        audio/x-ms-wma \
        audio/x-wav \
        audio/x-wavpack \
        video/mpeg \
        video/mp4 \
        video/ogg \
        video/x-matroska \
        video/webm

    # CONF
    sys::Write <<EOF $HOME/.config/vlc/vlcrc
[qt]
qt-system-tray=0
qt-privacy-ask=0

[core]
metadata-network-access=0
EOF
}



app::Natron ()
{
    Meta --no-default true \
         --desc "Video compositor"

    # DEAD PPA apt::AddPpaPackages samoilov-lex/natron natron
    # EXPIRED-CERT apt::AddRemotePackages "$url"
    local url="https://downloads.natron.fr/Linux/releases/64bit/files/natron_2.3.13_amd64.deb"
    local tempdeb=$( mktemp )
    net::Download --opts --insecure "$url" "$tempdeb"
    apt::AddLocalPackages "$tempdeb"
    rm "$tempdeb"

    # gui::AddAppFolder Video Natron fr.natron.Natron # Natron2
    gui::AddAppFolder Video Natron2
}



app::Handbrake ()
{
    Meta --desc "Video transcoder"

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages stebbins/handbrake-releases handbrake-gtk handbrake-cli
        gui::AddAppFolder Video fr.handbrake.ghb
    else
        apt::AddPackages handbrake handbrake-cli
        gui::AddAppFolder Video ghb
    fi

    gui::AddEditor \
        /usr/share/applications/ghb.desktop \
        convert_video \
        "Convert video"

    # Kazam integration: Hijack avidemux:avidemux-gtk.desktop # ALT pitivi
    sys::Mkdir /usr/share/app-install/desktop/
    cp  /usr/share/applications/ghb.desktop \
        /usr/share/app-install/desktop/avidemux:avidemux-gtk.desktop
    sys::SedInline 's#^(\[Desktop Entry\].*)$#\1\nNoDisplay=true#' \
        /usr/share/app-install/desktop/avidemux:avidemux-gtk.desktop

}



app::Kdenlive ()
{
    Meta --desc "Video editor" \
         --no-default true

    # DEAD PPA for bionic
    # if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
    #     apt::AddPackages kdenlive
    # else
    #     apt::AddPpaPackages kdenlive/mlt libmlt++3 libmlt6 libmlt-data melt
    #     apt::AddPpaPackages kdenlive/kdenlive-stable kdenlive kdenlive-data
    # fi

    apt::AddPackages kdenlive

    apt::AddPackages frei0r-plugins dvdauthor genisoimage
    
    gui::AddAppFolder Video org.kde.kdenlive

    sys::Write <<EOF $HOME/.config/kdenliverc
[unmanaged]
force_breeze=false

[version]
version=$( kdenlive --version 2>/dev/null | awk '{print $2}' )
EOF

    # Kazam integration
    sys::Mkdir /usr/share/app-install/desktop/
    cp  /usr/share/applications/org.kde.kdenlive.desktop \
        /usr/share/app-install/desktop/kdenlive:kde4__kdenlive.desktop
    sys::SedInline 's#^(\[Desktop Entry\].*)$#\1\nNoDisplay=true#' \
        /usr/share/app-install/desktop/kdenlive:kde4__kdenlive.desktop
}



app::Openshot ()
{
    Meta --desc "Video editor"

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages openshot.developers/ppa openshot-qt
    else
        apt::AddPackages openshot-qt
    fi
    gui::SetAppName openshot-qt OpenShot
    gui::AddAppFolder Video openshot-qt

    sys::Write <<'EOF' $HOME/.openshot_qt/openshot.settings 1000:1000 750
[
    {
        "category": "General",
        "restart": true,
        "setting": "theme",
        "title": "Default Theme",
        "title_tr": "Default Theme",
        "type": "dropdown",
        "value": "No Theme",
        "values": [{"name": "Humanity", "value": "Humanity"}, {"name": "Humanity: Dark", "value": "Humanity: Dark"}, {"name": "No Theme", "value": "No Theme"}]
    },
    {
        "category": "Debug",
        "setting": "send_metrics",
        "title": "Send Anonymous Metrics and Errors",
        "title_tr": "Send Anonymous Metrics and Errors",
        "type": "bool",
        "value": false
    },
    {
        "category": "Tutorial",
        "setting": "tutorial_enabled",
        "title": "",
        "type": "hidden",
        "value": false
    },
    {
        "category": "Qt",
        "setting": "window_state",
        "title": "",
        "type": "hidden",
        "value": "AAAA/wAAAAD9AAAAAwAAAAAAAAD8AAAA9PwCAAAAAfwAAAILAAAA9AAAAAAA////+gAAAAECAAAAAvsAAAAcAGQAbwBjAGsAUAByAG8AcABlAHIAdABpAGUAcwAAAAAA/////wAAALYA////+wAAABgAZABvAGMAawBLAGUAeQBmAHIAYQBtAGUAAAAAAP////8AAAAAAAAAAAAAAAEAAAEcAAABQPwCAAAAAfsAAAAYAGQAbwBjAGsASwBlAHkAZgByAGEAbQBlAQAAAVgAAAAVAAAAAAAAAAAAAAACAAAEqwAAAdz8AQAAAAL8AAAAAAAAAWQAAAB7AP////oAAAAAAgAAAAP7AAAAEgBkAG8AYwBrAEYAaQBsAGUAcwEAAAAA/////wAAAKQA////+wAAAB4AZABvAGMAawBUAHIAYQBuAHMAaQB0AGkAbwBuAHMBAAAAAP////8AAACkAP////sAAAAWAGQAbwBjAGsARQBmAGYAZQBjAHQAcwEAAAAA/////wAAAKQA////+wAAABIAZABvAGMAawBWAGkAZABlAG8BAAABagAAA0EAAABJAP///wAABKsAAAEAAAAABAAAAAQAAAAIAAAACPwAAAABAAAAAgAAAAEAAAAOAHQAbwBvAGwAQgBhAHIAAAAAAP////8AAAAAAAAAAA=="
    }
]
EOF

    # WORKAROUND BUG kazam Edit link
    sys::Write \
        "/usr/share/app-install/desktop/openshot:openshot.desktop" \
        <"/usr/share/applications/openshot-qt.desktop"

    # TOCHECK: launcher args + qml css
    # http://openshotusers.com/forum/viewtopic.php?f=12&t=2961
}
