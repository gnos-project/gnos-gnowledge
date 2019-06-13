########
# FUNC #  BUNDLES::SETTINGS
########



PACKAGES_SETTINGS="
    app::Controlcenter
    app::Dconfeditor
    app::Tweaks
    app::Galternatives
    app::Dfeet
    "

    # TODO ? launcher for gnome-shell-extension-prefs

    # TOCHECK alacarte vs menulibre ppa:menulibre-dev/daily
    # TOCHECK apt::AddPackages gigolo
    # TOCHECK app::SystemdManager

    # UNUSED gnome-appfolders-manager
    # apt::AddPpaPackages nilarimogard/webupd8 gnome-appfolders-manager
    # gui::AddAppFolder Settings gnome-appfolders-manager



app::Controlcenter ()
{
    Meta --desc "Configuration center"

    apt::AddPackages gnome-control-center
    gui::AddAppFolder Settings gnome-control-center

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        :
        # DEV: pulled in GUI
    else
        # Hide im-config
        gui::HideApps im-config gnome-language-selector
        apt::AddPackages gnome-startup-applications
    fi
    gui::SetAppName gnome-session-properties Startup
}



app::Dconfeditor ()
{
    Meta --no-default true \
         --desc "Configuration editor"

    # dconf-editor
    apt::AddPackages dconf-editor
    gui::AddAppFolder Settings ca.desrt.dconf-editor
    gui::SetAppName ca.desrt.dconf-editor dconf


    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        :
    else
        # BIONIC
        gui::SetAppIcon ca.desrt.dconf-editor dconf-editor
    fi

    # BUG NO EFFECT
#     sys::Write <<'EOF' /usr/share/glib-2.0/schemas/$PRODUCT_NAME-dconf-editor.gschema.override
# [ca.desrt.dconf-editor]
# show-warning=false
# EOF
#     glib-compile-schemas /usr/share/glib-2.0/schemas/

}



app::Tweaks ()
{
    Meta --desc "Gnome tweaks"


    # tweak-tool
    apt::AddPackages gnome-tweak-tool
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        gui::AddAppFolder Settings gnome-tweak-tool
    else
        # BIONIC
        gui::AddAppFolder Settings org.gnome.tweaks
        gui::SetAppIcon org.gnome.tweaks gnome-tweak-tool
    fi

}



app::Galternatives ()
{
    Meta --no-default true \
         --desc "Software alternatives editor"

    apt::AddPackages galternatives
    gui::AddAppFolder Settings galternatives
    gui::SetAppIcon galternatives gnome-windows
    gui::SetAppName galternatives Alternatives

}



app::Dfeet ()
{
    Meta --no-default true \
         --desc "D-BUS browser"

    apt::AddPackages d-feet
    gui::AddAppFolder Settings d-feet
    gui::SetAppName d-feet "D-Bus"
}
