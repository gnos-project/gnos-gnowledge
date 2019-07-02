########
# FUNC #  BUNDLES::ENTERTAIN
########



PACKAGES_ENTERTAIN="
    app::Clementine
    app::Gradio
    app::Headset
    app::Spotify_NONFREE
    app::Freetuxtv
    app::Kodi
    app::PopCornTime
    "



app::Spotify_NONFREE ()
{
    Meta --desc "Music streaming client" \
         --no-default true

    apt::AddSource spotify \
        "http://repository.spotify.com" \
        "stable non-free" \
        "931FF8E79F0876134EDDBDCCA87FF9DF48BF1C90"
    apt::AddPackages spotify-client

    gui::AddAppFolder Entertainment spotify
}



app::Headset ()
{
    Meta --desc "Youtube music player" \
         --no-default true

    apt::AddSource --force-name headset \
        "[arch=amd64] http://headsetapp.co/headset-electron/debian" \
        "stable non-free" \
        "http://headsetapp.co/headset-electron/debian/headset.asc"
    apt::AddPackages headset

    gui::AddAppFolder Entertainment headset

    sys::Write <<'EOF' /usr/local/bin/headset 0:0 755
#!/bin/bash
# NAME Headset app launcher
# DESC Hide Youtube window
# AUTH elias@gnos.in

# FUNC
GetWindowIdsByClass () # $1:WM_CLASS
{
    [[ $# -eq 1 ]] || return 1
      comm -13 2>/dev/null \
        <( xdotool search -maxdepth 1 --class $1 2>/dev/null | sort ) \
        <( xdotool search             --class $1 2>/dev/null | sort ) \
    | sort -n
}
ManageHeadsetWindows ()
{
    [[ $# -eq 2 ]] || return 1
    xdotool \
        windowunmap --sync ${@: -1} \
        windowactivate $1
}

# MAIN
{ sleep 5 ; ManageHeadsetWindows $( GetWindowIdsByClass headset ) ; } &
/usr/bin/headset
EOF
}



app::Gradio ()
{
    Meta --desc "Online radio player"

    # DEAD PPA, flatpak & snap break themes
    # apt::AddPpaPackages haecker-felix/gradio-daily gradio

    apt::AddRemotePackages \
        "http://download.opensuse.org/repositories/home:/stevepassert/Debian_8.0/amd64/gradio_5.0-1~obs_amd64.deb"

    gui::AddAppFolder Entertainment de.haeckerfelix.gradio
    gui::SetAppIcon de.haeckerfelix.gradio.desktop gradio

    # CONF
    sys::Write <<EOF /usr/share/glib-2.0/schemas/$PRODUCT_NAME-gradio.gschema.override
[de.haecker-felix.gradio]
show-notifications=true
EOF

}



app::Clementine ()
{
    Meta --desc "Music collection"

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages me-davidsansome/clementine clementine
    else
        apt::AddPackages clementine
    fi

    gui::AddAppFolder Entertainment clementine

    # CONF: Disable internet providers
    sys::Write --append <<'EOF' "$HOME/.config/Clementine/Clementine.conf" 1000:1000
[InternetModel]
Box=false
ClassicalRadio=false
DigitallyImported=false
Dropbox=false
Google%20Drive=false
Icecast=false
Intergalactic%20FM=false
Jamendo=false
JazzRadio=false
Magnatune=false
OneDrive=false
Podcasts=false
RadioTunes=false
RockRadio=false
Seafile=false
SomaFM=false
SoundCloud=false
Spotify=false
Subsonic=false
SavedRadio=true

[GlobalSearch]
enabled_library=true
enabled_classicalradio=false
enabled_di=false
enabled_icecast=false
enabled_intergalacticfm=false
enabled_jamendo=false
enabled_jazzradio=false
enabled_magnatune=false
enabled_radiotunes=false
enabled_rockradio=false
enabled_savedradio=true
enabled_somafm=false
enabled_soundcloud=false
enabled_subsonic=false
show_providers=false

[MainWindow]
showtray=false
keeprunning=false
EOF


    # THEMING: tabbar layout
    sys::Write --append <<'EOF' "$HOME/.config/Clementine/Clementine.conf" 1000:1000

[MainWindow]
tab_mode=4
EOF

    # THEMING: toolbar icons
    local tempdir=$( mktemp -d )
    net::Download "https://github.com/narunlifescience/Clementine-Custom-Icon-Sets/archive/master.zip" \
        $tempdir/master.zip
    unzip $tempdir/master.zip "Clementine-Custom-Icon-Sets-master/FaenzaDark/*" -d "$tempdir"
    sys::Chk
    sys::Copy --rename "$tempdir/Clementine-Custom-Icon-Sets-master/FaenzaDark/" \
        "$HOME/.config/Clementine/customiconset/" 1000:1000
    rm -rf "$tempdir"

}



app::Freetuxtv ()
{
    Meta --desc "TV player" \
         --no-default true

    apt::AddPpaPackages freetuxtv/freetuxtv freetuxtv
    gui::AddAppFolder Entertainment freetuxtv

    # OLD
    # if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
    #     apt::AddPpaPackages freetuxtv/freetuxtv-dev freetuxtv
    # else
    #     # BUG BIONIC libcurl3/4 conflict
    #     # apt::AddPpaPackages --release xenial freetuxtv/freetuxtv-dev freetuxtv # libcurl issue
    #     # WORKAROUND => BUILD :(
    #     local freetuxtv_build_deps="intltool libgtk2.0-dev libgtk-3-dev
    #         libvlc-dev libnotify-dev libdbus-glib-1-dev"
    #     apt::AddPackages $freetuxtv_build_deps libcurl3-dev libpng-dev
    #     local tmpdir=$( mktemp -d )
    #     net::DownloadGithubLatestRelease freetuxtv/freetuxtv \
    #         '/freetuxtv-.*\\.tar\\.gz$' \
    #         "$tmpdir/freetuxtv.tgz"
    #     pushd "$tmpdir"
    #     tar xzvf freetuxtv.tgz
    #     sys::Chk
    #     pushd freetuxtv-*
    #     ./configure --prefix=/usr/local
    #     make install
    #     popd ; popd
    #     rm -rf "$tmpdir"
    #     apt::RemovePackages $freetuxtv_build_deps
    # fi
    # gui::AddAppFolder Entertainment freetuxtv
}



app::Kodi ()
{
    Meta --desc "Media center" \
         --no-default true

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages team-xbmc/ppa kodi libcrossguid1 libshairplay0 libp8-platform2 libcec4
    else
        apt::AddPackages kodi kodi-repository-kodi
    fi

    gui::AddAppFolder Entertainment kodi

    mv /usr/share/xsessions/kodi.desktop{,.ORIG}

    RegisterPostInstall post::Kodi 80
}



post::Kodi ()
{
    # Create profile
    ulimit -c 0
    gui::XvfbRunKill 10 kodi

       [[ -f "$HOME/.kodi/userdata/Database/Addons27.db" ]] \
    || sys::Die "Kodi profile creation failed"

    # sleep 30
    rm -v "$HOME/kodi_crashlog-"* # "$HOME/core"

    # CONF: enable unknown sources
    sys::XmlstarletInline \
        "$HOME/.kodi/userdata/guisettings.xml" \
        --update '/settings/addons/unknownsources' \
        --value "true" \
        --delete '/settings/addons/unknownsources/@default'


#     # SOURCES
#     sys::Write <<'EOF' "$HOME/.kodi/userdata/sources.xml"
# <sources>
#     <files>
#         <default pathversion="1"></default>
#         <source>
#             <name>fusion.tvaddons.co</name>
#             <path pathversion="1">http://fusion.tvaddons.co/</path>
#             <allowsharing>true</allowsharing>
#         </source>
#         <source>
#             <name>lazykodi.com</name>
#             <path pathversion="1">https://lazykodi.com/</path>
#             <allowsharing>true</allowsharing>
#         </source>
#        <source>
#            <name>archive.org/download/repository.xvbmc</name>
#            <path pathversion="1">http://archive.org/download/repository.xvbmc/</path>
#            <allowsharing>true</allowsharing>
#        </source>
#        <source>
#            <name>kodil.co</name>
#            <path pathversion="1">http://kodil.co/repo/</path>
#            <allowsharing>true</allowsharing>
#        </source>
#     </files>
# </sources>
# EOF


    # DEP: sqlite3
    which sqlite3 &>/dev/null || apt::AddPackages sqlite3

    # # REPO: xbmchub
    # net::DownloadUnzip \
    #     "https://github.com/tvaddonsco/tva-release-repo/raw/master/repository.xbmchub/repository.xbmchub-3.0.0.zip" \
    #     "$HOME/.kodi/addons/"
    # sqlite3 "$HOME/.kodi/userdata/Database/Addons27.db" \
    #     <<<"INSERT INTO installed(addonID, enabled) VALUES ('repository.xbmchub',1);"
    # sys::Chk

    # # REPO: kodil
    # net::DownloadUnzip \
    #     "https://github.com/kodil/kodil/raw/master/repo/repository.kodil/repository.kodil-1.3.zip" \
    #     "$HOME/.kodi/addons/"
    # sqlite3 "$HOME/.kodi/userdata/Database/Addons27.db" \
    #     <<<"INSERT INTO installed(addonID, enabled) VALUES ('repository.kodil',1);"
    # sys::Chk

    # # REPO: cherrytv
    # net::DownloadUnzip \
    #     "https://github.com/CherryKodi/CHERRY/raw/master/zips/repository.cherrytv/repository.cherrytv-1.3.6.zip" \
    #     "$HOME/.kodi/addons/"
    # sqlite3 "$HOME/.kodi/userdata/Database/Addons27.db" \
    #     <<<"INSERT INTO installed(addonID, enabled) VALUES ('repository.cherrytv',1);"
    # sys::Chk


    # REPO: exodus redux
    # ALT https://i-a-c.github.io/repo/repository.exodusredux-0.0.7.zip
    net::DownloadUnzip \
        "http://lazykodi.com/-=%20REPOSITORIES%20%20=-/EXODUSREDUX/repository.exodusredux-0.0.8.zip" \
        "$HOME/.kodi/addons/"
    sqlite3 "$HOME/.kodi/userdata/Database/Addons27.db" \
        <<<"INSERT INTO installed(addonID, enabled) VALUES ('repository.exodusredux',1);"
    sys::Chk

    # SERVICE: opensubtitles
    net::DownloadUnzip \
        "https://github.com/tvaddonsco/tva-release-repo/raw/master/service.subtitles.opensubtitles_by_opensubtitles/service.subtitles.opensubtitles_by_opensubtitles-5.2.14.zip" \
        "$HOME/.kodi/addons/"
    sqlite3 "$HOME/.kodi/userdata/Database/Addons27.db" \
        <<<"INSERT INTO installed(addonID, enabled) VALUES ('service.subtitles.opensubtitles_by_opensubtitles',1);"
    sys::Chk

    rm -f "$HOME/kodi_crashlog*"
    chown -hR 1000:1000 "$HOME/.kodi/"

}



app::PopCornTime ()
{
    Meta --desc "Torrent video player" \
         --no-default true

    mkdir /opt/Popcorn-Time
    local tempxz=$( mktemp )

# BUG cacert: LE cert expired
    net::Download  --opts "-k" \
        "https://mirror02.popcorntime.sh/build/Popcorn-Time-0.3.10-Linux-64.tar.xz" \
        $tempxz
        # "https://get.popcorntime.sh/repo/build/Popcorn-Time-0.3.10-Linux-64.tar.xz" \
    tar --directory /opt/Popcorn-Time -xJf $tempxz
    chown -hR 0:0 /opt/Popcorn-Time

    sys::Write <<'EOF' /usr/share/applications/popcorntime.desktop
[Desktop Entry]
StartupWMClass=crx_hecfofbbdfadifpemejbbdcjmfmboohj
Encoding=UTF-8
Type=Application
Name=Popcorn Time
Exec=/opt/Popcorn-Time/Popcorn-Time
Icon=popcorntime
Terminal=false
StartupNotify=true
EOF

    # gui::AddFavoriteApp popcorntime
    gui::AddAppFolder Entertainment popcorntime
}
