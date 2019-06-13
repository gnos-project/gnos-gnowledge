########
# FUNC #  BUNDLES::SPEAK
########



PACKAGES_SPEAK="
    app::Jami
    app::Pidgin
    app::Signal

    app::Skype_NONFREE
    app::Telegram
    app::TweetTray
    app::Viber_NONFREE
    app::Wire_NONFREE
    "
    # app::Discord_NONFREE



app::TweetTray ()
{

    Meta --desc "Twitter client" \
         --no-default true

    net::InstallGithubLatestRelease jonathontoon/tweet-tray '\\.deb$'

    gui::AddAppFolder Speak tweet-tray
    # gui::SetAppIcon tweet-tray tweetdeck
}



app::Wire_NONFREE ()
{
    apt::AddSource signal  \
        "[arch=amd64] https://wire-app.wire.com/linux/debian"  \
        "stable main"  \
        "https://wire-app.wire.com/linux/releases.key"

    apt::AddPackages wire-desktop
    gui::AddAppFolder Speak wire-desktop
}



app::Viber_NONFREE ()
{
    Meta --desc "Chat client (Viber)" \
         --no-default true

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddRemotePackages "http://download.cdn.viber.com/cdn/desktop/Linux/viber.deb"
    else
        # BUG BIONIC: DEPS libcurl3
        # WORKAROUND https://linuxconfig.org/how-to-install-viber-on-ubuntu-18-04-bionic-beaver-linux
        local tempdeb=$( mktemp -d )
        net::Download "http://download.cdn.viber.com/cdn/desktop/Linux/viber.deb" \
            "$tempdeb/viber.deb"

        pushd "$tempdeb"
        dpkg-deb -x viber.deb viber
        sys::Chk
        dpkg-deb --control viber.deb viber/DEBIAN
        sys::Chk
        sys::SedInline 's#libcurl3#libcurl4#' viber/DEBIAN/control
        dpkg -b viber viberfix.deb
        sys::Chk
        # apt::AddLocalPackages
        dpkg -i viberfix.deb || apt-get install --yes --no-install-recommends -f
        sys::Chk
        popd
        rm -rf "$tempdeb"
    fi

    # WORKAROUND BUG
    rm /0

    gui::AddAppFolder Speak viber
    gui::SetAppIcon viber viber
}



app::Jami ()
{
    Meta --desc "Secure SIP client"

    # TIP: free TURN account at http://numb.viagenie.ca/cgi-bin/numbacct

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then

        apt::AddSource ring  \
            "https://dl.ring.cx/ring-nightly/ubuntu_16.04/"  \
            "ring main"  \
            "A295D773307D25A33AE72F2F64CD5FA175348F84"

    else

        apt::AddSource ring  \
            "https://dl.ring.cx/ring-nightly/ubuntu_18.04/"  \
            "ring main"  \
            "A295D773307D25A33AE72F2F64CD5FA175348F84"

    fi
    apt::AddPackages ring
    gui::AddAppFolder Speak jami-gnome
    gui::SetAppIcon jami-gnome ring


    # TODO Mime scheme handler ? x-scheme-handler/sip‌​
}



app::Signal ()
{
    Meta --desc "Secure chat client" \
         --no-default true

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddSource signal  \
            "[arch=amd64] https://updates.signal.org/desktop/apt"  \
            "$(lsb_release -cs) main"  \
            "https://updates.signal.org/desktop/apt/keys.asc"
    else
        apt::AddSource signal  \
            "[arch=amd64] https://updates.signal.org/desktop/apt"  \
            "xenial main"  \
            "https://updates.signal.org/desktop/apt/keys.asc"
    fi

    apt::AddPackages signal-desktop

    # Icon
    sed -E -e 's#^Icon=.*#Icon=chrome-bikioccmkafdpakkkcpdbppfkghcmihk-Default#' \
        /usr/share/applications/signal-desktop.desktop \
        >/usr/local/share/applications/signal-desktop.desktop

    gui::AddAppFolder Speak signal-desktop
}



app::Skype_NONFREE ()
{
    Meta --desc "Chat client (Microsoft)" \
         --no-default true

    apt::AddRemotePackages https://go.skype.com/skypeforlinux-64.deb
    gui::AddAppFolder Speak skypeforlinux

    # THEMING
    sys::Write <<'EOF' $HOME/.config/skypeforlinux/ecscache.json 1000:1000
{ "data": { "appOverride": { "featureFlags": { "darkThemeEnabled": true } } } }
EOF

}



