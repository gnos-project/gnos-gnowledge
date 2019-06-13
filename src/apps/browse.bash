########
# FUNC #  BUNDLES::BROWSE
########



PACKAGES_BROWSE="
    app::Chrome_NONFREE
    app::Chromium
    app::Torbrowser
    app::Tor
    app::Vpn
    app::Web
    "


app::Web ()
{
    Meta --desc "Web browser based on Mozilla Firefox"

    local fullname="Web"
    local browser="firefox-esr"

    local name=$( str::SanitizeString "$fullname" )
    name=${name,,}
    local user=$( basename $HOME )

    firefox::CreateProfile \
        "$browser" \
        $user \
        "$fullname" \
        "$THEME_COLOR_OKOKOK_HEX:$THEME_COLOR_SELECT_HEX" \
        'ALL'

    # LAUNCHER
    gui::AddAppFolder Browse $name

    # gui::AddFavoriteApp $name

    gui::AddKeybinding web-browser "<Super>w" \
        'bash -c "f=0 ; for i in $( xdotool search --class '"${browser^}-$user-$name"' ) ; do r=$( xdotool windowactivate $i 2>&1) ; [[ ${#r} -eq 0 ]] && f=1 && break ; done ; [[ $f -eq 0 ]] && /usr/local/bin/gnos-sugar Nohup '"$browser-$user-$name"'"'
    gui::AddKeybinding web-browser-new "<Shift><Super>w" 'bash -c "'"$browser-$user-$name"'"'
    gui::AddKeybinding web-browser-safe "<Alt><Super>w" 'bash -c "'"$browser-$user-$name"'" --private-window"'

}



app::Torbrowser()
{
    Meta --desc "Tor browser (Official)"

    local url="$(
      net::Download https://aus1.torproject.org/torbrowser/update_3/release/downloads.json \
    | sys::Jq '.downloads.linux64."en-US".binary' )"

    net::DownloadUntarXzip "$url" /opt

    chown -hR 1000:1000 /opt/tor-browser_en-US
    sys::Chk
    mv /opt/tor-browser_en-US /opt/tor-browser_$USER_USERNAME
    sys::Chk

    sed -E \
        -e 's#\$\(dirname "\$\*"\)#/opt/tor-browser_'"$USER_USERNAME"'/#g' \
        -e 's#^(Exec=sh -c '"'"')#\1export GTK_THEME='"$THEME_GS"' ; #' \
        -e 's#^Icon=.*#Icon=torbrowser#' \
        -e 's#^(Name=).*#\1Tor Browser#' \
        /opt/tor-browser_$USER_USERNAME/start-tor-browser.desktop \
        >/usr/local/share/applications/tor-browser.desktop
    sys::Chk

    gui::AddAppFolder Browse tor-browser

    # sys::Mkdir "/opt/tor-browser_$USER_USERNAME/Browser/Downloads"
    sys::Write --append <<EOF $HOME/.config/gtk-3.0/bookmarks 1000:1000
file:///opt/tor-browser_$USER_USERNAME/Browser/Downloads TorDownloads
EOF


    # Shadowfox
    sys::Touch /opt/tor-browser_$USER_USERNAME/Browser/TorBrowser/Data/Browser/profile.default/prefs.js \
        $USER_USERNAME:$USER_USERNAME

    user=$USER_USERNAME \
    profileParent=/opt/tor-browser_$USER_USERNAME/Browser/TorBrowser/Data/Browser/ \
    profilePath=/opt/tor-browser_$USER_USERNAME/Browser/TorBrowser/Data/Browser/profile.default \
        firefox_60::InstallShadowfox --no-uuid


    # Fix Dark theme
    sys::Write --append <<'EOF' /opt/tor-browser_$USER_USERNAME/Browser/TorBrowser/Data/Browser/profile.default/chrome/userContent.css 1000:1000
/* Workaround dark theme bug https://bugzilla.mozilla.org/show_bug.cgi?id=70315 */

input:not([type=checkbox]):not([type=radiobox]), textarea, select {
background-color: white;
color: black;
-moz-appearance: none !important;
}
button,
input[type="reset"],
input[type="button"],
input[type="submit"] {
background-color: ThreeDFace;
color: black;
-moz-appearance: none;
}
EOF

    # Fix Tabs
    sys::Write --append <<'EOF' /opt/tor-browser_$USER_USERNAME/Browser/TorBrowser/Data/Browser/profile.default/chrome/userChrome.css 1000:1000
