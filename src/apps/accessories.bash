########
# FUNC #  BUNDLES::ACCESSORIES
########



PACKAGES_ACCESSORIES="
    app::Nautilus
    app::Hachoir
    app::Mat
    app::Calculator
    app::Clocks
    app::Gcolor
    app::Gtkhash
    app::Kazam
    app::Peek
    "



app::Mat ()
{
    Meta --desc "Metadata editor"

    apt::AddPackages mat gir1.2-poppler-0.18 libimage-exiftool-perl

    gui::HideApps mat

    # NACT
    local actions=/usr/share/gnome/file-manager/actions
    sys::Write <<EOF $actions/anonymize.desktop
[Desktop Entry]
Type=Action
Name=Anonymize
Icon=gcleaner
TargetLocation=true
Profiles=profile-zero;

[X-Action-Profile profile-zero]
Name=default
Exec=mat-gui %F
MimeTypes=$( python <<<'import libmat.mat ; print(  ";".join( [item for sublist in [ i["mimetype"].split(", ") for i in libmat.mat.list_supported_formats() ] for item in sublist] )  )' )
EOF

# TIP: get all supported mimetypes
# MimeTypes=$( python <<'EOS'
# import libmat.mat
# print(  ";".join( [item for sublist in [ i["mimetype"].split(", ") for i in libmat.mat.list_supported_formats() ] for item in sublist] )  )
# EOS

    # Disable nautilys-python extension
    mv        /usr/share/nautilus-python/extensions/nautilus-mat.py{,.ORIG}
    touch     /usr/share/nautilus-python/extensions/nautilus-mat.py
    chmod 444 /usr/share/nautilus-python/extensions/nautilus-mat.py
}



app::Hachoir ()
{
    Meta --no-default true \
         --desc "Binary stream viewer"

    apt::AddPackages python-hachoir-wx python-hachoir-urwid python-hachoir-metadata

    # NACT
    local actions=/usr/share/gnome/file-manager/actions
    [[ -d "$actions" ]] || return

    # NACT: Expert > Meta
    sys::Write <<'EOF' $actions/expert_meta.desktop
[Desktop Entry]
Type=Action
Name=Meta
Icon=nautilus
TargetLocation=true
Profiles=profile-zero;

[X-Action-Profile profile-zero]
Name=Default profile
Exec=hachoir-metadata-qt %F
MimeTypes=all/allfiles;
EOF
    # Expert > Stream
    sys::Write <<'EOF' $actions/expert_stream.desktop
[Desktop Entry]
Type=Action
Name=Stream
Icon=nautilus
TargetLocation=true
Profiles=profile-zero;

[X-Action-Profile profile-zero]
Name=Default profile
Exec=/usr/bin/hachoir-wx %f
MimeTypes=all/allfiles;
EOF
}



app::Calculator ()
{
    Meta --desc "Calculator"

    apt::AddPackages gnome-calculator
    gui::AddAppFolder Accessories gnome-calculator
    gui::AddAppFolder Accessories org.gnome.Calculator # BIONIC

}



app::Clocks ()
{
    Meta --desc "Time tools"

    apt::AddPackages gnome-clocks # DEV: Pulls dbus service geoclue-2.0
    gui::AddAppFolder Accessories org.gnome.clocks
    gui::DisableSearchProvider org.gnome.clocks
    sys::Write <<'EOF' /usr/share/glib-2.0/schemas/$PRODUCT_NAME-gnome-clocks.gschema.override
[org.gnome.clocks]
world-clocks=[{'location': <(uint32 2, <('San Francisco', 'KSFO', true, [(0.65658801258494626, -2.1356672871875406)], [(0.659296885757089, -2.1366218601153339)])>)>}, {'location': <(uint32 2, <('New York', 'KNYC', true, [(0.71180344078725644, -1.2909618758762367)], [(0.71059804659265924, -1.2916478949920254)])>)>}, {'location': <(uint32 2, <('London', 'EGLL', true, [(0.89855367075064974, -0.0078539816339744835)], [(0.89884456477707964, -0.0020362232784242244)])>)>}, {'location': <(uint32 2, <('Paris', 'LFPB', true, [(0.85462956287765413, 0.042760566673861078)], [(0.8528842336256599, 0.040724343395436846)])>)>}, {'location': <(uint32 2, <('Moscow', 'UUWW', true, [(0.97127572873484425, 0.65042604039431762)], [(0.97305983920281813, 0.65651530216830811)])>)>}, {'location': <(uint32 2, <('Hong Kong', 'VHHH', false, [(0.39009203103514262, 1.9929027420584826)], [(0.38979019379430269, 1.9928751117510946)])>)>}, {'location': <(uint32 2, <('Tokyo', 'RJTI', true, [(0.62191898430954862, 2.4408429589140699)], [(0.62282074357417661, 2.4391218722853854)])>)>}, {'location': <(uint32 2, <('Sydney', 'YSSY', true, [(-0.59253928105207498, 2.6386469349889961)], [(-0.59137572239964786, 2.6392287230418559)])>)>}]
EOF
    glib-compile-schemas /usr/share/glib-2.0/schemas/
}



