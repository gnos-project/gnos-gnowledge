########
# FUNC #  BUNDLES::OFFICE
########



PACKAGES_OFFICE="
    app::LibreOffice
    app::WpsOffice_NONFREE
    app::MasterPdf_NONFREE
    app::Okular
    app::Paperwork
    "



app::Paperwork ()
{
    Meta --no-default true \
         --desc "Document collection"

    # DEPS
    cli::Python

    apt::AddPackages python3-pil python3-whoosh libsane libenchant-dev

    # tesseract 3
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPackages tesseract-ocr
        [[ "$KEYBOARD_LAYOUT"  == "fr" ]] && apt::AddPackages tesseract-ocr-fra
    else
        # DEV https://gitlab.gnome.org/World/OpenPaperwork/paperwork/blob/master/doc/install.debian.markdown
        apt::AddPackages liblept5

        apt::AddRemotePackages \
            https://launchpad.net/ubuntu/+archive/primary/+files/tesseract-ocr_3.04.01-4_amd64.deb \
            https://launchpad.net/ubuntu/+archive/primary/+files/libicu55_55.1-7ubuntu0.4_amd64.deb \
            https://launchpad.net/ubuntu/+archive/primary/+files/libtesseract3_3.04.01-4_amd64.deb \
            https://launchpad.net/ubuntu/+archive/primary/+files/tesseract-ocr-eng_3.04.00-1_all.deb \
            https://launchpad.net/ubuntu/+archive/primary/+files/tesseract-ocr-equ_3.04.00-1_all.deb \
            https://launchpad.net/ubuntu/+archive/primary/+files/tesseract-ocr-osd_3.04.00-1_all.deb
        apt-mark hold \
            tesseract-ocr \
            libicu55 \
            libtesseract3 \
            tesseract-ocr-eng \
            tesseract-ocr-equ \
            tesseract-ocr-osd
        sys::Chk
        gui::AddAptIndicatorIgnore \
            tesseract-ocr \
            libicu55 \
            libtesseract3 \
            tesseract-ocr-eng \
            tesseract-ocr-equ \
            tesseract-ocr-osd

        if [[ "$KEYBOARD_LAYOUT"  == "fr" ]] ; then
            apt::AddRemotePackages \
                https://launchpad.net/ubuntu/+archive/primary/+files/tesseract-ocr-fra_3.04.00-1_all.deb
            apt-mark hold tesseract-ocr-fra
            gui::AddAptIndicatorIgnore tesseract-ocr-fra
        fi
    fi

    # TIP: manual deps check
    # paperwork-shell chkdeps paperwork_backend paperwork

    pip::Install paperwork

    # paperwork-shell install # DEV: oldschool icons
    sys::Write <<'EOF' /usr/local/share/applications/paperwork.desktop 1000:1000 750
[Desktop Entry]
Name=Paperwork
Exec=paperwork
Terminal=false
Type=Application
Icon=paperwork
EOF
    gui::AddAppFolder Office paperwork
}