/* FROM https://addons.mozilla.org/en-US/firefox/addon/squared-australis-tabs/ */
@namespace url(http://www.mozilla.org/keymaster/gatekeeper/there.is.only.xul);
@-moz-document url("chrome://browser/content/browser.xul"){

#tabbrowser-tabs { border-top: 1px solid #AD557A !important; margin: 0 !important; border-top-style: dashed !important; }

#nav-bar { border: 0 !important; }
EOF
return
cat >/dev/null <<EOF
#tabbrowser-tabs,
.tab-background-start::after,
.tab-background-start::before,
.tab-background-start,
.tab-background-end,
.tab-background-end::after,
.tab-background-end::before {
width: 0 !important;
}

.tab-background-start[selected=true]:-moz-locale-dir(ltr)::before,
.tab-background-end[selected=true]:-moz-locale-dir(rtl)::before,
.tab-background-end[selected=true]:-moz-locale-dir(ltr)::before,
.tab-background-start[selected=true]:-moz-locale-dir(rtl)::before {
background-image: none !important;
}

.tab-background,
.tabs-newtab-button {
-moz-margin-end: -1px !important;
-moz-margin-start: -1px !important;
background: none !important; /**/
}

.tab-background-middle {
border-left: 4px solid transparent !important;
border-right: 4px solid transparent !important;
margin: 0 -4px !important;
}

.tabbrowser-tab > .tab-stack > .tab-background,
.tabs-newtab-button {
background-position: 0px 0px, 4px top, right top !important;
background-repeat: no-repeat !important;
background-size: 4px 31px, calc(100% - (2 * 4px)) 31px, 4px 31px !important;
}

.tab-background-middle[selected=true] {
background-size: auto 31px !important;
}

.tabs-newtab-button {
width: 30px !important;
}

}
EOF
}



app::Vpn ()
{
    Meta --desc "Vpn browser" \
         --no-default true

    # Firefox
    local browser="firefox-esr"
    local fullname="Vpn"
    local name=$( str::SanitizeString "$fullname" )
    name=${name,,}
    local user=$( basename $HOME )
    firefox::CreateProfile \
        "$browser" \
        $user \
        "$fullname" \
        "$THEME_COLOR_SELECT_HEX" \
        Base Content Eyecare Firejail Flash Dev Privacy Searchplugins Theme Ui

    gui::AddAppFolder Browse $name

    gui::AddKeybinding web-browser-vpn "<Alt><Super>w" 'bash -c "'"$browser-$user-$name"' --private-window"'

    # gnos-vpngate
    cli::Vpngate
    sys::Write --append <<EOF $HOME/.config/vpngate/browser 1000:1000
# NAME: Default browser profile
# DESC: High Throughput
filter='( ."VPN sessions" > 0)'
select='-."Throughput (Mbps)" / ."VPN sessions"'
EOF

    # PATCH desktop launcher
    sys::SedInline 's#^(FF_BRANDING=[^ ]+ exec)#\1 vpngate -v -g browser #' \
        /usr/local/bin/$browser-$user-$name
    sys::Chk
}



