########
# FUNC #  BUNDLES::GRAPHICS
########



PACKAGES_GRAPHICS="
    app::Darktable
    app::Digikam
    app::Gimp
    app::Inkscape
    app::Scribus
    app::Gthumb
    app::Pencil
    app::Fontmanager
    app::Birdfont
    app::Typecatcher
    app::Sweethome3d
    "
    # app::Freecad



app::Pencil ()
{
    Meta --no-default true \
         --desc "Mockup editor"

    # DEV: NO BINARY releases on github "https://github.com/evolus/pencil"
    # DEV: SLOW/BUGGY    "http://pencil.evolus.vn/dl/V3.0.4/Pencil_3.0.4_amd64.deb"
    apt::AddRemotePackages \
        "https://mirror.sobukus.de/files/grimoire/bin-graphics/Pencil_3.0.4_amd64.deb"

    gui::AddAppFolder Graphics pencil

    apt::AddPackages fonts-cantarell # Gnome 3 Widgets
}



app::Sweethome3d ()
{
    Meta --no-default true \
         --desc "3D interior design"

    local vers="6.1.2"

    net::DownloadUntarGzip \
        "https://sourceforge.net/projects/sweethome3d/files/SweetHome3D/SweetHome3D-$vers/SweetHome3D-$vers-linux-x64.tgz/download" \
        /opt/

    # TODO Detect path
    local path=/opt/SweetHome3D-$vers
    [[ -d "$path" ]] || sys::Die "Failed to download SweetHome3D"

    sys::Write <<EOF /usr/local/share/applications/sweethome3d.desktop
[Desktop Entry]
Type=Application
Terminal=false
Name=SweetHome3D
Exec=$path/SweetHome3D
Icon=sweethome3d
EOF

    gui::AddAppFolder Graphics sweethome3d
}



app::Freecad ()
{
    Meta --desc "3D parametric modeler" \
         --no-default true

    apt::AddPpaPackages freecad-maintainers/freecad-stable freecad
    gui::AddAppFolder Graphics freecad


    # TODO XML Configure $HOME/.FreeCAD/user.cfg
        # <?xml version="1.0" encoding="UTF-8" standalone="no" ?>
        # <FCParameters>
        #   <FCParamGroup Name="Root">
        #     <FCParamGroup Name="BaseApp">
        #       <FCParamGroup Name="Preferences">
    # Background
        #           <FCParamGroup Name="View">
    # Editor font
        #           <FCParamGroup Name="Editor">
        #                 <FCInt Name="FontSize" Value="13"/>
        #                 <FCText Name="Font">Hack</FCText>
}



app::Digikam ()
{
    Meta --desc "Photo collection"

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages philip5/extra \
            digikam5 digikam5-data digikam-data \
            libqtav libqtavwidgets \
            libkf5kipi32.0.0 libkf5kipi-data libkf5ksane5 \
            liblensfun-data-v1 liblensfun1
    else
        apt::AddPackages digikam
    fi
    gui::AddAppFolder Graphics org.kde.digikam

    # welcomepage
    mv /usr/share/digikam/about{,.ORIG}
}



app::Fontmanager ()
{
    Meta --desc "Font manager"

    apt::AddPackages font-manager
    # XENIAL
    gui::AddAppFolder Graphics font-manager
    gui::HideApps font-viewer
    # BIONIC
    gui::AddAppFolder Graphics org.gnome.FontManager
    gui::HideApps org.gnome.FontViewer
}



app::Typecatcher ()
{
    Meta --desc "Online font installer"

    apt::AddPackages typecatcher

    gui::AddAppFolder Graphics typecatcher
}



app::Birdfont ()
{
    Meta --no-default true \
        --desc "Font editor"

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages birdfont-team/birdfont birdfont
    else
        apt::AddPackages birdfont
    fi

    gui::AddAppFolder Graphics birdfont
}



app::Darktable ()
{
    Meta --no-default true \
         --desc "Raw editor"

    apt::AddPpaPackages pmjdebruijn/darktable-release darktable
    gui::AddAppFolder Graphics darktable
}



app::Scribus ()
{
    Meta --desc "Desktop publishing"
    
    apt::AddPpaPackages scribus/ppa scribus-ng scribus-ng-data

    gui::SetAppName scribus-ng "Scribus"
    gui::AddAppFolder Graphics scribus-ng
}



