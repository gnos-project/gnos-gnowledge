########
# FUNC #  BUNDLES::SOFTWARE
########



PACKAGES_SOFTWARE="
    app::Drivers
    app::Updates
    app::Software
    app::Gdebi
    app::Synaptic
    app::Yppamanager
    "



app::Drivers ()
{
    Meta --desc "Drivers installer"

    apt::AddPackages software-properties-gtk

    gui::SetAppName software-properties-gtk Apt
    gui::AddAppFolder Settings software-properties-gnome software-properties-gtk
    gui::HideApps software-properties-gtk software-properties-livepatch

    gui::SetAppName software-properties-drivers Drivers
    gui::SetAppProp software-properties-drivers NotShowIn ""
    gui::AddAppFolder Software software-properties-drivers
}



app::Gdebi ()
{
    Meta --desc "Software installer"

    apt::AddPackages gdebi-core gdebi lintian
    gui::AddAppFolder Software gdebi
    gui::SetAppName gdebi GDebi
    gui::SetDefaultAppForMimetypes gdebi \
        application/vnd.debian.binary-package \
        application/x-deb

    # WORKAROUND Polkit or libVTE bug ? ugly though
    gui::SetAppProp gdebi Terminal true
}



app::Synaptic ()
{

    Meta --no-default true \
         --desc "Software manager"

    # APT: synaptic
    apt::AddPackages synaptic libgtk2-perl
    gui::AddAppFolder Software synaptic
    gui::SetAppName synaptic Synaptic
    sys::Write <<'EOF' /root/.synaptic/synaptic.conf
Synaptic "" {
  ToolbarState "3";
  ShowAllPkgInfoInMain "true";
  LastSearchType "0";
  showWelcomeDialog "0";
  ViewMode "0";
  AskRelated "true";
  upgradeType "1";
  OneClickOnStatusActions "false";
  delAction "3";
  update "" {
    type "0";
  };
};
EOF
  # Install-Recommends "0";

}



app::Yppamanager ()
{

    Meta --no-default true \
         --desc "PPA manager"

    apt::AddPpaPackages webupd8team/y-ppa-manager y-ppa-manager
    gui::AddAppFolder Software y-ppa-manager
    gui::SetAppName y-ppa-manager "Y PPA Mgr"
}



app::Software ()
{
    Meta --desc "Software store"

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPackages \
            ubuntu-software gnome-software gnome-software-common \
            aptdaemon packagekit-tools \
            appstream/xenial-backports sessioninstaller
    else
        apt::AddPackages \
            ubuntu-software \
            gnome-software \
            gnome-software-common \
            gnome-software-plugin-flatpak \
            gnome-software-plugin-snap \
            gir1.2-snapd-1 appstream aptdaemon packagekit-tools

        sys::Crudini /etc/PackageKit/PackageKit.conf \
            "Daemon" KeepCache true
    fi
    gui::AddAppFolder Software org.gnome.Software
    gui::DisableSearchProvider org.gnome.Software

    RegisterPostInstall post::Software 50
}



post::Software ()
{
    sudo --set-home -u \#1000 pkcon refresh
    sys::Chk

    rm -rf /var/cache/app-info/*
    appstreamcli refresh --force --verbose
    sys::Chk

    gui::XvfbRunKill 4 gnome-software
}



app::Updates ()
{
    Meta --desc "Software updates"

    apt::AddPackages update-notifier
    gui::AddAppFolder Software update-manager
    gui::SetAppName update-manager Updates

    # Disable lts dist upgrade
    sys::Crudini /etc/update-manager/release-upgrades \
    "DEFAULT" \
    "Prompt" \
    "never"

    # Disable autostart
    sys::Copy /etc/xdg/autostart/update-notifier.desktop $HOME/.config/autostart/
    sys::Crudini "$HOME/.config/autostart/update-notifier.desktop" \
        "Desktop Entry" Exec true


    gui::SetAppProp $HOME/.config/autostart/update-notifier.desktop Exec true

    # Disable apt/dpkg hooks
    sys::SedInline 's#^#// #' /etc/apt/apt.conf.d/99update-notifier

    # Force Phased updates to match apt results
    sys::Write <<'EOF' /etc/apt/apt.conf.d/99update-manager
Update-Manager::Always-Include-Phased-Updates "True";
EOF

    # Alternative update notifications using Gnome Shell extension
    # https://github.com/franglais125/apt-update-indicator
    # https://extensions.gnome.org/extension/1139/apt-update-indicator/
    gui::AddShellExtensionsById 1139

    # PATCH: panel indicator position
    sys::SedInline "s#(addToStatusArea\('AptUpdateIndicator', this)#\1, 3#" \
        /usr/share/gnome-shell/extensions/apt-update-indicator@franglais125.gmail.com/indicator.js

    # CONFIG
    sys::Write <<'EOF' --append "$POSTINST_USER_SESSION_SCRIPT"
gsettings set org.gnome.shell.extensions.apt-update-indicator always-visible                    false
gsettings set org.gnome.shell.extensions.apt-update-indicator verbosity                         2
gsettings set org.gnome.shell.extensions.apt-update-indicator update-cmd-options                'update-manager'
gsettings set org.gnome.shell.extensions.apt-update-indicator show-count                        false
EOF
    gui::AddAptIndicatorIgnore $( apt-mark showhold )
    
    # DEV: Extension requires non-default dconf value for ignore-list
    RegisterPostInstall post::Updates 00
}



post::Updates ()
{
    local default="$( sudo --set-home -u \#1000 gsettings get org.gnome.shell.extensions.apt-update-indicator ignore-list | cut -d "'" -f 2 )"
    grun gsettings set org.gnome.shell.extensions.apt-update-indicator ignore-list "$default"
}