app::Telegram ()
{
    Meta --desc "Chat client (VK)" \
         --no-default true

    local tmpdir=$( mktemp -d )
    net::DownloadGithubLatestRelease telegramdesktop/tdesktop \
        '/tsetup\\..*\\.tar\\.xz$' "$tmpdir/tsetup.tar.xz"
    sys::Mkdir /opt/Telegram
    tar --directory /opt/ -xJf "$tmpdir/tsetup.tar.xz"
    sys::Chk

    sys::Write <<'EOF' /usr/local/share/applications/telegramdesktop.desktop
[Desktop Entry]
Type=Application
Name=Telegram
Exec=/opt/Telegram/Telegram -- %u
Icon=telegram
Terminal=false
StartupWMClass=TelegramDesktop
MimeType=x-scheme-handler/tg;
EOF

    gui::AddAppFolder Speak telegramdesktop
}



app::Discord_NONFREE ()
{
    Meta --desc "Chat client (Discord)" \
         --no-default true

    apt::AddRemotePackages "https://discordapp.com/api/download?platform=linux&format=deb"

    gui::AddAppFolder Speak discord
}



app::Pidgin ()
{
    Meta --desc "Universal chat client"

    # TIP: free TURN account at http://numb.viagenie.ca/cgi-bin/numbacct

    apt::AddPackages pidgin pidgin-otr # pidgin-libnotify
    # gui::AddFavoriteApp pidgin
    gui::AddAppFolder Speak pidgin
    gui::SetAppName pidgin Pidgin

    # TODO pidgin-eap
    # https://github.com/PowaBanga/pidgin-EAP

    # ICONS: Unicode emoji themes
    mkdir -p "$HOME/.purple/smileys/"
    local tmpzip=$( mktemp )
    net::Download https://github.com/stv0g/unicode-emoji/archive/master.zip $tmpzip
    unzip $tmpzip -d "$HOME/.purple/smileys/"
    sys::Chk

    # Facebook chat support
    # DEV: MERGED THEN REMOVED FROM 2.12.0
    apt::AddSource purple-facebook \
        "http://download.opensuse.org/repositories/home:/jgeboski/xUbuntu_$(lsb_release -rs)/" \
        "/" \
        "http://download.opensuse.org/repositories/home:/jgeboski/xUbuntu_$(lsb_release -rs)/Release.key"
    apt::AddPackages purple-facebook

    # PLUGIN: Google hangouts support
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages nilarimogard/webupd8 \
            purple-hangouts pidgin-hangouts
    else
        # BIONIC missing
        apt::AddPpaPackages --release xenial nilarimogard/webupd8 \
            purple-hangouts pidgin-hangouts
    fi

    # TOCHECK Twitter support https://github.com/mikeage/prpltwtr

    # PLUGIN: Skype web support
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages aap/pidgin \
            pidgin-skypeweb \
            pidgin-skype-theme \
            pidgin-skype-icons
    else
        # BIONIC missing
        apt::AddPpaPackages --release xenial aap/pidgin \
            pidgin-skypeweb \
            pidgin-skype-theme \
            pidgin-skype-icons
    fi

    # PLUGIN: Telegram support
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages nilarimogard/webupd8 telegram-purple
    else
        # BIONIC missing
        apt::AddRemotePackages \
            https://launchpad.net/ubuntu/+archive/primary/+files/libwebp5_0.4.4-1_amd64.deb
        apt::AddPpaPackages --release xenial \
            nilarimogard/webupd8 telegram-purple
    fi

    # PLUGIN Microsoft Office Communicator support
    apt::AddPackages pidgin-sipe

    # GS integration https://extensions.gnome.org/extension/782/pidgin-im-integration/
    gui::AddShellExtensionsById 782
# BUG Gjs-Message: JS LOG: pidgin-im-gs: Gio.DBusError: GDBus.Error:org.freedesktop.DBus.Error.ServiceUnknown: The name im.pidgin.purple.PurpleService was not provided by any .service files

    # Config
    sys::Write <<'EOF' $HOME/.purple/prefs.xml 1000:1000
<?xml version='1.0' encoding='UTF-8' ?>

<pref version='1' name='/'>
    <pref name='purple'>
        <pref name='away'>
            <pref name='idle_reporting' type='string' value='none'/>
            <pref name='away_when_idle' type='bool' value='0'/>
            <pref name='auto_reply' type='string' value='never'/>
        </pref>
        <pref name='logging'>
            <pref name='format' type='string' value='txt'/>
        </pref>
        <pref name='conversations'>
            <pref name='im'>
                <pref name='send_typing' type='bool' value='0'/>
            </pref>
        </pref>
        <pref name='proxy'>
            <pref name='socks4_remotedns' type='bool' value='1'/>
        </pref>
        <pref name='sound'>
            <pref name='while_status' type='int' value='3'/>
        </pref>
    </pref>
    <pref name='plugins'>
        <pref name='gtk'>
            <pref name='X11'>
                <pref name='notify'>
                    <pref name='type_im' type='bool' value='1'/>
                    <pref name='type_chat' type='bool' value='1'/>
                    <pref name='type_focused' type='bool' value='0'/>
                    <pref name='method_string' type='bool' value='0'/>
                    <pref name='title_string' type='string' value='(*)'/>
                    <pref name='method_urgent' type='bool' value='1'/>
                    <pref name='method_count' type='bool' value='1'/>
                    <pref name='notify_focus' type='bool' value='1'/>
                    <pref name='notify_click' type='bool' value='1'/>
                    <pref name='notify_type' type='bool' value='1'/>
                    <pref name='notify_send' type='bool' value='1'/>
                    <pref name='notify_switch' type='bool' value='1'/>
                    <pref name='type_chat_nick' type='bool' value='1'/>
                    <pref name='method_count_xprop' type='bool' value='0'/>
                    <pref name='method_raise' type='bool' value='0'/>
                    <pref name='method_present' type='bool' value='0'/>
                </pref>
                <pref name='gestures'>
                    <pref name='visual' type='bool' value='0'/>
                </pref>
            </pref>
            <pref name='timestamp_format'>
                <pref name='force' type='string' value='force24'/>
                <pref name='use_dates'>
                    <pref name='conversation' type='string' value='always'/>
                    <pref name='log' type='string' value='always'/>
                </pref>
            </pref>
        </pref>
    </pref>
    <pref name='pidgin'>
        <pref name='browsers'>
            <pref name='browser' type='string' value='xdg-open'/>
        </pref>
        <pref name='plugins'>
            <pref name='loaded' type='pathlist'>
                <item value='/usr/lib/pidgin/history.so'/>
                <item value='/usr/lib/purple-2/joinpart.so'/>
                <item value='/usr/lib/pidgin/markerline.so'/>
                <item value='/usr/lib/pidgin/notify.so'/>
                <item value='/usr/lib/pidgin/timestamp_format.so'/>
                <item value='/usr/lib/purple-2/ssl-nss.so'/>
                <item value='/usr/lib/pidgin/pidgin-otr.so'/>
                <item value='/usr/lib/purple-2/ssl.so'/>
            </pref>
        </pref>

        <pref name='smileys'>
            <pref name='theme' type='string' value='Small'/>
        </pref>
        <pref name='sound'>
            <pref name='enabled'>
                <pref name='login' type='bool' value='0'/>
                <pref name='logout' type='bool' value='0'/>
                <pref name='send_im' type='bool' value='0'/>
                <pref name='nick_said' type='bool' value='1'/>
            </pref>
        </pref>
        <pref name='conv_focus' type='bool' value='0'/>
        <pref name='conversations'>
            <pref name='toolbar'>
                <pref name='wide' type='bool' value='0'/>
            </pref>
        </pref>
    </pref>
    <pref name='OTR'>
        <pref name='enabled' type='bool' value='1'/>
        <pref name='automatic' type='bool' value='1'/>
        <pref name='onlyprivate' type='bool' value='0'/>
        <pref name='avoidloggingotr' type='bool' value='0'/>
    </pref>
</pref>
EOF


    sys::Write <<EOF $HOME/.purple/gtkrc-2.0 1000:1000
style "purplerc_style"
{
        GtkIMHtml::hyperlink-color = "#$THEME_COLOR_HOTHOT_HEX"
}
widget_class "*" style "purplerc_style"
EOF

    # irc:// scheme support
    apt::AddPackages libpurple-bin
    sys::Write <<EOF /usr/local/share/applications/purple-url-handler.desktop
[Desktop Entry]
Name=Purple URL Handler
GenericName=Internet Messenger
Comment=URL handler forGoogle Talk, Jabber/XMPP, MSN, Yahoo and more
Exec=purple-url-handler %U
Icon=pidgin
StartupNotify=true
Terminal=false
Type=Application
MimeType=x-scheme-handler/aim;x-scheme-handler/gg;x-scheme-h‌​andler/gtalk;x-schem‌​e-handler/icq;x-sche‌​me-handler/irc;x-sche‌​me-handler/ircs;x-sch‌​eme-handler/msnim;x-‌​scheme-handler/myim;‌​x-scheme-handler/sip‌​;x-scheme-handler/xm‌​pp;x-scheme-handler/‌​ymsgr;
Categories=Network;InstantMessaging;
X-Ubuntu-Gettext-Domain=pidgin
NoDisplay=true
EOF
    sudo --set-home -u \#1000 \
        xdg-mime default purple-url-handler.desktop x-scheme-handler/irc
    sudo --set-home -u \#1000 \
        xdg-mime default purple-url-handler.desktop x-scheme-handler/ircs

    # WORKAROUND BUG: File "/usr/bin/purple-url-handler", line 252:    print "TODO: send uri: ", uri
    grep -v '"TODO: send uri: "' \
        /usr/bin/purple-url-handler \
        >/usr/local/bin/purple-url-handler
    chmod +x /usr/local/bin/purple-url-handler

# TODO ? THEME tabs color https://wiki.gnome.org/Attic/GnomeArt/Tutorials/GtkThemes/Pidgin

    chown -hR 1000:1000 "$HOME/.purple"
}