app::WpsOffice_NONFREE ()
{
    Meta --no-default true \
         --desc "Office suite, MS-compatible"

    # DOC: http://wps-community.org/downloads
    apt::AddRemotePackages \
        http://kdl.cc.ksosoft.com/wps-community/download/8392/wps-office_11.1.0.8392_amd64.deb


    rm -rfv $HOME/Desktop/wps-office-* \
        $HOME/"模板" \
        /root/"模板"

    gui::SetAppIcon wps-office-wps wps-word
    gui::SetAppIcon wps-office-et  wps-calc
    gui::SetAppIcon wps-office-wpp wps-pres

    gui::SetAppProp wps-office-wps StartupWMClass wps
    gui::SetAppProp wps-office-et  StartupWMClass et
    gui::SetAppProp wps-office-wpp StartupWMClass wpp

    gui::AddAppFolder Office \
        wps-office-wps \
        wps-office-et \
        wps-office-wpp

    gui::SetDefaultAppForMimetypes wps-office-wps \
        application/vnd.ms-word \
        application/wps-office.docx \
        application/wps-office.doc
        # application/msword
        # application/x-msword
    gui::SetDefaultAppForMimetypes wps-office-et \
        application/vnd.ms-excel \
        application/wps-office.xlsx \
        application/wps-office.xls
    gui::SetDefaultAppForMimetypes wps-office-wpp \
        application/vnd.ms-powerpoint \
        application/wps-office.pptx \
        application/wps-office.ppt

    # FIX: restore default mimes for MS Office documents
    sys::Write <<'EOF' "/usr/share/mime/packages/msoffice.xml"
<?xml version='1.0' encoding='utf-8'?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
    <mime-type type="application/msword">
        <comment>Microsoft Word</comment>
        <alias type="application/vnd.ms-word"/>
        <alias type="application/x-msword"/>
        <glob pattern="*.doc" weight="61"/>
        <glob pattern="*.docx" weight="61"/>
        <glob pattern="*.rtf" weight="61"/>
    </mime-type>
    <mime-type type="application/vnd.ms-excel">
        <comment>Microsoft Excel</comment>
        <alias type="application/msexcel"/>
        <alias type="application/x-msexcel"/>
        <glob pattern="*.xls" weight="61"/>
        <glob pattern="*.xlsx" weight="61"/>
    </mime-type>
    <mime-type type="application/vnd.ms-powerpoint">
        <comment>Microsoft Powerpoint</comment>
        <alias type="application/vnd.ms-powerpoint"/>
        <alias type="application/powerpoint"/>
        <alias type="application/mspowerpoint"/>
        <alias type="application/x-mspowerpoint"/>
        <glob pattern="*.pps" weight="61"/>
        <glob pattern="*.ppt" weight="61"/>
        <glob pattern="*.pptx" weight="61"/>
    </mime-type>
</mime-info>
EOF
   update-mime-database /usr/share/mime
   sys::Chk

    # CONF
   sys::Write <<'EOF' "$HOME/.config/Kingsoft/Office.conf"
[6.0]
common\AcceptedEULA=true
common\system_check\no_necessary_symbol_fonts=false
wps\uifile=res/wpsongmani.kui
et\uifile=res/etongmani.kui
wpp\uifile=res/wppongmani.kui
wps\wpsongmani\UseSystemTitleBar=true
et\etongmani\UseSystemTitleBar=true
wpp\wppongmani\UseSystemTitleBar=true
EOF
    sys::Write <<'EOF' "$HOME/.kingsoft/office6/skins/default/histroy.ini" # TYPO
[wps]
lastSkin=2013

[et]
lastSkin=2013

[wpp]
lastSkin=2013
EOF
    # BUG "2016black" theme not distributed anymore, use: "2016" (white), "2013blue", "2013" (black)
    # ALT manually reinstall "2016black" theme
}