app::Gimp ()
{
    Meta --desc "Bitmap editor"

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages otto-kesselgulasch/gimp \
            gimp libgimp2.0 gimp-data
            # gimp-plugin-registry
    else
        apt::AddPpaPackages otto-kesselgulasch/gimp \
            gimp libgimp2.0 gimp-data \
            mypaint-brushes libmypaint
    fi

    gui::AddAppFolder Graphics gimp
    gui::SetAppName gimp "Gimp"
    gui::SetAppProp gimp StartupWMClass "gimp-2.10"

    # MIME
    gui::SetDefaultAppForMimetypes gimp \
        image/photoshop \
        image/vnd.adobe.photoshop \
        image/x-photoshop \
        image/x-vnd.adobe.photoshop \
        image/x-psd \
        image/x-psp \
        image/x-adobe-dng

    gui::AddEditor /usr/share/applications/gimp.desktop \
        edit_bitmap \
        "Edit bitmap"


    # TOCHECK PLUGINS
    # gimp-beautify set of GIMP plug-ins for quickly and easily beautify photo
    # apt::AddPpaPackages varlesh-l/ubuntu-tools gimp-beautify
    # BIMP can apply a set of GIMP manipulations on groups of images
    # apt::AddPpaPackages varlesh-l/ubuntu-tools gimp-plugin-bimp


    local confTarget=$HOME/.config/GIMP/2.10

    sys::Write <<'EOF' $confTarget/contextrc 1000:1000 750
(tool "gimp-rect-select-tool")
EOF
# (palette "Default")
# (font "Sans")

    sys::Write <<EOF $confTarget/gimprc 1000:1000 750
(default-view
    (show-menubar yes)
    (show-statusbar yes)
    (show-rulers yes)
    (show-scrollbars yes)
    (show-selection yes)
    (show-layer-boundary yes)
    (show-guides yes)
    (show-grid no)
    (show-sample-points yes)
    (padding-mode custom)
    (padding-color (color-rgb $( # DEV: RGB/255 to RBG/1 conversion
        awk 'BEGIN{RS=","} {printf("%s%6f",s,$1/255);s=" "}' \
            <<< "$THEME_COLOR_BACKGD_RGB" \
        ))))
(theme "System")
EOF

    sys::Write <<'EOF' $confTarget/sessionrc 1000:1000 750
(session-info "toplevel"
    (factory-entry "gimp-single-image-window")
    (position 0 34)
    (size 1600 841)
    (open-on-exit)
    (aux-info
        (left-docks-width "72")
        (right-docks-width "228")
        (maximized "yes"))
    (gimp-toolbox
        (side left))
    (gimp-dock
        (side right)
        (book
            (current-page 0)
            (dockable "gimp-tool-options"
                (tab-style preview)
                (aux-info
                    (show-button-bar "true"))))
        (book
            (position 431)
            (current-page 3)
            (dockable "gimp-layer-list"
                (tab-style automatic)
                (preview-size 32)
                (aux-info
                    (show-button-bar "true")))
            (dockable "gimp-channel-list"
                (tab-style automatic)
                (preview-size 32)
                (aux-info
                    (show-button-bar "true")))
            (dockable "gimp-vectors-list"
                (tab-style automatic)
                (preview-size 32)
                (aux-info
                    (show-button-bar "true")))
            (dockable "gimp-undo-history"
                (tab-style automatic)
                (aux-info
                    (show-button-bar "true"))))))
(session-info "toplevel"
    (factory-entry "gimp-preferences-dialog")
    (position 313 69))

(hide-docks no)
(single-window-mode yes)
(last-tip-shown 0)
EOF

    # TOCHECK # PS SHORTCUTS FROM http://nuclearnapalm.com/2014/08/transform-gimp-photoshop/
    # local temprar=$( mktemp )
    # net::Download "http://nuclearnapalm.com/wp-content/uploads/2014/08/NuclearNapalm-DarkTheme.rar" $temprar
    # unrar e $temprar NuclearNapalm-DarkTheme/Hotkeys/ps-menurc $confTarget

    chown -hR 1000:1000 $confTarget


    # gnome-xcf-thumbnailer
    apt::AddPackages gnome-xcf-thumbnailer
    sys::Write <<'EOF' /usr/share/thumbnailers/gnome-xcf.thumbnailer
[Thumbnailer Entry]
TryExec=gnome-xcf-thumbnailer
Exec=gnome-xcf-thumbnailer %i %o
MimeType=image/x-xcf;image/x-compressed-xcf;
EOF

}



app::Gthumb ()
{
    Meta --desc "Universal image viewer"

    apt::AddPackages gthumb

    local name
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then name=gthumb
    else                                          name=org.gnome.gThumb
    fi

    gui::AddAppFolder Graphics $name

    # MIME
    gui::SetDefaultAppForMimetypes $name \
        image/bmp \
        image/gif \
        image/jpeg \
        image/jpg \
        image/png \
        image/svg+xml \
        image/svg+xml-compressed \
        image/tiff \
        image/x-bmp \
        image/x-ico \
        image/x-icon \
        image/xpm \
        image/x-png \
        image/x-tga

    # CONF
    sys::Write <<EOF /usr/share/glib-2.0/schemas/$PRODUCT_NAME-gthumb.gschema.override
# AUTO-GENERATED BY $FUNCNAME

[org.gnome.gthumb.browser]
thumbnail-caption='comment::note,comment::time,standard::display-name'

[org.gnome.gthumb.image-viewer]
zoom-change='fit-size'
EOF
    glib-compile-schemas /usr/share/glib-2.0/schemas/
}



app::Inkscape ()
{
    Meta --desc "Vector editor"

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages inkscape.dev/stable inkscape
    else
        apt::AddPackages inkscape
    fi
    gui::AddAppFolder Graphics inkscape
    gui::AddEditor /usr/share/applications/inkscape.desktop \
        edit_vector \
        "Edit vector"

    # Icon THEME http://ioverd.deviantart.com/art/Inkscape-0-91-dark-theme-547919927
    GetMediafireUrl () # $1:URL
    {
          net::Download "$1" \
        | awk -F '"' '/^ +href="http:\/\/download/{ print $2 }'
    }
    local tmpDir=$( mktemp -d )
    local link="http://www.mediafire.com/file/bunqu4bqt88bzqa/Inkscape+0.91+dark+theme.zip"
    local name="Set dark theme - for Inkscape 64-bit.exe"
    local path="share/icons/icons.svg"
    local dest="$HOME/.config/inkscape/icons"
    mkdir -p "$dest"
    local url=$( GetMediafireUrl "$link" )
    [[ -z "$url" ]] && sys::Die "Failed to get file from Mediafire: $link"
    net::DownloadUnzip "$url" "$tmpDir"
    7z e -y -r "$tmpDir/$name" "$path" -o"$tmpDir"
    sys::Chk
    sys::Copy "$tmpDir/$( basename "$path" )" "$dest/"
    chown -hR 1000:1000 "$HOME/.config/inkscape"
    rm -rf $tmpDir
}
