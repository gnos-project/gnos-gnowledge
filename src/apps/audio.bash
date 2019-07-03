########
# FUNC #  BUNDLES::AUDIO
########



PACKAGES_AUDIO="
    app::Ardour
    app::Audacity
    app::Lmms
    app::Mixxx
    app::Pulseeffects
    app::Soundconverter
    "



# TODO MUSESCORE
# ppa:mscore-ubuntu/mscore-stable musescore

# TODO yoshimi synthesizer
# https://sourceforge.net/projects/yoshimi/files/1.5/yoshimi-1.5.2.tar.bz2/download



InstallKxStudioRepo ()
{
# http://kxstudio.linuxaudio.org/Repositories
# http://kxstudio.linuxaudio.org/Repositories:Applications
# http://kxstudio.linuxaudio.org/Repositories:Plugins

    [[ -f /etc/apt/sources.list.d/kxstudio-free.list ]] && return

    apt::AddRemotePackages \
        "https://launchpad.net/~kxstudio-debian/+archive/kxstudio/+files/kxstudio-repos_9.5.1~kxstudio3_all.deb" \
        "https://launchpad.net/~kxstudio-debian/+archive/kxstudio/+files/kxstudio-repos-gcc5_9.5.1~kxstudio3_all.deb"

    apt::Update
    apt::Upgrade
}



app::Mixxx ()
{
    Meta --no-default true \
        --desc "DJ station"

    apt::AddPpaPackages mixxx/mixxx mixxx
    gui::AddAppFolder Audio mixxx
    gui::SetAppIcon mixxx mixxx

    sed -i -E 's/ #.*//' /lib/udev/rules.d/60-mixxx-usb.rules
}



app::Soundconverter ()
{
    Meta --desc "Audio transcoder"

    apt::AddPackages soundconverter
    gui::SetAppName soundconverter Converter
    gui::AddAppFolder Audio soundconverter

    gui::AddEditor \
        /usr/share/applications/soundconverter.desktop \
        convert_audio \
        "Convert audio"

    gui::AddEditor \
        /usr/share/applications/soundconverter.desktop \
        extract_audio \
        "Extract audio"

    sed -i -E 's#^(MimeTypes=).*$#\1video/*#' \
        /usr/share/gnome/file-manager/actions/extract-audio.desktop
}



app::Lmms ()
{
    Meta --no-default true \
         --desc "Audio studio"

    InstallKxStudioRepo

    apt::AddPackages lmms tap-plugins # lmms-vst-server
    gui::AddAppFolder Audio lmms

    gui::AddAppFolder Audio zynaddsubfx-jack
    gui::SetAppName zynaddsubfx-jack "ZynAddSubFx"
    gui::HideApps zynaddsubfx-alsa zynaddsubfx-oss zynaddsubfx-jack-multi

    # TOCHECK http://linux-sound.org/linux-vst-plugins.html
    # TOCHECK kxstudio plugins
}



app::Ardour ()
{
    Meta --no-default true \
         --desc "Audio studio"

    InstallKxStudioRepo

    # DEP: jackd
    apt::AddSelection "jackd2  jackd/tweak_rt_limits   boolean false"
    apt::AddPackages qjackctl
    gui::AddAppFolder Settings qjackctl

    apt::AddPackages ardour  # jamin ubuntustudio-audio-plugins
    gui::AddAppFolder Audio ardour
    gui::SetAppIcon ardour ardour5


# Recommended packages:
#   jackd2-firewire abgate aeolus amb-plugins autotalent
#   blepvco blop calf-plugins caps cmt csladspa drumkv1
#   dssi-host-jack dssi-utils eq10q fil-plugins
#   fluidsynth-dssi foo-yc20 ghostess hexter
#   invada-studio-plugins-ladspa invada-studio-plugins-lv2
#   ir.lv2 jconvolver lv2vocoder mcp-plugins mda-lv2 omins
#   rev-plugins rubberband-ladspa samplv1 slv2-doc slv2-jack
#   swh-lv2 synthv1 tap-plugins vco-plugins vocproc
#   wah-plugins whysynth x42-plugins xsynth-dssi zita-at1
#   zita-lrx zita-mu1 zita-resampler zita-rev1

# Suggested packages:
#   ladish hydrogen jack-rack muse rosegarden zynjacku
#   jack-tools meterbridge jcgui libbonobo2-bin libfftw3-bin
#   libfftw3-dev desktop-base liblo-dev liblrdf0-dev ams
#   tcl-tclreadline vkeybd

    # TOCHECK
    # http://linux-sound.org/linux-vst-plugins.html

    # TODO THEME: $HOME/.config/ardour4/my-dark.colors
    # <ColorAlias name="gtk_background" alias="color 46"/>
}



app::Pulseeffects ()
{
    Meta --desc "Audio equalizer" \
         --no-default true

    InstallKxStudioRepo

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages yunnxx/gnome3 pulseeffects
        gui::AddAppFolder Audio pulseeffects
    else
        apt::AddPpaPackages mikhailnov/pulseeffects \
            pulseeffects pulseaudio \
            calf-plugins zam-plugins rubberband-ladspa \
            liblilv-0-0 mda-lv2 \
            gstreamer1.0-convolver-pulseeffects \
            gstreamer1.0-crystalizer-pulseeffects \
            gstreamer1.0-autogain-pulseeffects
        gui::HideApps calf
        gui::AddAppFolder Audio com.github.wwmm.pulseeffects
    fi
}



app::Audacity ()
{
    Meta --desc "Audio editor"

    apt::AddPackages audacity
    gui::AddAppFolder Audio audacity
    gui::AddEditor /usr/share/applications/audacity.desktop \
        edit_audio \
        "Edit audio"

    # CONF
    sys::Write <<'EOF' $HOME/.audacity-data/audacity.cfg
[GUI]
ShowSplashScreen=0
EOF

    # THEME
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then

        # THEME audacity dark bitmap
        local adTheme="/usr/share/themes/$THEME_GS/audacity/ImageCache.png"
        if [[ -f "$adTheme" ]] ; then
            sys::Copy "$adTheme" "$HOME/.audacity-data/Theme/"
            sys::Write --append <<'EOF' $HOME/.audacity-data/audacity.cfg
[Theme]
LoadAtStart=1
EOF
        fi

    else

        sys::Write --append <<'EOF' $HOME/.audacity-data/audacity.cfg
Theme=dark
EOF
    fi

}