app::Tor()
{
    Meta --desc "Tor browser (Experimental)" \
         --no-default true

    # TIP: http://torstatus.blutmagie.de/

    # Tor
    apt::AddSource tor  \
        "http://deb.torproject.org/torproject.org"  \
        "$(lsb_release -cs) main" \
        "https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc"
        # NEW "74A941BA219EC810"
        # OLD "A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89"
    apt::AddPackages tor deb.torproject.org-keyring \
        tor-geoipdb tor-arm
    gui::AddSystemdSwitch tor tor 1
    # rm /etc/systemd/system/multi-user.target.wants/tor.service
    systemctl mask tor

    # SelekTOR
    apt::AddRemotePackages \
        "https://www.dazzleships.net/?wpdmact=process&did=Mi5ob3RsaW5r"
    gui::AddAppFolder Net selektor
    gui::SetAppIcon selektor selektoricon
    gui::HideApps selektor-proxy-reset
    gui::HideApps selektor-autostart # BIONIC
    mv /etc/xdg/autostart/selektor-autostart.desktop{,.ORIG}
    local tcpport=9090
    sys::Write --append <<EOF "$HOME/.SelekTOR/3xx/SelekTOR.xml" 1000:1000
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE properties SYSTEM "http://java.sun.com/dtd/properties.dtd">
<properties>
<comment>SelekTOR Settings</comment>
<entry key="PREF_AUTOSTART">false</entry>
<entry key="PREF_TORLOGLEV">2</entry>
<entry key="PREF_HTTP_PROXY"/>
<entry key="prefsver">1.01</entry>
<entry key="PREF_UPDATECHECK">true</entry>
<entry key="PREF_GEOCHECK">true</entry>
<entry key="PREF_GEODATE">$(( $( date -d now "+%s" )000 + 60000 * 60 * 24 * 90 ))</entry>
<entry key="PREF_PROXY_MODE">0</entry>
<entry key="PREF_TORARGS"/>
<entry key="PREF_AVOIDDISK">true</entry>
<entry key="PREF_CACHEDELETE">false</entry>
<entry key="PREF_SAFELOG">true</entry>
<entry key="PREF_LISTENPORT">$tcpport</entry>
<entry key="PREF_TORBRIDGE"/>
<entry key="PREF_NOSYSTRAY">true</entry>
<entry key="PREF_MINONCLOSE">false</entry>
<entry key="PREF_DISABLE_NOTIFY">true</entry>
<entry key="PREF_HIDE_MIN">false</entry>
<entry key="PREF_HIDETOTRAY">false</entry>
<entry key="PREF_DONOT_PROXY">localhost,127.0.0.1</entry>
<entry key="PREF_SAFESOCKS">true</entry>
<entry key="PREF_TESTSOCKS">false</entry>
</properties>
EOF

    # Firefox
    local browser="firefox-esr"

    local fullname="Tor"
    local name=$( str::SanitizeString "$fullname" )
    name=${name,,}
    local user=$( basename $HOME )
    firefox::CreateProfile \
        "$browser" \
        $user \
        "$fullname" \
        "$THEME_COLOR_MANAGE_HEX" \
        Base Content Eyecare Firejail Privacy Theme Tor Ui

    gui::AddAppFolder Browse $name

    gui::AddKeybinding web-browser-tor "<Primary><Super>w" 'bash -c "'"$browser-$user-$name"' --private-window"'

    # PATCH launcher: Firejail dns
    sed -i -E 's#^(exec firejail)#\1 --dns=0.0.0.0#' \
        /usr/local/bin/$browser-$user-$name

    # PATCH launcher: SelekTOR
    local code='xdotool search -maxdepth 1 --class SelekTOR \&>/dev/null || { /usr/bin/selektor \& sleep 4 ; xdotool search -maxdepth 1 --class SelekTOR || exit ; }'
    # ALT 'while true ; do sleep 1 ; netstat -lnpet4 2>/dev/null | awk "s\\$4~/:9090\\$/{exit 1}" || break ; done'
    sys::SedInline 's#^(FF_BRANDING=[^ ]+ exec)#'"$code"'\n\1#' \
        /usr/local/bin/$browser-$user-$name

    # BONUS: Torjail
    net::Download \
    "https://raw.githubusercontent.com/orjail/orjail/master/usr/sbin/orjail" \
        /usr/local/sbin/orjail
    chmod +x /usr/local/sbin/orjail
    sys::SedInline 's#(\$SUDOBIN) (-u)#\1 --set-home \2#' /usr/local/sbin/orjail
}



app::Chrome_NONFREE ()
{
    Meta --desc "Web browser (Google)" \
         --no-default true

    apt::AddRemotePackages \
        "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"

    gui::SetAppProp google-chrome Exec "google-chrome-stable --no-first-run --no-default-browser-check %U"
    gui::SetAppName google-chrome "Chrome"

    gui::AddAppFolder Browse google-chrome

    if [[ -d "$HOME/.config/browser/" ]] ; then
        ln -s "/usr/local/share/applications/google-chrome.desktop" $HOME/.config/browser/
        sys::Chk
        chown -hR 1000:1000 "$HOME/.config/browser/google-chrome.desktop"
        sys::Chk
    fi

    local bashrc=$HOME/.bashrc
    [[ -d "$HOME/.bashrc.d" ]] && bashrc=$HOME/.bashrc.d/env.chrome
        sys::Write --append <<'EOF' "$bashrc" 1000:1000 700
export GOOGLE_API_KEY="no"
export GOOGLE_DEFAULT_CLIENT_ID="no"
export GOOGLE_DEFAULT_CLIENT_SECRET="no"
EOF

}



app::Chromium ()
{
    Meta --desc "Chrome alternative"

    # PPA: HW-accel video support
    apt::AddPpaPackages saiarcot895/chromium-beta \
        chromium-browser chromium-codecs-ffmpeg-extra

    gui::SetAppProp chromium-browser Exec "chromium-browser --no-first-run --no-default-browser-check %U"
    gui::SetAppName chromium-browser Chromium
    gui::AddAppFolder Browse chromium-browser

    if [[ -d "$HOME/.config/browser/" ]] ; then
        ln -s "/usr/local/share/applications/chromium-browser.desktop" $HOME/.config/browser/
        sys::Chk
        chown -hR 1000:1000 "$HOME/.config/browser/chromium-browser.desktop"
        sys::Chk
    fi

# TODO API KEY -less launcher: --disable-infobars

    local bashrc=$HOME/.bashrc
    [[ -d "$HOME/.bashrc.d" ]] && bashrc=$HOME/.bashrc.d/env_chrome
        sys::Write --append <<'EOF' "$bashrc" 1000:1000 700
export GOOGLE_API_KEY="no"
export GOOGLE_DEFAULT_CLIENT_ID="no"
export GOOGLE_DEFAULT_CLIENT_SECRET="no"
EOF

# TODO reset ALTERNATIVES x-www-browser gnome-www-browser
}
