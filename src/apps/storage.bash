########
# FUNC #  BUNDLES::STORAGE
########



PACKAGES_STORAGE="
    app::Baobab
    app::Gparted
    app::Gsmartcontrol
    app::Sirikali
    app::Zulucrypt
    "
    # TODO app::UsbThumb



app::UsbThumb ()
{
    Meta --desc "USB thumb drives creator"

    # Linux ISO
    apt::AddPackages usb-creator-gtk
    gui::AddAppFolder Storage usb-creator-gtk

    # Windows ISO
    apt::AddPpaPackages nilarimogard/webupd8 woeusb
    gui::AddAppFolder Storage woeusbgui

    # TIP: OSX DMG
    # https://www.insanelymac.com/forum/topic/293168-guide-how-to-make-a-bootable-os-x-109-mavericks-usb-install-drive-on-linux/
}



app::Baobab ()
{
    Meta --desc "Disk space analyzer"

    apt::AddPackages baobab
    gui::AddAppFolder Storage org.gnome.baobab
    gui::SetAppName org.gnome.baobab "Disk Usage"
}



app::Gparted ()
{
    Meta --desc "Partions editor"

    apt::AddPackages gparted
    gui::AddAppFolder Storage gparted
}



app::Gsmartcontrol ()
{
    Meta --desc "SMART monitor"

    apt::AddPackages gsmartcontrol # smart-notifier
    gui::AddAppFolder Storage gsmartcontrol
    gui::SetAppName gsmartcontrol "Gsmart"
}



app::Sirikali ()
{
    Meta --desc "Encrypted folders" \
         --no-default true

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddSource sirikali \
            "http://download.opensuse.org/repositories/home:/obs_mhogomchungu/xUbuntu_16.04/" \
            "/" \
            "https://download.opensuse.org/repositories/home:obs_mhogomchungu/xUbuntu_16.04/Release.key"
    else
        apt::AddSource sirikali \
            "http://download.opensuse.org/repositories/home:/obs_mhogomchungu/xUbuntu_18.04/" \
            "/" \
            "https://download.opensuse.org/repositories/home:obs_mhogomchungu/xUbuntu_18.04/Release.key"
    fi
    apt::AddPackages sirikali
    gui::AddAppFolder Storage sirikali # DEV: check if usefull on xenial ?
    gui::AddAppFolder Storage io.github.mhogomchungu.sirikali
}



app::Zulucrypt ()
{
    Meta --desc "Encrypted devices" \
         --no-default true

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        # ALT https://github.com/mhogomchungu/zuluCrypt/releases/download/5.1.0/zuluCrypt-5.1.0-ubuntu-16.04-Xenial_Xerus.tar.xz
        apt::AddPpaPackages hda-me/zulucrypt zulucrypt-gui zulucrypt-cli libzulucrypt1
        gui::AddAppFolder Storage zuluCrypt zuluMount
    else
        apt::AddPackages zulucrypt-gui # OLD zulumount-gui
        gui::AddAppFolder Storage zuluCrypt zuluMount # OLD zulucrypt-gui zulumount-gui
    fi
}