app::Gcolor ()
{
    Meta --desc "Color picker"

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages varlesh-l/ubuntu-tools gcolor3
    else
        # BIONIC unavailable
        apt::AddPpaPackages --release xenial varlesh-l/ubuntu-tools gcolor3
    fi
    gui::AddAppFolder Accessories gcolor3

}



app::Gtkhash ()
{
    Meta --no-default true \
         --desc "Digest viewer"

    apt::AddPackages gtkhash
    gui::AddAppFolder Accessories gtkhash

    # NACT
    local actions=/usr/share/gnome/file-manager/actions
    [[ -d "$actions" ]] || return

    # NACT: Expert > Meta
    sys::Write <<'EOF' $actions/expert_hash.desktop
[Desktop Entry]
Type=Action
Name=Hash
Icon=nautilus
TargetLocation=true
Profiles=profile-zero;

[X-Action-Profile profile-zero]
Name=Default profile
Exec=gtkhash %F
MimeTypes=all/allfiles;
EOF
}



app::Peek ()
{
    Meta --desc "GIF Screencaster"

    # gifski
    local tempdir=$( mktemp -d )
    net::DownloadGithubLatestRelease ImageOptim/gifski '/gifski-.*\\.tar\\.xz$' "$tempdir/gifski.zip"
    tar --directory "$tempdir" -xJf "$tempdir/gifski.zip"
    sys::Chk
    apt::AddLocalPackages $tempdir/linux/gifski_*_amd64.deb
    rm -rf "$tempdir"

    # peek
    apt::AddPpaPackages peek-developers/stable peek
    gui::AddAppFolder Accessories com.uploadedlobster.peek

    # CONF
    sys::Write <<'EOF' /usr/share/glib-2.0/schemas/$PRODUCT_NAME-peek.gschema.override
[com.uploadedlobster.peek]
recording-gifski-enabled=true
recording-gifski-quality=100
EOF
}



app::Kazam ()
{
    Meta --desc "Screencaster"

    apt::AddPackages kazam
    gui::AddAppFolder Accessories kazam
    sys::Write <<EOF $HOME/.config/kazam/kazam.conf 1000:1000
[main]
autosave_picture = False
autosave_video = False
autosave_video_file = screencast
autosave_picture_file = screenshot
autosave_picture_dir = $HOME
autosave_video_dir = $HOME
audio_volume = 0
audio2_volume = 0
audio2_toggled = False
capture_microphone = False
capture_speakers = False
codec = 2
first_run = True
EOF
# DEV codec = 2 uses HUFFYUV encoding, preserving color space

    # Screenkey
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages nilarimogard/webupd8 screenkey
    else
        apt::AddPackages screenkey
    fi
    gui::AddAppFolder Accessories screenkey
    sys::Write <<EOF $HOME/.config/screenkey.json 1000:1000
{
    "bak_mode": "baked",
    "bg_color": "#$THEME_COLOR_OBJECT_HEX",
    "compr_cnt": 3,
    "font_color": "#$THEME_COLOR_HOTHOT_HEX",
    "font_desc": "Sans Bold",
    "font_size": "small",
    "geometry": null,
    "ignore": [],
    "key_mode": "composed",
    "mods_mode": "normal",
    "mods_only": false,
    "multiline": false,
    "no_systray": true,
    "opacity": 0.8,
    "persist": false,
    "position": "bottom",
    "recent_thr": 0.1,
    "screen": 0,
    "timeout": 2.5,
    "vis_shift": false,
    "vis_space": true
}
EOF

    # ycDMZ: cursor theme
      net::DownloadUntarGzip \
        "https://distribute.kde.org/khotnewstuff/mousethemes/downloads/157167-ycDMZ.tar.gz" \
        /usr/share/icons
    sys::Chk
    chown -hR 0:0 /usr/share/icons/ycDMZ

    # Demo switch
    gui::AddSwitch demo \
        'gsettings get org.gnome.desktop.interface cursor-theme | grep ycDMZ' \
        'bash -c \"gsettings set org.gnome.desktop.interface cursor-theme ycDMZ ; pgrep screenkey || screenkey\"' \
        'bash -c \"gsettings set org.gnome.desktop.interface cursor-theme '"$THEME_CURSOR"' ; pkill screenkey\"' \
        0
}