app::LibreOffice ()
{
    Meta --desc "Office suite"

    apt::AddPpa --noupgrade libreoffice/ppa

    apt::AddPackages \
        libreoffice-common libreoffice-core libreoffice-base-core \
        libreoffice-style-elementary libreoffice-style-galaxy libreoffice-gnome libreoffice-gtk2 \
        libreoffice-writer libreoffice-calc libreoffice-impress libreoffice-draw \
        libreoffice-pdfimport \
        python3-uno uno-libs3 unoconv ure

    gui::AddAppFolder Office \
        libreoffice-writer \
        libreoffice-calc \
        libreoffice-impress \
        libreoffice-draw

    gui::HideApps libreoffice-startcenter

    gui::SetAppName libreoffice-writer  "LO Writer"
    gui::SetAppName libreoffice-calc    "LO Calc"
    gui::SetAppName libreoffice-impress "LO Impress"
    gui::SetAppName libreoffice-draw    "LO Draw"

    # DEV Experimental GTK3 Mode
    # TIP override Exec= IN /usr/share/applications/libreoffice-*.desktop :
    # env SAL_USE_VCLPLUGIN=gtk3
    # <item oor:path="/org.openoffice.Office.Common/Misc"><prop oor:name="ExperimentalMode" oor:op="fuse"><value>false</value></prop></item>

    # Disable splash
    sed -E -i 's/^Logo=1$/Logo=0/' /etc/libreoffice/sofficerc

    # THEMING
    net::Download \
        "https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-libreoffice-theme/master/images_papirus.zip" \
        /usr/share/libreoffice/share/config/images_papirus.zip
    ln -s /usr/{share,lib}/libreoffice/share/config/images_papirus.zip

# TOCHECK https://github.com/RaitaroH/LibreOffice-BreezeDark/blob/master/registrymodifications.xcu
    mkdir -p "$HOME/.config/libreoffice/4/user"
    sys::Write <<EOF "$HOME/.config/libreoffice/4/user/registrymodifications.xcu"
<?xml version="1.0" encoding="UTF-8"?>
<oor:items xmlns:oor="http://openoffice.org/2001/registry" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <item oor:path="/org.openoffice.Office.Common/Misc"><prop oor:name="SymbolStyle" oor:op="fuse"><value>papirus</value></prop></item>
    <item oor:path="/org.openoffice.Office.UI/ColorScheme/ColorSchemes/org.openoffice.Office.UI:ColorScheme['LibreOffice']/DocColor"><prop oor:name="Color" oor:op="fuse"><value>$( echo -n $((16#$THEME_COLOR_BACKGD_HEX)) )</value></prop></item>
    <item oor:path="/org.openoffice.Office.UI/ColorScheme/ColorSchemes/org.openoffice.Office.UI:ColorScheme['LibreOffice']/FontColor"><prop oor:name="Color" oor:op="fuse"><value>$( echo -n $((16#$THEME_COLOR_FOREGD_HEX)) )</value></prop></item>
    <item oor:path="/org.openoffice.Office.UI/ColorScheme/ColorSchemes/org.openoffice.Office.UI:ColorScheme['LibreOffice']/AppBackground"><prop oor:name="Color" oor:op="fuse"><value>$( echo -n $((16#$THEME_COLOR_BACKGD_HEX)) )</value></prop></item>
    <item oor:path="/org.openoffice.Office.UI/ColorScheme/ColorSchemes/org.openoffice.Office.UI:ColorScheme['LibreOffice']/CalcGrid"><prop oor:name="Color" oor:op="fuse"><value>3355443</value></prop></item>
</oor:items>
EOF
    cp "$HOME/.config/libreoffice/4/user/registrymodifications.xcu"{,.eyecare}
    sys::Write <<EOF "$HOME/.config/libreoffice/4/user/registrymodifications.xcu.default"
<?xml version="1.0" encoding="UTF-8"?>
<oor:items xmlns:oor="http://openoffice.org/2001/registry" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <item oor:path="/org.openoffice.Office.Common/Misc"><prop oor:name="SymbolStyle" oor:op="fuse"><value>papirus</value></prop></item>
</oor:items>
EOF

    # Extensions
    apt::AddPackages python3-uno
    local tmpDir=$( mktemp -d )

    # Disable start center https://bz.apache.org/ooo/show_bug.cgi?id=90815
    net::Download \
        "https://bz.apache.org/ooo/attachment.cgi?id=58887" \
        "$tmpDir/DisableStartModule.oxt"
    HOME=/root unopkg add --shared "$tmpDir/DisableStartModule.oxt"

    # VRT Network Equipment
    net::Download \
        "https://www.vrt.com.au/sites/default/files/download/VRTnetworkequipment_1.2.0-lo.oxt" \
        "$tmpDir/vrt.oxt"
        # ALT "https://extensions.libreoffice.org/extensions/vrt-network-equipment/1.2.0/@@download/file/vrtnetworkequipment_1-2-0-lo.oxt" \
        # ALT "https://www.vrt.com.au/sites/default/files/download/VRTnetworkequipment_1.2.0-lo.oxt" \
    HOME=/root unopkg add --shared "$tmpDir/vrt.oxt"
    sys::Chk

    # FR LibreOffice Grammalecte
    if [[ "$KEYBOARD_LAYOUT"  == "fr" ]] ; then
        local oxturl="https://grammalecte.net/$(
              net::Download "https://grammalecte.net" \
            | awk -F"\"" 'BEGIN{RS="\""} /\/oxt\/Grammalecte-fr.*\.oxt$/{print;exit}'
            )"
        if [[ $oxturl =~ \.oxt$ ]] ; then
            net::Download "$oxturl" "$tmpDir/grammalecte.oxt"
            HOME=/root unopkg add --shared "$tmpDir/grammalecte.oxt"
            sys::Chk
        fi
    fi

    rm -rf "$tmpDir/"
    chown -hR 1000:1000 "$HOME/.config/libreoffice"


    # ooo-thumbnailer-custom: ffmpegthumbnailer instead of totem-video-thumbnailer
    apt::AddPackages imagemagick-6.q16 ; gui::HideApps display-im6 display-im6.q16
    apt::AddPackages ooo-thumbnailer

    sed -E \
        -e 's#(\+matte)#\1 -brightness-contrast -30x0#' \
        -e 's#^(\s*)totem-video-thumbnailer (\S+) (\S+)#\1ffmpegthumbnailer -c png -t 10 -i \2 -o \3#' \
        /usr/bin/ooo-thumbnailer \
        >/usr/bin/ooo-thumbnailer-custom
    sys::Chk

    chmod +x /usr/bin/ooo-thumbnailer-custom
    sys::Chk

    sys::Write <<'EOF' /usr/share/thumbnailers/ooo.thumbnailer
[Thumbnailer Entry]
TryExec=ooo-thumbnailer-custom
Exec=/usr/bin/ooo-thumbnailer-custom %i %o %s
MimeType=application/vnd.oasis.opendocument.graphics;application/vnd.oasis.opendocument.presentation;application/vnd.oasis.opendocument.spreadsheet;application/vnd.oasis.opendocument.text;
EOF


    # CUSTOM msoffice-thumbnailer-custom
    # FROM https://github.com/NicolasBernaerts/ubuntu-scripts/tree/master/thumbnailer/msoffice
    apt::AddPackages \
        gvfs-bin libfile-mimeinfo-perl netpbm

    sys::Write <<'EOF' /usr/local/bin/msoffice-thumbnailer-custom 0:0 755
#!/bin/bash
# FROM https://github.com/NicolasBernaerts/ubuntu-scripts/tree/master/thumbnailer/msoffice

# check tools availability
CMD_OFFICE=libreoffice
for i in "$CMD_OFFICE" gio pbmmake pngtopnm pnmscalefixed pnmcomp pnmtopng; do
    command -v $i >/dev/null 2>&1 || { echo "[error] $i missing"; exit 1; }
done

# get parameters
FILE_URI="$1"
FILE_THUMB="$2"

# get filename extension
FILE_EXT="${FILE_URI##*.}"
[ "${FILE_EXT}" = "${FILE_URI}" ] && FILE_EXT="none"

# generate temporary files and directory
TMP_DIR=$(mktemp -t -d "thumb-ms-XXXXXXXX")
TMP_LOCAL="${TMP_DIR}/thumbnail.${FILE_EXT}"

# if file is a remote one
URI_TYPE="${FILE_URI:0:4}"
if [ "${URI_TYPE}" = "file" ]
then
    # convert URI to local path and extract local path
    FILE_PATH=$(printf '%b' "${FILE_URI//%/\\x}")
    FILE_LOCAL="${FILE_PATH:7}"
else
    # copy input file to temporary local file
    gio copy "${FILE_URI}" "${TMP_LOCAL}"
    FILE_LOCAL="${TMP_LOCAL}"
fi

# convert first page to PNG
${CMD_OFFICE} "-env:UserInstallation=file://${TMP_DIR}" --headless \
    --convert-to png --outdir "${TMP_DIR}" "${FILE_LOCAL}"

FILE_NAME=$(basename "${FILE_LOCAL}")
FILE_NAME="${FILE_NAME%.*}"

# convert PNG to PNM to PNG
  pngtopnm "${TMP_DIR}/${FILE_NAME}.png" \
| pnmscalefixed -xysize 256 256 - \
| ppmbrighten -v -30 \
| pnmtopng -downscale - > "${FILE_THUMB}"

# remove temporary directory
rm -r "${TMP_DIR}"
EOF

    sys::Write <<'EOF' /usr/share/thumbnailers/msoffice.thumbnailer
[Thumbnailer Entry]
TryExec=/usr/local/bin/msoffice-thumbnailer-custom
Exec=/usr/local/bin/msoffice-thumbnailer-custom %u %o %s
MimeType=application/msword;application/vnd.ms-word;application/vnd.openxmlformats-officedocument.wordprocessingml.document;application/vnd.ms-excel;application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;application/vnd.openxmlformats-officedocument.spreadsheetml.template;application/vnd.ms-powerpoint;application/vnd.openxmlformats-officedocument.presentationml.presentation;application/vnd.openxmlformats-officedocument.presentationml.template;application/vnd.openxmlformats-officedocument.presentationml.slideshow;application/ms-office;application/wps-office.docx;application/wps-office.doc;application/wps-office.xlsx;application/wps-office.xls;application/wps-office.pptx;application/wps-office.ppt;
EOF

}



app::Okular ()
{
    Meta --desc "Document viewer"

    apt::AddPackages okular okular-extra-backends

    local name
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        name=kde4-okular
        # FIX StartupWMClass
        sed -E \
            's#^(\[Desktop Entry\].*)$#\1\nStartupWMClass=okular#' \
            /usr/share/applications/kde4/okular.desktop \
            >/usr/local/share/applications/$name.desktop
    else
        name=org.kde.okular
    fi

    gui::AddAppFolder Office $name

    # MIME
    gui::SetDefaultAppForMimetypes $name \
        application/x-bzpdf \
        application/x-gzpdf \
        application/pdf \
        application/x-gzpostscript \
        application/postscript \
        image/x-eps \
        image/x-bzeps \
        image/x-gzeps \
        application/x-cbr \
        application/x-cbt \
        application/x-cbz \
        image/x-dds \
        image/x-exr \
        image/x-hdr \
        application/x-dvi \
        application/x-fictionbook+xml \
        image/g3fax



    # CONF
    sys::Write <<EOF $HOME/.kde/share/config/okularpartrc 1000:1000
[Core General]
ChooseGenerators=true
ExternalEditor=Custom
ExternalEditorCommand=
ObeyDRM=false

[Dlg Accessibility]
RecolorBackground=$THEME_COLOR_BACKGD_RGB
RecolorForeground=$THEME_COLOR_FOREGD_RGB

[Dlg Performance]
EnableCompositing=false

[Document]
ChangeColors=true
PaperColor=$THEME_COLOR_BACKGD_RGB
RenderMode=Recolor

[General]
DisplayDocumentNameOrPath=Path
DisplayDocumentTitle=false
ShellOpenFileInTabs=true
ShowOSD=false
UseKTTSD=false

[Main View]
ShowBottomBar=false
ShowLeftPanel=false
SplitterSizes=171,1709

[Nav Panel]
SidebarIconSize=16
SidebarShowText=false

[PageView]
ViewMode=Facing

[Zoom]
ZoomMode=3
EOF

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then

    sys::Write <<EOF $HOME/.kde/share/config/okularrc 1000:1000
Height 1200=1138
MenuBar=Disabled
State=AAAA/wAAAAD9AAAAAAAAA8AAAARMAAAABAAAAAQAAAAIAAAACPwAAAABAAAAAgAAAAEAAAAWAG0AYQBpAG4AVABvAG8AbABCAGEAcgEAAAAA/////wAAAAAAAAAA
Width 1920=960

[Colors]
CurrentPalette=Forty Colors

[Desktop Entry]
FullScreen=false
shouldShowMenuBarComingFromFullScreen=true
shouldShowToolBarComingFromFullScreen=true

[MainWindow]
Height 1200=1138
MenuBar=Disabled
State=AAAA/wAAAAD9AAAAAAAAA8AAAARMAAAABAAAAAQAAAAIAAAACPwAAAABAAAAAgAAAAEAAAAWAG0AYQBpAG4AVABvAG8AbABCAGEAcgEAAAAA/////wAAAAAAAAAA
ToolBarsMovable=Disabled
Width 1920=960

[MainWindow][Toolbar mainToolBar]
ToolButtonStyle=IconOnly

[Recent Files]

[Toolbar mainToolBar]
ToolButtonStyle=IconOnly
EOF


        sys::Write <<EOF $HOME/.kde/share/apps/okular/part.rc 1000:1000
<!DOCTYPE kpartgui>
<kpartgui version="37" name="okular_part">
 <MenuBar>
  <Menu noMerge="1" name="file">
   <text>&amp;File</text>
   <Action group="file_open" name="get_new_stuff"/>
   <Action group="file_open" name="import_ps"/>
   <Action group="file_save" name="file_save_as"/>
   <Action group="file_save" name="file_save_copy"/>
   <Action group="file_save" name="file_reload"/>
   <Action group="file_print" name="file_print"/>
   <Action group="file_print" name="file_print_preview"/>
   <Action group="file_print" name="properties"/>
   <Action group="file_print" name="embedded_files"/>
   <Action group="file_print" name="file_export_as"/>
  </Menu>
  <Menu noMerge="1" name="edit">
   <text>&amp;Edit</text>
   <Action name="edit_undo"/>
   <Action name="edit_redo"/>
   <Separator/>
   <Action name="edit_copy"/>
   <Separator/>
   <Action name="edit_select_all"/>
   <Separator/>
   <Action name="edit_find"/>
   <Action name="edit_find_next"/>
   <Action name="edit_find_prev"/>
  </Menu>
  <Menu noMerge="1" name="view">
   <text>&amp;View</text>
   <Action name="presentation"/>
   <Separator/>
   <Action name="view_zoom_in"/>
   <Action name="view_zoom_out"/>
   <Action name="view_fit_to_width"/>
   <Action name="view_fit_to_page"/>
   <Action name="view_auto_fit"/>
   <Separator/>
   <Action name="view_continuous"/>
   <Action name="view_render_mode"/>
   <Separator/>
   <Menu noMerge="1" name="view_orientation">
    <text>&amp;Orientation</text>
    <Action name="view_orientation_rotate_ccw"/>
    <Action name="view_orientation_rotate_cw"/>
    <Action name="view_orientation_original"/>
   </Menu>
   <Action name="view_pagesizes"/>
   <Action name="view_trim_mode"/>
   <Separator/>
   <Action name="view_toggle_forms"/>
  </Menu>
  <Menu noMerge="1" name="go">
   <text>&amp;Go</text>
   <Action name="go_previous"/>
   <Action name="go_next"/>
   <Separator/>
   <Action name="first_page"/>
   <Action name="last_page"/>
   <Separator/>
   <Action name="go_document_back"/>
   <Action name="go_document_forward"/>
   <Separator/>
   <Action name="go_goto_page"/>
  </Menu>
  <Menu noMerge="1" name="bookmarks">
   <text>&amp;Bookmarks</text>
   <Action name="bookmark_add"/>
   <Action name="rename_bookmark"/>
   <Action name="previous_bookmark"/>
   <Action name="next_bookmark"/>
   <Separator/>
   <ActionList name="bookmarks_currentdocument"/>
  </Menu>
  <Menu noMerge="1" name="tools">
   <text>&amp;Tools</text>
   <Action name="mouse_drag"/>
   <Action name="mouse_zoom"/>
   <Action name="mouse_select"/>
   <Action name="mouse_textselect"/>
   <Action name="mouse_tableselect"/>
   <Action name="mouse_magnifier"/>
   <Separator/>
   <Action name="mouse_toggle_annotate"/>
   <Separator/>
   <Action name="speak_document"/>
   <Action name="speak_current_page"/>
   <Action name="speak_stop_all"/>
  </Menu>
  <Menu noMerge="1" name="settings">
   <text>&amp;Settings</text>
   <Action group="show_merge" name="show_leftpanel"/>
   <Action group="show_merge" name="show_bottombar"/>
   <Action group="configure_merge" name="options_configure_generators"/>
   <Action group="configure_merge" name="options_configure"/>
  </Menu>
  <Menu noMerge="1" name="help">
   <text>&amp;Help</text>
   <Action group="about_merge" name="help_about_backend"/>
  </Menu>
 </MenuBar>
 <ToolBar noMerge="1" name="mainToolBar">
  <Action name="show_leftpanel"/>
  <Separator name="separator_0"/>
  <text>Main Toolbar</text>
  <Action name="go_previous"/>
  <Action name="go_next"/>
  <Separator name="separator_1"/>
  <Action name="zoom_to"/>
  <Action name="view_zoom_out"/>
  <Action name="view_auto_fit"/>
  <Action name="view_zoom_in"/>
  <Separator name="separator_2"/>
  <Action name="mouse_drag"/>
  <Action name="mouse_zoom"/>
  <Action name="mouse_selecttools"/>
  <Separator name="separator_3"/>
  <Action name="view_continuous"/>
  <Action name="view_render_mode_single"/>
  <Action name="view_render_mode_facing"/>
  <Action name="view_render_mode_overview"/>
  <Separator name="separator_4"/>
  <Action name="toggle_change_colors"/>
  <Separator name="separator_5"/>
  <Action name="view_orientation_rotate_ccw"/>
  <Action name="view_orientation_rotate_cw"/>
 </ToolBar>
 <ActionProperties scheme="Default">
  <Action iconText="Eyecare" name="toggle_change_colors"/>
  <Action iconText="Single" name="view_render_mode_single"/>
  <Action iconText="Facing" name="view_render_mode_facing"/>
 </ActionProperties>
</kpartgui>
EOF
    else
        sys::Write <<EOF $HOME/.config/okularrc 1000:1000
[MainWindow]
MenuBar=Disabled

[MainWindow][Toolbar mainToolBar]
ToolButtonStyle=IconOnly

[Toolbar mainToolBar]
ToolButtonStyle=IconOnly
EOF
        sys::Write <<EOF $HOME/.local/share/kxmlgui5/okular/part.rc 1000:1000
<!DOCTYPE kpartgui>
<kpartgui version="37" name="okular_part">
 <MenuBar>
  <Menu noMerge="1" name="file">
   <text translationDomain="okular">&amp;File</text>
   <Action group="file_open" name="get_new_stuff"/>
   <Action group="file_open" name="import_ps"/>
   <Action group="file_save" name="file_save_as"/>
   <Action group="file_save" name="file_save_copy"/>
   <Action group="file_save" name="file_reload"/>
   <Action group="file_print" name="file_print"/>
   <Action group="file_print" name="file_print_preview"/>
   <Action group="file_print" name="properties"/>
   <Action group="file_print" name="embedded_files"/>
   <Action group="file_print" name="file_export_as"/>
  </Menu>
  <Menu noMerge="1" name="edit">
   <text translationDomain="okular">&amp;Edit</text>
   <Action name="edit_undo"/>
   <Action name="edit_redo"/>
   <Separator/>
   <Action name="edit_copy"/>
   <Separator/>
   <Action name="edit_select_all"/>
   <Separator/>
   <Action name="edit_find"/>
   <Action name="edit_find_next"/>
   <Action name="edit_find_prev"/>
  </Menu>
  <Menu noMerge="1" name="view">
   <text translationDomain="okular">&amp;View</text>
   <Action name="presentation"/>
   <Separator/>
   <Action name="view_zoom_in"/>
   <Action name="view_zoom_out"/>
   <Action name="view_fit_to_width"/>
   <Action name="view_fit_to_page"/>
   <Action name="view_auto_fit"/>
   <Separator/>
   <Action name="view_continuous"/>
   <Action name="view_render_mode"/>
   <Separator/>
   <Menu noMerge="1" name="view_orientation">
    <text translationDomain="okular">&amp;Orientation</text>
    <Action name="view_orientation_rotate_ccw"/>
    <Action name="view_orientation_rotate_cw"/>
    <Action name="view_orientation_original"/>
   </Menu>
   <Action name="view_pagesizes"/>
   <Action name="view_trim_mode"/>
   <Separator/>
   <Action name="view_toggle_forms"/>
  </Menu>
  <Menu noMerge="1" name="go">
   <text translationDomain="okular">&amp;Go</text>
   <Action name="go_previous"/>
   <Action name="go_next"/>
   <Separator/>
   <Action name="first_page"/>
   <Action name="last_page"/>
   <Separator/>
   <Action name="go_document_back"/>
   <Action name="go_document_forward"/>
   <Separator/>
   <Action name="go_goto_page"/>
  </Menu>
  <Menu noMerge="1" name="bookmarks">
   <text translationDomain="okular">&amp;Bookmarks</text>
   <Action name="bookmark_add"/>
   <Action name="rename_bookmark"/>
   <Action name="previous_bookmark"/>
   <Action name="next_bookmark"/>
   <Separator/>
   <ActionList name="bookmarks_currentdocument"/>
  </Menu>
  <Menu noMerge="1" name="tools">
   <text translationDomain="okular">&amp;Tools</text>
   <Action name="mouse_drag"/>
   <Action name="mouse_zoom"/>
   <Action name="mouse_select"/>
   <Action name="mouse_textselect"/>
   <Action name="mouse_tableselect"/>
   <Action name="mouse_magnifier"/>
   <Separator/>
   <Action name="mouse_toggle_annotate"/>
   <Separator/>
   <Action name="speak_document"/>
   <Action name="speak_current_page"/>
   <Action name="speak_stop_all"/>
  </Menu>
  <Menu noMerge="1" name="settings">
   <text translationDomain="okular">&amp;Settings</text>
   <Action group="show_merge" name="show_leftpanel"/>
   <Action group="show_merge" name="show_bottombar"/>
   <Action group="configure_merge" name="options_configure_generators"/>
   <Action group="configure_merge" name="options_configure"/>
  </Menu>
  <Menu noMerge="1" name="help">
   <text translationDomain="okular">&amp;Help</text>
   <Action group="about_merge" name="help_about_backend"/>
  </Menu>
 </MenuBar>
 <ToolBar name="mainToolBar" noMerge="1">
  <Action name="show_leftpanel"/>
  <Separator name="separator_0"/>
  <text translationDomain="okular">Main Toolbar</text>
  <Action name="go_previous"/>
  <Action name="go_next"/>
  <Separator name="separator_1"/>
  <Action name="zoom_to"/>
  <Action name="view_zoom_out"/>
  <Action name="view_zoom_in"/>
  <Separator name="separator_2"/>
  <Action name="view_render_mode_single"/>
  <Action name="view_render_mode_facing"/>
  <Action name="view_render_mode_overview"/>
  <Action name="view_continuous"/>
  <Separator name="separator_3"/>
  <Action name="mouse_drag"/>
  <Action name="mouse_zoom"/>
  <Action name="mouse_select"/>
  <Separator name="separator_4"/>
  <Action name="toggle_change_colors"/>
 </ToolBar>
 <ActionProperties>
  <Action name="mouse_zoom" priority="0"/>
  <Action iconText="Eyecare" name="toggle_change_colors" icon="invertimage"/>
  <Action name="mouse_select" icon="edit-select-all"/>
  <Action name="show_leftpanel" icon="format-justify-left"/>
  <Action iconText="1" name="view_render_mode_single"/>
  <Action iconText="2" name="view_render_mode_facing"/>
  <Action iconText="3" name="view_render_mode_overview"/>
 </ActionProperties>
</kpartgui>
EOF
# ALT icon="face-glasses"
    fi
}



app::MasterPdf_NONFREE ()
{
    Meta --desc "PDF editor" \
         --no-default true

    apt::AddRemotePackages \
        "http://sft.if.usp.br/proprietary/master-pdf-editor-4.3.89_qt5.amd64.deb"
        #  DEAD "http://get.code-industry.net/public/master-pdf-editor-4.3.89_qt5.amd64.deb"

    gui::AddAppFolder Office masterpdfeditor4
    gui::SetAppName masterpdfeditor4 "Master PDF"
    gui::SetAppIcon masterpdfeditor4 master-pdf-editor

    gui::AddEditor /usr/local/share/applications/masterpdfeditor4.desktop \
        edit_pdf \
        "Edit PDF"


    sys::Write <<EOF "$HOME/.config/Code Industry/Master PDF Editor.conf" 1000:1000
[General]
app_style=GTK+
check_updates=0
create_backup_file=false
last_check_update=2000000000
show_icons=true
show_start_page=false
EOF

    # Disable updates
    sys::Write --append <<'EOF' /etc/hosts
127.0.0.1       get.code-industry.net # Master PDF Editor updates
EOF

}