app::Nautilus ()
{
    Meta --desc "File manager"

    apt::AddPpaPackages lubomir-brindza/nautilus-typeahead nautilus

    [[ "$UBUNTU_RELEASE" == "xenial" ]] || apt::AddPackages libgdk-pixbuf2.0-bin

    # gui::AddFavoriteApp nautilus
    gui::DisableSearchProvider org.gnome.Nautilus

    gui::AddKeybinding file-manager "<Super>f" \
        'bash -c "f=0 ; for i in $( xdotool search -maxdepth 1 --class nautilus ) ; do r=$( xdotool windowactivate $i 2>&1) ; [[ ${#r} -eq 0 ]] && f=1 && break ; done ; [[ $f -eq 0 ]] && /usr/local/bin/gnos-sugar Nohup nautilus"'
    gui::AddKeybinding file-manager-new "<Shift><Super>f" "nautilus --new-window"
    gui::AddKeybinding file-manager-root "<Primary><Super>f" 'bash -c "pkexec nautilus; sleep 2"'

    gui::SetDefaultAppForMimetypes file-roller application/vnd.ms-cab-compressed


    # CONF
    sys::Write <<'EOF' /usr/share/glib-2.0/schemas/$PRODUCT_NAME-nautilus.gschema.override
[org.gnome.nautilus.desktop]
home-icon-visible=false
network-icon-visible=false
trash-icon-visible=false
volumes-visible=false

[org.gnome.nautilus.icon-view]
default-zoom-level='standard'

[org.gnome.nautilus.list-view]
default-zoom-level='small'
default-visible-columns=['name', 'size', 'type', 'date_modified', 'owner' ]
use-tree-view=true

[org.gnome.nautilus.preferences]
show-hidden-files=true
executable-text-activation='ask'
default-folder-viewer='list-view'
search-view='list-view'
EOF

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        sys::Write --append <<'EOF' /usr/share/glib-2.0/schemas/$PRODUCT_NAME-nautilus.gschema.override
enable-interactive-search=true
sort-directories-first=true
EOF
    fi


    # THEMING: NO thumbnail_frame, NO filmholes
    # DOC: https://developer.gnome.org/gio/stable/GResource.html
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        # REQUIRES GLib >2.50
        apt::AddPpaPackages ubuntu-desktop/gnome-3-24 libglib2.0-0 libglib2.0-bin libglib2.0-data libglib2.0-dev
    fi
    local png=/usr/local/share/icons/nautilus/transparent.png
    sys::Touch "$png"
    base64 -d >"$png" \
      <<<"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="
    sys::Chk
    sys::Write <<EOF /etc/X11/Xsession.d/90nautilus 0:0 644
G_RESOURCE_OVERLAYS=/org/gnome/nautilus/icons/thumbnail_frame.png=$png:/org/gnome/nautilus/icons/filmholes.png=$png
export G_RESOURCE_OVERLAYS
EOF


    # FIX thumbnailers https://askubuntu.com/a/1103015
    apt::AddPackages bubblewrap
    sys::Write <<'EOF' /usr/local/bin/bwrap 0:0 755
#!/bin/bash
# DESC  bwrap wrapper to correct nautilus 3.26.4+ bug for external thumbnailers under debian based distros
# CRED  https://github.com/NicolasBernaerts

if [[ "$( ps -p $PPID -o comm= )" == nautilus ]] ; then

    [[ "${@: -1}" == 256 ]] && cnt=$(($#-2)) || cnt=$(($#-1))
    arg=${!cnt}
    arg=${arg#file://}

    if [[ $arg == /tmp/gnome-desktop-file-to-thumbnail.* ]] ; then

        # FROM https://github.com/NicolasBernaerts/ubuntu-scripts/blob/master/nautilus/bwrap

        # intialise parameters array
        ARR_PARAM=( )

        # add both --ro-bind needed by thumbnailers using imagemagick tools
        [ -d "/etc/alternatives" ] && ARR_PARAM=( "${ARR_PARAM[@]}" "--ro-bind" "/etc/alternatives" "/etc/alternatives" )
        [ -d "/var/cache/fontconfig" ] && ARR_PARAM=( "${ARR_PARAM[@]}" "--ro-bind" "/var/cache/fontconfig" "/var/cache/fontconfig" )

        # loop thru original parameters
        while test $# -gt 0 ; do
            case "$1" in
                "--symlink") # convert to --ro-bind
                    shift ; shift
                    ARR_PARAM=( "${ARR_PARAM[@]}" "--ro-bind" "$1" "$1" ) ;;
                *)   # add parameter
                    ARR_PARAM=( "${ARR_PARAM[@]}" "$1" ) ;;
            esac
            shift
        done

        # call original bwrap with patched args
        /usr/bin/bwrap "${ARR_PARAM[@]}"
        exit $?
    fi

fi

# call original bwrap with original args
exec /usr/bin/bwrap "$@"
EOF

    # gnome-raw-thumbnailer
    apt::AddPackages gnome-raw-thumbnailer

    # ffmpegthumbnailer
    apt::AddPackages ffmpegthumbnailer
    # sys::Move /usr/share/thumbnailers/ffmpegthumbnailer.thumbnailer{,.ORIG}
    mv /usr/share/thumbnailers/ffmpegthumbnailer.thumbnailer{,.ORIG}
    sys::Chk
    sys::Write <<'EOF' /usr/share/thumbnailers/ffmpeg.thumbnailer
[Thumbnailer Entry]
TryExec=/usr/bin/ffmpegthumbnailer
Exec=/usr/bin/ffmpegthumbnailer -s %s -i %i -o %o -c png -t 10
MimeType=video/flv;video/webm;video/mkv;video/mp4;video/mpeg;video/avi;video/ogg;video/quicktime;video/x-avi;video/x-flv;video/x-mp4;video/x-mpeg;video/x-webm;video/x-mkv;application/x-extension-webm;video/x-matroska;video/x-ms-wmv;video/x-msvideo;video/x-msvideo/avi;video/x-theora/ogg;video/x-theora/ogv;video/x-ms-asf;video/x-m4v;
EOF

    # imagemagick-pdf
    apt::AddPackages imagemagick-6.q16 ; gui::HideApps display-im6 display-im6.q16
    sys::Write <<'EOF' /usr/share/thumbnailers/imagemagick-pdf.thumbnailer
[Thumbnailer Entry]
TryExec=convert
Exec=convert -thumbnail %s -background white -alpha remove -brightness-contrast -30x0 %i[0] png:%o
MimeType=application/pdf;application/x-pdf;image/pdf;
EOF
    # FIX https://stackoverflow.com/a/52661288
    sys::SedInline 's#(rights=")none(" pattern="PDF")#\1read|write\2#' \
        /etc/ImageMagick-6/policy.xml


    # file-roller
    apt::AddPackages file-roller
    gui::SetAppName file-roller Archives
    gui::AddAppFolder Accessories org.gnome.Nautilus nautilus file-roller

    # DEV file-roller: prohibit --notify arg
    sys::Write <<'EOF' /usr/local/bin/file-roller 0:0 755
#!/bin/bash
# DESC file-roller: prohibit --notify arg

a=("$@")

for k in "${!a[@]}"; do
    [[ ${a[k]} == "--notify" ]] && unset 'a[k]'
done

exec /usr/bin/file-roller "${a[@]}"
EOF


    # SAMBA
    apt::AddPackages nautilus-share
    # DEV: pulls software-properties-gtk
    gui::HideApps software-properties-gtk software-properties-livepatch
    gui::AddAppFolder Settings software-properties-gtk


    # eiciel
    apt::AddPackages eiciel
    gui::HideApps eiciel
    gui::HideApps org.roger-ferrer.Eiciel # BIONIC


    # foldercolor  http://foldercolor.tuxfamily.org/
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages costales/folder-color \
            folder-color folder-color-common
    else
        apt::AddPpaPackages --priority 1000 costales/folder-color \
            folder-color folder-color-common
    fi
    mkdir -p $HOME/.config/folder-color/hide_donation
    chown -hR 1000:1000 $HOME/.config/folder-color


    # gloobus
    apt::AddPackages \
        libmagickcore-6.q16-2-extra ghostscript netpbm libpaper-utils # unoconv
    gui::HideApps display-im6 display-im6.q16
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages nilarimogard/webupd8 gloobus-preview gloobus-sushi
    else
        # BIONIC: unavailable
        apt::AddPpaPackages --release xenial nilarimogard/webupd8 gloobus-preview gloobus-sushi
    fi
    # DEV: does NOT support Gimp XCF 11 format
    # https://gitlab.gnome.org/GNOME/gimp/blob/master/devel-docs/xcf.txt
    sys::Write <<'EOF' $HOME/.config/gloobus/gloobus-preview.cfg 1000:1000
[Main]
taskbar = 1
ontop = 1
focus = 1
winbar_layout = 1

[Theme]
gtk = 1
EOF
    mkdir -p {/etc/skel,/root}/.config/gloobus
    cp {$HOME,/etc/skel}/.config/gloobus/gloobus-preview.cfg
    cp {$HOME,/root}/.config/gloobus/gloobus-preview.cfg

    # markdown mimetype in gtksourceview
    sed -i -E 's#(<property name="mimetypes">text/x-markdown)#\1;text/markdown#' \
        /usr/share/gtksourceview-3.0/language-specs/markdown.lang

    # nautilus-git
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages khurshid-alam/nautilus-git nautilus-git
    else
        # BIONIC: unavailable
        apt::AddPpaPackages --release xenial khurshid-alam/nautilus-git nautilus-git
    fi


    ## Nautilus actions
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then

        apt::AddPackages nautilus-actions
        # gui::AddAppFolder Settings nact
        # gui::SetAppIcon nact preferences-system-windows-actions
        gui::HideApps nact

        sys::Write <<'EOF' $HOME/.config/nautilus-actions/nautilus-actions.conf 1000:1000
[runtime]
items-level-zero-order=root_menu;expert_menu;$( str::InList app::Konsole $INSTALL_BUNDLES && echo "term;" )$( str::InList app::SublimeText_NONFREE $INSTALL_BUNDLES && echo "edit_text;" )
items-list-order-mode=ManualOrder

items-create-root-menu=false
items-add-about-item=false
terminal-pattern=
desktop-environment=

[nact]
main-toolbar-file-display=true
main-toolbar-edit-display=true
main-toolbar-help-display=true
relabel-when-duplicate-menu=false
relabel-when-duplicate-action=false
relabel-when-duplicate-profile=false
assistant-esc-quit=true
assistant-esc-confirm=true
main-save-auto=false
main-save-period=5
import-preferred-mode=Ask
export-preferred-format=Ask
scheme-default-list=dav|WebDAV files;file|Local files;ftp|FTP files;sftp|SSH files;smb|Windows files;
io-providers-write-order=na-desktop;
preferences-wsp=140;140;745;421;

[io-provider na-desktop]
readable=true
writable=true
EOF

    # SKEL
    cp -R $HOME/.config/nautilus-actions /etc/skel/.config/

    else

        apt::AddPpaPackages daniel-marynicz/filemanager-actions filemanager-actions-nautilus-extension
        # gui::SetAppName fma-config-tool "Files Actions"
        # gui::AddAppFolder Settings fma-config-tool
        gui::HideApps fma-config-tool

        sys::Write <<'EOF' $HOME/.config/filemanager-actions/filemanager-actions.conf 1000:1000
[runtime]
items-create-root-menu=false
items-add-about-item=false
items-level-zero-order=root_menu;expert_menu;$( str::InList app::Konsole $INSTALL_BUNDLES && echo "term;" )$( str::InList app::SublimeText_NONFREE $INSTALL_BUNDLES && echo "edit_text;" )

[fma-config-tool]
main-tabs-pos=Left
EOF

    fi


    # NACT Helpers

    local actions=/usr/share/gnome/file-manager/actions
# UNUSED
#     sys::Write <<'EOF' "$NACT_HELPER_RUN_ALL"
# #!/bin/bash
# declare -a cmd
# while [[ "$1" != '--' ]] ; do
#     cmd+=("$1")
#     shift
# done
# shift
# while [[ "$#" -ne 0 ]] ; do
#     url_encoded="${1//+/ }"
#     url_encoded="$( printf '%b' "${url_encoded//%/\\x}" )"
#     args+=("${url_encoded#file://}")
#     shift
# done
# "${cmd[@]}" "${args[@]}"
# EOF

    # WORKAROUND NACT BUG: %f breaks filenames with spaces in quoted commands
    sys::Write <<'EOF' "$NACT_HELPER_GET_ONE" 0:0 755
#!/bin/bash
[[ "$#" -ne 1 ]] && return
url_encoded="${1//+/ }"
url_encoded="$( printf '%b' "${url_encoded//%/\\x}" )"
echo "${url_encoded#file://}"
EOF

    # Term
    if str::InList app::Konsole $INSTALL_BUNDLES ; then
        sys::Write <<EOF $actions/term.desktop
[Desktop Entry]
Type=Action
Name=Term
Icon=konsole
TargetLocation=true
Profiles=profile-zero;

[X-Action-Profile profile-zero]
Name=default
Exec=bash -c 'o="\$( '"$NACT_HELPER_GET_ONE"' %U )" ; gnome-terminal --working-directory "\$( [[ -d "\$o" ]] && echo "\$o" || dirname "\$o" )"'
MimeTypes=inode/directory;
SelectionCount==1
EOF
    fi

    # Edit text
    if str::InList app::SublimeText_NONFREE $INSTALL_BUNDLES ; then
        sys::Write <<EOF $actions/edit_text.desktop
[Desktop Entry]
Type=Action
Name=Edit text
Icon=sublimetext
TargetLocation=true
Profiles=profile-zero;

[X-Action-Profile profile-zero]
Name=default
Exec=subl %F
EOF
    fi


    # Root menu
    sys::Write <<EOF $actions/root_menu.desktop
[Desktop Entry]
Type=Menu
Name=root
Icon=selinux
ItemsList=root_open;$( str::InList app::Konsole $INSTALL_BUNDLES && echo "root_term;" )$( str::InList app::SublimeText_NONFREE $INSTALL_BUNDLES && echo "root_edit_text;" )
EOF
# ;root_perm

    # Root > Open
    sys::Write <<EOF $actions/root_open.desktop
[Desktop Entry]
Type=Action
Name=Open
Icon=nautilus
TargetLocation=true
Profiles=profile-zero;

[X-Action-Profile profile-zero]
Name=default
Exec=/usr/bin/pkexec nautilus %F
MimeTypes=inode/directory;
EOF

    if str::InList app::Konsole $INSTALL_BUNDLES ; then

        sys::Write <<EOF $actions/root_term.desktop
[Desktop Entry]
Type=Action
Name=Term
Icon=konsole
TargetLocation=true
Profiles=profile-zero;

[X-Action-Profile profile-zero]
Name=default
Exec=bash -c 'o="\$( '"$NACT_HELPER_GET_ONE"' %U )" ; gnome-terminal --working-directory "\$( [[ -d "\$o" ]] && echo "\$o" || dirname "\$o" )" --profile bash:ROOT@local'
MimeTypes=inode/directory;
SelectionCount==1
EOF
    fi

    # Root > Edit text
    if str::InList app::SublimeText_NONFREE $INSTALL_BUNDLES ; then
        sys::Write <<EOF $actions/root_edit_text.desktop
[Desktop Entry]
Type=Action
TargetLocation=true
Icon=sublimetext
Name=Edit
Profiles=profile-zero;

[X-Action-Profile profile-zero]
Name=default
Exec=/usr/bin/pkexec subl -- %F
EOF
    fi

#     # Root > Perms
#     sys::Write <<EOF $actions/root_perm.desktop
# [Desktop Entry]
# Type=Action
# Name=Perms
# Icon=configure
# TargetLocation=true
# Profiles=profile-zero;

# [X-Action-Profile profile-zero]
# Name=default
# Exec=/usr/bin/pkexec eiciel %F
# SelectionCount==1
# EOF

    # Expert menu
    sys::Write <<'EOF' $actions/expert_menu.desktop
[Desktop Entry]
Type=Menu
Name=expert
Icon=angrysearch
ItemsList=expert_info;expert_meta;expert_stream;expert_binary;expert_hash;
EOF

    # Expert > Info
    sys::Write <<EOF $actions/expert_info.desktop
[Desktop Entry]
Type=Action
Name=Info
Icon=nautilus
TargetLocation=true
Profiles=profile-zero;

[X-Action-Profile profile-zero]
Name=default
Exec=/usr/local/bin/o i -v %F
MimeTypes=all/allfiles;
EOF

    # pkexec nautilus
    gui::AddPkexecPolicy \
        /usr/bin/nautilus \
        org.gnome.nautilus

    # pkexec eiciel
    gui::AddPkexecPolicy \
        /usr/bin/eiciel \
        org.roger-ferrer.rofi.eiciel

}
