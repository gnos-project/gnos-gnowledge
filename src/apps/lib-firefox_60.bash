# ▌  ▗ ▌   ▗▀▖▗       ▗▀▖       ▞▀▖▞▀▖
# ▌  ▄ ▛▀▖ ▐  ▄ ▙▀▖▞▀▖▐  ▞▀▖▚▗▘ ▙▄ ▌▞▌
# ▌  ▐ ▌ ▌ ▜▀ ▐ ▌  ▛▀ ▜▀ ▌ ▌▗▚  ▌ ▌▛ ▌
# ▀▀▘▀▘▀▀  ▐  ▀▘▘  ▝▀▘▐  ▝▀ ▘ ▘ ▝▀ ▝▀ 

# DOC firefox_60_feat::* plugins use these variables
# browser
# shellLauncher
# features
# defaultExts
# defaultPrefs
# defaultProfile



firefox_60::AddSchemeHandler () # $1:SCHEME $2:HANDLER $3:DESC
{
    sys::Write --append <<EOF "$defaultProfile/handlers.json.$1"
.schemes += { "$1":{"action":2,"handlers":[{"name":"$3","path":"$2"}]} }
EOF

}



firefox_60::ProcessMime ()
{
    # DEV: run jq from handlers.json.*
    for customMimeFile in "$profileParent/.preconfig/handlers.json."* ; do
        if [[ ! -f "$profilePath/handlers.json" ]] ; then
            sys::Msg "TODO Ignoring $customMimeFile"
            continue
        fi
        sys::JqInline "$(<"$customMimeFile")" "$profilePath/handlers.json"
        rm "$customMimeFile"
    done
}



firefox_60::ResetPlaces() # $1:SQLITE_DB
{
    local db="$1"

    sqlite3 "$db" <<EOF
DELETE FROM moz_bookmarks
WHERE type=1
AND fk NOT IN (2,3);
-- TODO match menu & toolbar ids by name

DELETE FROM moz_bookmarks
WHERE type=2
AND ( id!=1 AND parent!=1 );

DELETE FROM moz_places
WHERE id  NOT IN ( SELECT fk FROM moz_bookmarks WHERE fk IS NOT NULL );

DELETE FROM moz_historyvisits;
EOF
    sys::Chk
}



firefox_60::Conf () # $1:DEST_PATH $2:NAME
{
    # DOC
    # defaultPref();  // set new default value
    # pref();         // set pref, but allow changes in current session
    # lockPref();     // lock pref, disallow changes


    sys::Write --append <<'EOF' "$defaultPrefs"
/*********************
    Firefox Defaults
**********************/


/* Basilisk BUG: NO EFFECT*/
user_pref("extensions.blocklist.enabled", false);
user_pref("extensions.blocklist.url", "");

/* Updates */
user_pref("app.update.enabled", false);
user_pref("app.update.mode", 0);
user_pref("app.update.auto", false);
user_pref("app.update.silent", false);
user_pref("app.update.service.enabled", false);
user_pref("xpinstall.signatures.required", false);
user_pref("lightweightThemes.update.enabled", false);

/* User Agent */
user_pref("browser.search.countryCode", "US");
user_pref("browser.search.region", "US");
user_pref("general.useragent.enable_overrides", true);
user_pref("general.useragent.override", "Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/60.0");

/* Features mitigation */
user_pref("security.dialog_enable_delay", 0); /* Useless as no auto-execution from browser */
user_pref("browser.search.geoip.url", "");
user_pref("browser.search.geoSpecificDefaults", false);
user_pref("extensions.allow-non-mpc-extensions", true);
user_pref("accessibility.typeaheadfind", true);
user_pref("accessibility.typeaheadfind.autostart", false);
user_pref("browser.displayedE10SNotice", 3);
user_pref("browser.pocket.enabled", false);
user_pref("privacy.userContext.enabled", false);
user_pref("browser.startup.page", 0);
user_pref("browser.selfsupport.url", "");
user_pref("browser.tabs.remote.autostart.2", false);
user_pref("geo.enabled", false);
user_pref("geo.wifi.uri", "");
user_pref("signon.rememberSignons", false);
user_pref("reader.parse-on-load.enabled", false);
user_pref("browser.urlbar.oneOffSearches", false);
user_pref("browser.urlbar.searchSuggestionsChoice", false);
user_pref("browser.urlbar.suggest.searches", false);
user_pref("browser.urlbar.trimURLs", false);
user_pref("layout.spellcheckDefault", 0);
user_pref("loop.enabled", false);
user_pref("nglayout.enable_drag_images", false);
user_pref("extensions.webservice.discoverURL", "about:support");
user_pref("extensions.ui.lastCategory", "addons://list/extension");
user_pref("browser.newtabpage.enabled", false);
user_pref("browser.newtabpage.enhanced", false);
user_pref("browser.newtabpage.directory.ping", "");
user_pref("browser.newtabpage.directory.source", "data:application/json,{}");
/* user_pref("browser.download.useDownloadDir", false); */
user_pref("browser.slowStartup.notificationDisabled", true);
user_pref("browser.slowStartup.maxSamples", 0);
user_pref("browser.slowStartup.samples", 0);
user_pref("browser.uitour.enabled", false);
user_pref("network.manage-offline-status", false);
user_pref("extensions.getAddons.showPane", false);


/* UI */
user_pref("browser.fullscreen.animate", false);
user_pref("full-screen-api.warning.timeout", 0);
user_pref("full-screen-api.transition-duration.enter", "0 0");
user_pref("full-screen-api.transition-duration.leave", "0 0" );
user_pref("full-screen-api.transition.timeout", 0 );
user_pref("toolkit.cosmeticAnimations.enabled", false);
user_pref("findbar.highlightAll", true);


/* Leak control */
user_pref("network.cookie.cookieBehavior", 3); /* reject 3rd party cookies */
user_pref("keyword.enabled", false);
user_pref("beacon.enabled", false);
user_pref("browser.safebrowsing.enabled", false);
user_pref("browser.safebrowsing.phishing.enabled", false);
user_pref("browser.safebrowsing.blockedURIs.enabled", false);
user_pref("browser.safebrowsing.downloads.enabled", false);
user_pref("browser.safebrowsing.downloads.remote.enabled", false);
user_pref("browser.safebrowsing.downloads.remote.block_potentially_unwanted", false);
user_pref("browser.safebrowsing.malware.enabled", false);
user_pref("browser.search.update", false);
user_pref("extensions.update.enabled", false);
user_pref("extensions.update.autoUpdateDefault", false);
user_pref("extensions.blocklist.enabled", false);
user_pref("datareporting.healthreport.service.enabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.enabled", false); /* LOCKED in beta */
user_pref("toolkit.telemetry.updatePing.enabled", false);
user_pref("toolkit.telemetry.shutdownPingSender.enabled", false);
user_pref("toolkit.telemetry.newProfilePing.enabled", false);
user_pref("toolkit.telemetry.firstShutdownPing.enabled", false);
user_pref("toolkit.telemetry.bhrPing.enabled", false);
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("privacy.trackingprotection.enabled", false);
user_pref("privacy.trackingprotection.pbmode.enabled", false);
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.ping-centre.telemetry", false);

user_pref("network.captive-portal-service.enabled", false); /* http://detectportal.firefox.com/success.txt */
user_pref("network.proxy.socks_remote_dns", true);
user_pref("security.OCSP.enabled", 0);

/* TODO https://bugzilla.mozilla.org/show_bug.cgi?id=1333933 */

/* asmjs */
user_pref("javascript.options.asmjs", false);
user_pref("javascript.options.wasm", false);

/* webGL */
user_pref("webgl.disabled", true);

/* webRTC */
/* TIP: check https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/ */
user_pref("media.peerconnection.enabled", false);
user_pref("media.peerconnection.ice.default_address_only", true);

/* PLUGINS */
pref("plugin.expose_full_path", false);
user_pref("media.gmp-gmpopenh264.enabled", false); /* as webrtc is disabled */
user_pref("media.gmp-eme-adobe.enabled", false);
user_pref("media.eme.enabled", false);
user_pref("media.eme.apiVisible", false);
user_pref("browser.eme.ui.enabled", false);
user_pref("plugin.state.flash", 0);
/*
user_pref("plugin.state.libgnome-shell-browser-plugin", 1);
*/

/* Network performance FROM: https://addons.mozilla.org/de/firefox/addon/speed-tweaks-speedyfox/ */
user_pref("network.http.pipelining", true);
user_pref("network.http.pipelining.abtest", false);
user_pref("network.http.pipelining.aggressive", true);
user_pref("network.http.pipelining.max-optimistic-requests", 4);
user_pref("network.http.pipelining.maxrequests", 32);
user_pref("network.http.pipelining.maxsize", 300000);
user_pref("network.http.pipelining.read-timeout", 60000);
user_pref("network.http.pipelining.reschedule-on-timeout", true);
user_pref("network.http.pipelining.reschedule-timeout", 15000);
user_pref("network.http.pipelining.ssl", true);
user_pref("network.http.proxy.pipelining", true);
user_pref("network.http.max-connections", 256);
user_pref("network.http.max-persistent-connections-per-proxy", 256);
user_pref("network.http.max-persistent-connections-per-server", 8);
user_pref("network.http.redirection-limit", 20);
user_pref("network.http.speculative-parallel-limit", 0);
user_pref("network.http.fast-fallback-to-IPv4", true);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.prefetch-next", false);
user_pref("browser.cache.use_new_backend", 1);
user_pref("nglayout.initialpaint.delay", 0);
user_pref("network.http.connection-retry-timeout", 0);

/* SILENT */
user_pref("general.warnOnAboutConfig", false);
user_pref("browser.newtabpage.introShown", true);
user_pref("browser.displayedE10SPrompt.1", 5);
user_pref("browser.customizemode.tip0.shown", true);
user_pref("browser.urlbar.userMadeSearchSuggestionsChoice", true);
user_pref("browser.rights.3.shown", true);

/* TODO SSD performance ?
user_pref("browser.cache.disk.parent_directory", "/tmp/firefox");
user_pref("browser.cache.offline.parent_directory", "/tmp/firefox");
*/
user_pref("browser.sessionstore.interval", 60000);

EOF

}



firefox_60::InstallShadowfox() # [ --no-uuid ]
{
    # Install

    local uuid="-generate-uuids"
    [[ "$1" == "--no-uuid" ]] && { uuid= ; shift ; }

    net::DownloadGithubLatestRelease SrKomodo/shadowfox-updater \
        shadowfox_linux_x64 \
        "$profileParent/"

    chmod +x "$profileParent/shadowfox_linux_x64"
    chown $user:$user "$profileParent/shadowfox_linux_x64"
    mv "$profileParent/shadowfox_linux_x64" "$profileParent/shadowfox"
    sys::Chk

    local arg='$*'
    [[ -n "$uuid" && ! -f "$profileParent/.preconfig/shadowfox_exclude_uuids" ]] \
    && arg=-generate-uuids

    sys::Write <<EOF "$profilePath/chrome/update.sh" $user:$user 755
#!/bin/bash
pushd "\$( dirname "\$( readlink -f "\$BASH_SOURCE" )" )"/../.. || exit 1
./shadowfox -profile-index 0 $arg 
EOF


    # Run 1: Custom CSS

    for file in userChrome userContent ; do
           [[ -f "$profilePath/chrome/$file.css" ]] \
        && mv "$profilePath/chrome/$file.css"{,.backup}
    done

    sudo --set-home -u $user "$profilePath/chrome/update.sh"
    sys::Chk

    for file in userChrome userContent ; do
        if find "$profilePath/chrome/$file.css".backup ; then
            sys::Write --append \
                "$profilePath/chrome/ShadowFox_customization/${file}_customization.css" \
                <"$profilePath/chrome/$file.css".backup
            rm "$profilePath/chrome/$file.css".backup
        fi
    done


    # Run 2: Colors theming

    sys::Write <<EOF "$profilePath/chrome/ShadowFox_customization/colorOverrides.css"
--tone-1: #$THEME_COLOR_FOREGD_HEX;
--tone-2: #$THEME_COLOR_FOREGD_HEX;
--tone-3: white;
--tone-4: #$THEME_COLOR_FOREGD_HEX;
--tone-5: #$THEME_COLOR_FOREGD_HEX;
--tone-6: #$THEME_COLOR_OBJECT_HEX;
--tone-7: #$THEME_COLOR_WINDOW_HEX;
--tone-8: #$THEME_COLOR_BACKGD_HEX;
--tone-9: #$THEME_COLOR_BACKGD_HEX;
--accent-1: #$THEME_COLOR_SELECT_HEX;
--accent-2: #$THEME_COLOR_HOTHOT_HEX;
--accent-3: #$THEME_COLOR_HOTHOT_HEX;
EOF

    sudo --set-home -u $user "$profilePath/chrome/update.sh" $uuid
    sys::Chk


    # Run 3: Disable theming on some extensions

    if [[ -n "$uuid" && -f "$profileParent/.preconfig/shadowfox_exclude_uuids" ]] ; then
        local tmpuuid=$( mktemp )
        while IFS= read -r id || [[ -n $id ]] ; do
            grep -vF "$id=" \
                "$profilePath/chrome/ShadowFox_customization/internal_UUIDs.txt" \
                >"$tmpuuid"
            sys::Copy \
                "$tmpuuid" \
                "$profilePath/chrome/ShadowFox_customization/internal_UUIDs.txt"
        done <"$profileParent/.preconfig/shadowfox_exclude_uuids"
        rm -fv "$tmpuuid"
        sudo --set-home -u $user "$profilePath/chrome/update.sh"
        sys::Chk
    fi

}



firefox_60::ShadowfoxExclude() # $1:ID
{
     sys::Write --append "$profileParent/.preconfig/shadowfox_exclude_uuids" \
        <<<"$1"
}



firefox_60_feat::Base()
{
    firefox_60::Conf
}



firefox_60_feat::DefaultBookmarks()
{

    firefox::AddBookmarks "_" \
        "https://google.com/|${PRODUCT_NAME^}" # STUB

    # DOC REF: http://kb.mozillazine.org/About:config_entries
    firefox::AddBookmarks "About $oname" \
        "about:config|Config" \
        "about:about|List" \
        "about:memory|Memory" \
        "about:performance|Performance" \
        "about:support|Support"
}



firefox_60_feat::SoftwareBookmarks()
{

    firefox::AddBookmarks "More Software" \
        "https://packages.ubuntu.com/|Ubuntu" \
        "https://launchpad.net/ubuntu/+ppas|Launchpad" \
        "---" \
        "https://snapcraft.io/store|Snapcraft" \
        "https://flathub.org/apps/|Flathub" \
        "https://appimage.github.io/apps/|AppImage" \
        "---" \
        "https://hub.docker.com/explore/|Docker Hub" \
        "https://www.osboxes.org/virtualbox-images/|VirtualBox" \
        "---" \
        "https://www.npmjs.com/search|Node" \
        "https://rubygems.org/search|Ruby" \
        "https://pypi.python.org/pypi|Python" \
        "---" \
        "https://extensions.gnome.org/|Gnome" \
        "https://addons.mozilla.org/en-US/firefox/extensions/|Firefox" \
        "https://chrome.google.com/webstore/category/extensions|Chromium" \
        "https://packagecontrol.io/|Sublime"
        # "https://store.docker.com/search|Docker Store" \

}



firefox_60_feat::Eyecare()
{
    firefox::AddExtensionByName "$defaultExts" darkreader
}



firefox_60_feat::Searchplugins()
{
    # TIP: http://mycroftproject.com/google-search-plugins.html

    firefox::AddSearchEngine 14900 # "Google US"
    [[ "$KEYBOARD_LAYOUT"  == "fr" ]] && \
        firefox::AddSearchEngine 82766 "Google FR" "http://www.google.com/images/branding/product/ico/googleg_lodp.ico"
    firefox::AddSearchEngine 84531 "DuckDuck"
    firefox::AddSearchEngine 51277 "StartPage"
    firefox::AddSearchEngine 43012 "Wikipedia EN"
    [[ "$KEYBOARD_LAYOUT"  == "fr" ]] && \
        firefox::AddSearchEngine 43656 "Wikipedia FR"
    firefox::AddSearchEngine 63426 # "DevDocs"
    firefox::AddSearchEngine 44108 # "StackExchange"
    firefox::AddSearchEngine 55176 "Github" "https://www.iconsdb.com/icons/download/gray/github-11-32.ico" # "https://mycroftproject.com/installos.php/47102/github-code-search.png"
    firefox::AddSearchEngine 71871 "Ubuntu packages"
    firefox::AddSearchEngine 91876 "Reddit"
    firefox::AddSearchEngine 38959 "OpenStreetMap"
    firefox::AddSearchEngine 10339 "Amazon US"
    if [[ "$KEYBOARD_LAYOUT"  == "fr" ]] ; then
        firefox::AddSearchEngine 10966 "Amazon FR"
        firefox::AddSearchEngine 38439 "Leboncoin FR"
        firefox::AddSearchEngine 91191 "Leboncoin IDF"
    fi
}



firefox_60_feat::Theme()
{
    sys::Touch "$profileParent/.preconfig/shadowfox.mark"

    sys::Write --append <<EOF "$defaultPrefs"
/* classicthemerestorer */
user_pref("extensions.classicthemerestorer.am_extrabars", 0); /* TOCHECK addonbar */
user_pref("lightweightThemes.persisted.footerURL", false);
user_pref("lightweightThemes.persisted.headerURL", false);
user_pref("lightweightThemes.selectedThemeID", "firefox-compact-dark@mozilla.org");
user_pref("lightweightThemes.usedThemes", "[]");

/* THEMING */
user_pref("browser.display.use_system_colors", true);
user_pref("devtools.theme", "dark");

/* FONTS */
user_pref("font.default.x-western","sans-serif");
user_pref("font.name.sans-serif.x-western","$THEME_FONT_SHORT_NAME");
user_pref("font.name.serif.x-western","$THEME_FONT_SHORT_NAME");
user_pref("font.size.variable.x-western","$THEME_FONT_DEFAULT_SIZE");
user_pref("font.name.monospace.x-western","$THEME_FONT_FIXED_NAME");
user_pref("font.size.fixed.x-western","$THEME_FONT_FIXED_SIZE");
EOF


    # userChrome
    local userchrome="$defaultProfile/chrome/userChrome.css"
       [[ -f "$defaultProfile/chrome/ShadowFox_customization/userChrome_customization.css" ]] \
    && userchrome="$defaultProfile/chrome/ShadowFox_customization/userChrome_customization.css"

    # userjs_customization
    sys::Write --append <<EOF "$userchrome"
/* chrome/userjs_customization */
#alltabs-button { -moz-binding: url(data:text/xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIj8+CjwhLS0gQ29weXJpZ2h0IChjKSAyMDE3IEhhZ2dhaSBOdWNoaQpBdmFpbGFibGUgZm9yIHVzZSB1bmRlciB0aGUgTUlUIExpY2Vuc2U6Cmh0dHBzOi8vb3BlbnNvdXJjZS5vcmcvbGljZW5zZXMvTUlUCiAtLT4KCjwhLS0gUnVuIHVzZXJDaHJvbWUuanMvdXNlckNocm9tZS54dWwgYW5kIC51Yy5qcy8udWMueHVsLy5jc3MgZmlsZXMgIC0tPgo8YmluZGluZ3MgeG1sbnM9Imh0dHA6Ly93d3cubW96aWxsYS5vcmcveGJsIj4KICAgIDxiaW5kaW5nIGlkPSJqcyIgZXh0ZW5kcz0iY2hyb21lOi8vZ2xvYmFsL2NvbnRlbnQvYmluZGluZ3MvdG9vbGJhcmJ1dHRvbi54bWwjbWVudSI+CiAgICAgICAgPGltcGxlbWVudGF0aW9uPgogICAgICAgICAgICA8Y29uc3RydWN0b3I+PCFbQ0RBVEFbCiAgICAgICAgICAgICAgICBpZih3aW5kb3cudXNlckNocm9tZUpzTW9kKSByZXR1cm47CiAgICAgICAgICAgICAgICB3aW5kb3cudXNlckNocm9tZUpzTW9kID0gdHJ1ZTsKICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgdmFyIGNocm9tZUZpbGVzID0gRmlsZVV0aWxzLmdldERpcigiVUNocm0iLCBbInVzZXJqc19jdXN0b21pemF0aW9uIl0pLmRpcmVjdG9yeUVudHJpZXM7CiAgICAgICAgICAgICAgICB2YXIgeHVsRmlsZXMgPSBbXTsKICAgICAgICAgICAgICAgIHZhciBzc3MgPSBDY1snQG1vemlsbGEub3JnL2NvbnRlbnQvc3R5bGUtc2hlZXQtc2VydmljZTsxJ10uZ2V0U2VydmljZShDaS5uc0lTdHlsZVNoZWV0U2VydmljZSk7CiAgICAgICAgICAgICAgICAKICAgICAgICAgICAgICAgIHdoaWxlKGNocm9tZUZpbGVzLmhhc01vcmVFbGVtZW50cygpKSB7CiAgICAgICAgICAgICAgICAgICAgdmFyIGZpbGUgPSBjaHJvbWVGaWxlcy5nZXROZXh0KCkuUXVlcnlJbnRlcmZhY2UoQ2kubnNJRmlsZSk7CiAgICAgICAgICAgICAgICAgICAgdmFyIGZpbGVVUkkgPSBTZXJ2aWNlcy5pby5uZXdGaWxlVVJJKGZpbGUpOwogICAgICAgICAgICAgICAgICAgIAogICAgICAgICAgICAgICAgICAgIGlmKGZpbGUuaXNGaWxlKCkpIHsKICAgICAgICAgICAgICAgICAgICAgICAgaWYoLyhedXNlckNocm9tZXxcLnVjKVwuanMkL2kudGVzdChmaWxlLmxlYWZOYW1lKSkgewogICAgICAgICAgICAgICAgICAgICAgICAgICAgU2VydmljZXMuc2NyaXB0bG9hZGVyLmxvYWRTdWJTY3JpcHRXaXRoT3B0aW9ucyhmaWxlVVJJLnNwZWMsIHt0YXJnZXQ6IHdpbmRvdywgaWdub3JlQ2FjaGU6IHRydWV9KTsKICAgICAgICAgICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgICAgICAgICBlbHNlIGlmKC8oXnVzZXJDaHJvbWV8XC51YylcLnh1bCQvaS50ZXN0KGZpbGUubGVhZk5hbWUpKSB7CiAgICAgICAgICAgICAgICAgICAgICAgICAgICB4dWxGaWxlcy5wdXNoKGZpbGVVUkkuc3BlYyk7CiAgICAgICAgICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgICAgICAgICAgZWxzZSBpZigvXC5hc1wuY3NzJC9pLnRlc3QoZmlsZS5sZWFmTmFtZSkpIHsKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGlmKCFzc3Muc2hlZXRSZWdpc3RlcmVkKGZpbGVVUkksIHNzcy5BR0VOVF9TSEVFVCkpCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgc3NzLmxvYWRBbmRSZWdpc3RlclNoZWV0KGZpbGVVUkksIHNzcy5BR0VOVF9TSEVFVCk7CiAgICAgICAgICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgICAgICAgICAgZWxzZSBpZigvXig/ISh1c2VyQ2hyb21lfHVzZXJDb250ZW50KVwuY3NzJCkuK1wuY3NzJC9pLnRlc3QoZmlsZS5sZWFmTmFtZSkpIHsKICAgICAgICAgICAgICAgICAgICAgICAgICAgIGlmKCFzc3Muc2hlZXRSZWdpc3RlcmVkKGZpbGVVUkksIHNzcy5VU0VSX1NIRUVUKSkKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICBzc3MubG9hZEFuZFJlZ2lzdGVyU2hlZXQoZmlsZVVSSSwgc3NzLlVTRVJfU0hFRVQpOwogICAgICAgICAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgCiAgICAgICAgICAgICAgICBzZXRUaW1lb3V0KGZ1bmN0aW9uIGxvYWRYVUwoKSB7CiAgICAgICAgICAgICAgICAgICAgaWYoeHVsRmlsZXMubGVuZ3RoID4gMCkgewogICAgICAgICAgICAgICAgICAgICAgICBkb2N1bWVudC5sb2FkT3ZlcmxheSh4dWxGaWxlcy5zaGlmdCgpLCBudWxsKTsKICAgICAgICAgICAgICAgICAgICAgICAgc2V0VGltZW91dChsb2FkWFVMLCA1KTsKICAgICAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICB9LCAwKTsKICAgICAgICAgICAgXV0+PC9jb25zdHJ1Y3Rvcj4KICAgICAgICA8L2ltcGxlbWVudGF0aW9uPgogICAgPC9iaW5kaW5nPgo8L2JpbmRpbmdzPgo=); }
EOF

    # userjs_customization: dark scrollbars
    sys::Write --append <<EOF "$defaultProfile/chrome/userjs_customization/scrollbars.as.css"
resizer, scrollcorner {
    background-color: transparent !important;
    -moz-appearance: none !important;
}

scrollbar, slider
{
    -moz-appearance: none !important;
}

scrollbar[orient="vertical"] {
  min-width: 7px !important;
  max-width: 7px !important;
  margin-bottom: -1px !important;
  margin-right: 1px !important;

}
scrollbar[orient="horizontal"] {
  min-height: 7px !important;
  max-height: 7px !important;
}

scrollbar[orient='vertical'] >  slider { max-width: 7px !important; }
scrollbar[orient='horizontal'] > slider { min-width: 20px !important }

scrollbar > slider, html scrollbar > slider
{
    background-color: #191817; /* DARK READER */
    /* GNOS: background-color: #$THEME_COLOR_BACKGD_HEX; */
}
body scrollbar > slider
{
    background-color: transparent;
}

scrollbar > slider > thumb
{
    -moz-appearance: none !important;
    border: 0 !important;
    border-radius: 10px !important;
    background-color: #$THEME_COLOR_SELECT_HEX !important;
}
scrollbar > slider > thumb:-moz-any(:hover, :active)
{
    background-color: #$THEME_COLOR_HOTHOT_HEX !important;
}
EOF


    sys::Write --append <<EOF "$userchrome"
/* Theming */
#nav-bar {
    background-color: #242220 !important;
}
vbox#sidebar-box.chromeclass-extrachrome {
    border-right: 0!important;
}
#urlbar, #searchbar .searchbar-textbox, .findbar-textbox, #sidebar-box
{
    background-color: #242220 !important;
    border: 0 !important;
}
#urlbar:hover, #searchbar .searchbar-textbox:hover, .findbar-textbox:hover
{
  background-color: #302e2c !important;
}
#urlbar[focused], #searchbar .searchbar-textbox[focused="true"], .findbar-textbox[focused]
{
  background-color: #174d8d !important;
  color: white !important;

  box-shadow: none !important;
}
#urlbar[focused] *::-moz-selection, #searchbar .searchbar-textbox[focused="true"] *::-moz-selection, .findbar-textbox[focused] *::-moz-selection
{
  background-color: white !important;
  color: #174d8d !important;
}

*|*:root {
  --in-content-page-background: #181614 !important;
}

:root {
  --arrowpanel-background: #242220 !important;
  --arrowpanel-color: #c0c0c0 !important;
  --arrowpanel-border-color: transparent !important;

  --theme-body-color: #c0c0c0 !important;
  --theme-body-color-alt: #c0c0c0 !important;
  --theme-content-color1: #c0c0c0 !important;

  --theme-body-background: #181614 !important;
  --theme-sidebar-background: #181614 !important;

  --theme-tab-toolbar-background: #242220 !important;
  --theme-toolbar-background: #242220 !important;

  --theme-selection-background: #174d8d !important;
  --theme-selection-background-semitransparent: #174d8d80 !important;
  --theme-selection-color: white !important;
  --theme-splitter-color: transparent !important;
}

/* Sidebar width */
#sidebar
{
  max-width: none !important;
  min-width: 48px !important;
}

EOF

    sys::Write --append <<EOF "$userchrome"
/* SRC: https://github.com/Aris-t2/CustomCSSforFx/blob/master/classic/css/generalui/findbar_show_full_quickfindbar.css */

label.findbar-find-fast{
  visibility: collapse !important;
}

label.found-matches,
.findbar-find-status,
.findbar-find-previous,
.findbar-find-next,
.findbar-button {
  display: block !important;
  visibility: visible !important;
}

.findbar-find-previous[disabled]:active,
.findbar-find-next[disabled]:active {
  background: rgba(23,50,76,.2) !important;
  box-shadow: 0 1px 2px rgba(10,31,51,.2) inset !important;
}

.findbar-find-previous,
.findbar-find-previous[disabled]:active {
  border: 1px solid ThreeDShadow !important;
}

/* https://github.com/Aris-t2/CustomCSSforFx/blob/master/classic/css/generalui/searchbar_go_button_hidden.css */
/* remove search go button */
.searchbar-textbox .search-go-button {
  visibility: hidden !important;
}

/* SRC: https://github.com/Aris-t2/CustomCSSforFx/blob/master/classic/css/generalui/searchbar_popup_engines_show_labels.css */

/* catch all cases 'manually' */
#PopupSearchAutoComplete .search-panel-tree[height="180"]:not([collapsed="true"]) {
  min-height: 180px !important;
}
#PopupSearchAutoComplete .search-panel-tree[height="162"]:not([collapsed="true"]) {
  min-height: 162px !important;
}
#PopupSearchAutoComplete .search-panel-tree[height="144"]:not([collapsed="true"]) {
  min-height: 144px !important;
}
#PopupSearchAutoComplete .search-panel-tree[height="126"]:not([collapsed="true"]) {
  min-height: 126px !important;
}
#PopupSearchAutoComplete .search-panel-tree[height="108"]:not([collapsed="true"]) {
  min-height: 108px !important;
}
#PopupSearchAutoComplete .search-panel-tree[height="90"]:not([collapsed="true"]) {
  min-height: 90px !important;
}
#PopupSearchAutoComplete .search-panel-tree[height="72"]:not([collapsed="true"]) {
  min-height: 72px !important;
}
#PopupSearchAutoComplete .search-panel-tree[height="54"]:not([collapsed="true"]) {
  min-height: 54px !important;
}
#PopupSearchAutoComplete .search-panel-tree[height="36"]:not([collapsed="true"]) {
  min-height: 36px !important;
}
#PopupSearchAutoComplete .search-panel-tree[height="18"]:not([collapsed="true"]) {
  min-height: 18px !important;
}

#PopupSearchAutoComplete .search-panel-one-offs .searchbar-engine-one-off-item {
  -moz-appearance:none !important;
  min-width: 0 !important;
  width: 100% !important;
  border: unset !important;
  height: 22px !important;
}

#PopupSearchAutoComplete .search-panel-one-offs .searchbar-engine-one-off-item:not([tooltiptext]) {
  display: none !important;
}

#PopupSearchAutoComplete .search-panel-one-offs .searchbar-engine-one-off-item .button-box{
  position: absolute !important;
  -moz-padding-start: 4px !important;
  margin-top: 3px !important;
}

#PopupSearchAutoComplete .search-panel-one-offs .searchbar-engine-one-off-item::after {
  -moz-appearance: none !important;
  display: inline !important;
  content: attr(tooltiptext) !important;
  position: relative !important;
  top: -9px !important;
  -moz-padding-start: 24px !important;
  min-width: 0 !important;
  width: 100% !important;
  white-space: nowrap !important;
}


/* SRC: https://github.com/Aris-t2/CustomCSSforFx/blob/master/classic/css/locationbar/ac_popup_title_and_url_50percent_width.css */


/* To hide search engines at popups bottom open 'about:config' and set ************
** browser.urlbar.oneOffSearches to 'false' *************************************/

/* remove unneeded padding around results */
#PopupAutoCompleteRichResult .autocomplete-richlistbox {
  padding: 0 !important;
}

/* make sure there is no unneeded space before results (Fx58+) */
#PopupAutoCompleteRichResult .autocomplete-richlistitem {
  -moz-margin-start: 0 !important;
  -moz-padding-start: 0 !important;
}

/* make sure there is no unneeded space before results (Fx57+) */
#PopupAutoCompleteRichResult .autocomplete-richlistitem spacer{
  display: none !important;
}

/* remove separator between title and url */
#PopupAutoCompleteRichResult .autocomplete-richlistitem .ac-separator {
  display: none !important;
}

/* calculate width of title and url: width = 1/2 * (window size - 100px) */
#PopupAutoCompleteRichResult .autocomplete-richlistitem .ac-title-text,
#PopupAutoCompleteRichResult .autocomplete-richlistitem .ac-url-text {
  min-width: calc((100vw - 100px)/2) !important;
  width: calc((100vw - 100px)/2) !important;
}

/* fix large space issue at items end */
#PopupAutoCompleteRichResult[autocompleteinput="urlbar"]  .autocomplete-richlistitem {
  border-inline-end: 0px solid transparent !important;
}

/* do not hide heuristic/actiontype url item */
#PopupAutoCompleteRichResult[autocompleteinput="urlbar"] .autocomplete-richlistitem[actiontype="searchengine"] .ac-action {
  visibility: visible !important;
  display: inherit !important;
}


EOF

    sys::Write --append <<EOF "$defaultPrefs"
/* Fix dark GTK theme */
user_pref("widget.content.gtk-theme-override", "Adwaita");
EOF

}



firefox_60_feat::Privacy()
{
    firefox::AddExtensionByName "$defaultExts" append-domain "{462b2b0a-87e2-4da8-8c79-c2701a3a1d5b}"

    firefox::AddExtensionByName "$defaultExts" ublock-origin
    # TODO firefox::AddBlocklistByUrl "Name" "http://url"

    firefox::AddExtensionByName "$defaultExts" google-search-link-fix
    # TODO FIND ALT firefox::AddExtensionByName "$defaultExts" no-google-analytics
    firefox::AddExtensionByName "$defaultExts" bloody-vikings


    # EXT decentraleyes
    firefox::AddExtensionByName "$defaultExts" decentraleyes
#     sys::Write --append <<EOF "$defaultPrefs"
# /* decentraleyes */
# user_pref("extensions.jid1-BoFifL9Vbdl2zQ@jetpack.showReleaseNotes", true);
# EOF

    # EXT no-canvas-fingerprinting
    firefox::AddExtensionByName "$defaultExts" no-canvas-fingerprinting

    # EXT self-destructing-cookies-webex
    firefox::AddExtensionByName "$defaultExts" self-destructing-cookies-webex "{ff257424-87c5-46d1-bebd-f45cc8d2a4bf}"

    # TODO ANTI_leaks cfg

    # TOCHECK https://addons.mozilla.org/en-US/firefox/addon/redirectbypasser REPLACE clean-links
}



firefox_60_feat::Flash()
{
    # local defaultProfile=$1
    # local defaultPrefs="$defaultProfile/prefs.js"

    sys::Write --append <<EOF "$defaultPrefs"
/* flash */
user_pref("plugin.state.flash", 1);
EOF

    # TIP bookmarks
    # General Storage Settings
    # http://www.macromedia.com/support/documentation/en/flashplayer/help/settings_manager03.html
    # Site-Specific Storage Settings
    # http://www.macromedia.com/support/documentation/en/flashplayer/help/settings_manager07.html

}



firefox_60_feat::Ui()
{
    # TODO MORE FF UI EXT
    # https://addons.mozilla.org/en-US/firefox/addon/open-with
    # https://addons.mozilla.org/en-US/firefox/addon/no-dotted-border/
    # https://addons.mozilla.org/en-US/firefox/addon/play-pause/
    # https://addons.mozilla.org/en-US/firefox/addon/tabflasher

    sys::Write --append <<EOF "$defaultPrefs"
/* UI */
user_pref("browser.uiCustomization.state", '$(
    cat <<EOJ | sed -E 's/^\s*//' | tr --delete '\n'
{
  "currentVersion": 14,
  "dirtyAreaCache": [
    "widget-overflow-fixed-list",
    "PersonalToolbar",
    "nav-bar",
    "TabsToolbar",
    "toolbar-menubar"
  ],
  "newElementCount": 4,
  "placements": {
    "PersonalToolbar": [],
    "TabsToolbar": [
      "tabbrowser-tabs",
      "new-tab-button",
      "alltabs-button"
    ],
    "nav-bar": [
      "back-button",
      "forward-button",
      "stop-reload-button",
      "urlbar-container",
      "search-container",
      "addon_darkreader_org-browser-action",
      "treestyletab_piro_sakura_ne_jp-browser-action",
      "downloads-button",
      "library-button"
    ],
    "toolbar-menubar": [
      "menubar-items",
      "customizableui-special-spring8",
      "personal-bookmarks"
    ],
    "widget-overflow-fixed-list": [
      "ublock0_raymondhill_net-browser-action",
      "_ff257424-87c5-46d1-bebd-f45cc8d2a4bf_-browser-action",
      "_canvas-shadow-browser-action",
      "jid1-bofifl9vbdl2zq_jetpack-browser-action",
      "bloodyvikings_ffs_bplaced_net-browser-action",
      "_48748554-4c01-49e8-94af-79662bf34d50_-browser-action",
      "_c2c003ee-bd69-42a2-b0e9-6f34222cb046_-browser-action",
      "_7a7a4a92-a2a0-41d1-9fd7-1e92480d612d_-browser-action",
      "_f73df109-8fb4-453e-8373-f59e61ca4da3_-browser-action",
      "tab-session-manager_sienori-browser-action",
      "searchsite-we_dw-dev-browser-action"
    ]
  },
  "seen": [
    "autocopyselection2clipboard_dook-browser-action",
    "rester_kuehle_me-browser-action",
    "_c2c003ee-bd69-42a2-b0e9-6f34222cb046_-browser-action",
    "_canvas-shadow-browser-action",
    "bloodyvikings_ffs_bplaced_net-browser-action",
    "jid1-bofifl9vbdl2zq_jetpack-browser-action",
    "ublock0_raymondhill_net-browser-action",
    "_95322c08-05ff-4f3c-85fd-8ceb821988dd_-browser-action",
    "_f73df109-8fb4-453e-8373-f59e61ca4da3_-browser-action",
    "developer-button",
    "webide-button",
    "addon_darkreader_org-browser-action",
    "_ff257424-87c5-46d1-bebd-f45cc8d2a4bf_-browser-action",
    "treestyletab_piro_sakura_ne_jp-browser-action",
    "tab-session-manager_sienori-browser-action",
    "_7a7a4a92-a2a0-41d1-9fd7-1e92480d612d_-browser-action",
    "_d9f1a12e-9dbb-4782-bf00-5535e3026bb4_-browser-action",
    "jid1-tsgsxbhncspbwq_jetpack-browser-action",
    "jid1-kkzogwgsw3ao4q_jetpack-browser-action",
    "_16a49f65-1369-4839-a5ef-db2581e08b16_-browser-action"
  ]
}
EOJ
)');
EOF


    ###########
    # ui tabs #
    ###########

    sys::Write --append <<EOF "$defaultPrefs"
/* legacy tabmix */
user_pref("browser.uidensity", 1);
user_pref("browser.ctrlTab.previews", true);
user_pref("browser.link.open_newwindow", 3);
user_pref("browser.link.open_newwindow.override.external", -1);
user_pref("browser.link.open_newwindow.restriction", 0);
user_pref("browser.search.context.loadInBackground", false);
user_pref("browser.search.openintab", true);
user_pref("browser.urlbar.openintab", true);
user_pref("browser.tabs.animate", false);
user_pref("browser.tabs.loadBookmarksInTabs", true);
user_pref("browser.tabs.closeWindowWithLastTab", false);
user_pref("browser.tabs.insertRelatedAfterCurrent", true);
user_pref("browser.tabs.loadBookmarksInBackground", false);
user_pref("browser.tabs.loadDivertedInBackground", false);
user_pref("browser.tabs.loadInBackground", true);
user_pref("browser.tabs.warnOnClose", true);
user_pref("browser.warnOnQuit", true);
user_pref("browser.zoom.full", false);
user_pref("toolkit.scrollbox.clickToScroll.scrollDelay", 150);
user_pref("toolkit.scrollbox.smoothScroll", true);
EOF


    # EXT treestyletab
    if [[ $browser == firefox-esr ]] ; then
        # DEV TST 2.8 requires FF65
        firefox::AddExtensionByUrl "$defaultExts" \
            https://addons.mozilla.org/firefox/downloads/file/1690540/tree_style_tab-2.7.23-fx.xpi
    else
        firefox::AddExtensionByName "$defaultExts" tree-style-tab
    fi
    sys::Write --append <<EOF "$defaultProfile/browser-extension-data/treestyletab@piro.sakura.ne.jp/storage.js"
{
  "animation": false,
  "autoCollapseExpandSubtreeOnAttach": false,
  "autoCollapseExpandSubtreeOnSelect": false,
  "cachedExternalAddons": [],
  "context_closeOthers": true,
  "insertNewChildAt": -1,
  "notifiedFeaturesVersion": 3,
  "requestingPermissions": null,
  "showNewTabActionSelector": false,
  "style": "vertigo",
  "userStyleRules": "/* Theming: Active tab */\n.tab.active {\n  --tab-surface: #$THEME_COLOR_SELECT_HEX;\n  --tab-text: white;\n}\n\n/* Show title of unread tabs with red and italic font */\n.tab.unread .label-content {\n  font-style: normal !important;\n  color: #$THEME_COLOR_HOTHOT_HEX !important;\n}\n\n/* Hide the \"new tab\" button at the bottom edge of the tab bar #1591 */\n.newtab-button-box {\n  display: none;\n}\n#tabbar {\n  bottom: 0 !important; /* Eliminate dead space on bottom */\n}",
  "warnOnCloseTabs": false
}
EOF

# TOCHECK Show counter vs Hidden .newtab-button-box
# #tabbar {
#   counter-reset: vtabs atabs tabs;
#   /* vtabs tracks visible tabs, atabs tracks active tabs, tabs tracks all tabs */
# }
# .tab:not(.collapsed):not(.discarded) {
#   counter-increment: vtabs atabs tabs;
# }
# .tab:not(.collapsed) {
#   counter-increment: vtabs tabs;
# }
# .tab:not(.discarded) {
#   counter-increment: atabs tabs;
# }
# .tab {
#   counter-increment: tabs;
# }
#
# .newtab-button::after {
#   content: var(--tab-count-text);
#   pointer-events: none;
#   position: absolute;
#   left: 0.5em;
#   /* TST 2.4.0 - Fix for Issue #1664 */
#   background: transparent !important;
#   mask: none !important;
# }
#
# .newtab-button {
#   --tab-count-text: counter(atabs) "/" counter(tabs) " tabs";
# }
#
# .newtab-button-box {
#   position: fixed;
#   bottom: 0;
#   left: 0;
#   right: 0;
#   height: 20px;
# }
# #tabbar {
#   bottom: 20px !important;
# }

    local userchrome="$defaultProfile/chrome/userChrome.css"
       [[ -f "$defaultProfile/chrome/ShadowFox_customization/userChrome_customization.css" ]] \
    && userchrome="$defaultProfile/chrome/ShadowFox_customization/userChrome_customization.css"
    sys::Write --append <<EOF "$userchrome"
/* Hide horizontal tabs at the top of the window #1349 */
#main-window[tabsintitlebar="true"]:not([extradragspace="true"]) #TabsToolbar {
  opacity: 0;
  pointer-events: none;
}
#main-window:not([tabsintitlebar="true"]) #TabsToolbar {
    visibility: collapse !important;
}

/* Hide the "Tree Style Tab" header at the top of the sidebar - For only Tree Style Tab sidebar #1397 */
#sidebar-box[sidebarcommand="treestyletab_piro_sakura_ne_jp-sidebar-action"] #sidebar-header {
  display: none;
}

EOF

    firefox::AddExtensionByName "$defaultExts" auto-tab-discard
    sys::Write --append <<EOF "$defaultProfile/browser-extension-data/{c2c003ee-bd69-42a2-b0e9-6f34222cb046}/storage.js"
{"pinned":true,"faqs":false,"favicon":false}
EOF


    #############
    # clipboard #
    #############

    firefox::AddExtensionByName "$defaultExts" autocopyselection2clipboard
    sys::Write --append <<EOF "$defaultProfile/browser-extension-data/autocopyselection2clipboard@dook/storage.js"
{"site":[{"url":"*","copyTextFormat":"4","deleteEmptyLines":true,"inputFields":false,"keyboardSelection":true,"copyProtectionBreak":false,"middleClickPaste":true,"copyImageText":false,"copyImageByClick":false,"copyLinkByClick":false,"trim":true,"unselect":false,"copyNotification":false,"enableCopyTemplate":false,"copyTemplate":"<TEXT>\n<DATE> <TIME> <TITLE> <URL>"}],"useDocumentUrl4Frame":true,"debug":false,"selectionChangeControl":true,"manualFrameControl":true,"copyDelay":"10","menu":true,"hotkeys":true,"iconControl":true,"scriptID":"1557267064940moz-extension://d985654e-1a67-400c-893c-5965a239578f/options.html"}
EOF


    ##################
    # ui enhancement #
    ##################

    # TODO_REPLACE firefox::AddExtensionByName "$defaultExts" findbar-tweak

    # EXT flagfox
    firefox::AddExtensionByName "$defaultExts" flagfox
    SetFlagfoxActions ()
    {
        local dst=$1
        shift

        # TIP: {fullUrl} {IPaddress} {domainName}
        [[ $(($#%2)) -eq 0 ]] || return 1

        local str='{"warn.stale":"disabled","warn.tld":"disabled","warn.proxy":"disabled","useractions":"[\"Geotool\",\"WolframAlpha\",\"Whois\",\"Alexa\",\"WOT Scorecard\",\"Virus Scan\",\"Check Server Status\",\"Google\",\"Google Translate\",\"Google Cache\",\"Internet Archive\",\"W3C Validator\",\"W3C CSS Validator\",\"Validate.nu\",\"WAVE a11y Check\",\"SSL Server Test\",\"SSL Checker\",\"Header Check\",\"URL Parser\",\"Ping\",\"Traceroute\",\"Netcraft\",\"IntoDNS\",\"My Info\",\"Bit.ly URL\",\"Tiny URL\",\"is.gd URL\",\"Copy IP\",\"Copy Server Info\",\"Wikipedia: Country\",\"Wikipedia: Domain\",\"Wikipedia: TLD\",\"Page Metadata\"'
        while [[ $# -ne 0 ]] ; do
            str="$str,[\\\"$1\\\",1,0,0,\\\"$2\\\"]"
            shift 2
        done
        str="$str]\"}"

        sys::Write "$dst" <<<"$str"
    }
    SetFlagfoxActions $defaultProfile/browser-extension-data/{1018e4d6-728f-4b20-ad56-37578a4de76b}/storage.js \
        'PAGE Archive'      'https://web.archive.org/web/*/{fullURL}' \
        'PAGE Cache'        'https://webcache.googleusercontent.com/search?q=cache:{fullURL}' \
        'PAGE EN'           'https://translate.google.com/translate?sl=auto&tl=en&u={fullUrl}' \
        'PAGE FR'           'https://translate.google.com/translate?sl=auto&tl=fr&u={fullUrl}' \
         \
        'IP Copy'           'copystring:{IPaddress}' \
        'IP Geo'            'https://iplookup.flagfox.net/?ip={IPaddress}&host={domainName}' \
        'IP Ping'           'formfield:https://tools.keycdn.com/ping|hostname|{IPaddress}' \
        'IP Route'          'formfield:https://traceroute-online.com/mtr/|targetip|{IPaddress}' \
         \
        'DNS Copy'          'copystring:{domainName}' \
        'DNS Whois'         'https://whois.domaintools.com/{domainName}' \
        'DNS Graph'         'https://www.robtex.com/ip-lookup/{IPaddress}#ograph' \
        'SSL Test'          'https://www.ssllabs.com/ssltest/analyze.html?d={domainName}' \
         \
        'RANK Alexa'        'https://alexa.com/siteinfo/{domainName}' \
        'RANK Google'       'https://www.google.com/search?q=site:{domainName}' \
        'RANK Netcraft'     'https://toolbar.netcraft.com/site_report?url={domainName}' \
        'RANK WOT'          'https://www.mywot.com/scorecard/{domainName}' \
         \
        'UA IP'             'https://wtfismyip.com/' \
        'UA Fingerprint'    'https://panopticlick.eff.org/tracker?aat=1' \
        'UA Leaks'          'https://browserleaks.com/ip' \
        'UA Speed'          'https://speedtest.net/' \
        'UA SSL'            'https://www.ssllabs.com/ssltest/viewMyClient.html'

        # 'TCP Scan'          'https://mxtoolbox.com/SuperTool.aspx?action=scan%3a{IPaddress}&run=toolpage' \
        # 'DNS Check'         'https://www.intodns.com/{baseDomainName}' \

        # TODO
        # SSL https://www.htbridge.com/ssl/
        # WHOIS http://www.kloth.net/services/whois.php
        # WHOIS http://allwhois.org/whois/suck.asia

    #
    firefox::AddExtensionByName "$defaultExts" tap-to-tab "{25fce1f7-7e05-43a2-829f-600293bc1b26}"

    # text-link
    firefox::AddExtensionByName "$defaultExts" text-link

    # TODO_REPLACE
    # firefox::AddExtensionByName "$defaultExts" re-start


    ##########
    # search #
    ##########


    # TODO_REPLACE firefox::AddExtensionByName "$defaultExts" searchwp
    # # firefox::AddExtensionByName "$defaultExts" searchbox-sync

    # TODO_REPLACE # EXT add-to-search-bar
    # firefox::AddExtensionByName "$defaultExts" add-to-search-bar

    # TOCHECK burning-moth-add-search

    # TODO_REPLACE # EXT add-opensearch-xml
    # firefox::AddExtensionByName "$defaultExts" add-opensearch-xml

    # TODO_REPLACE # EXT context-search
    # https://bugzilla.mozilla.org/show_bug.cgi?id=1352598
    # OLD firefox::AddExtensionByName "$defaultExts" context-search
    # ALT firefox::AddExtensionByName "$defaultExts" contextsearch-web-ext

    # # EXT scroll-search-engines
    # firefox::AddExtensionByName "$defaultExts" scroll-search-engines

    # google images
    firefox::AddExtensionByName "$defaultExts" canvas-google-images "{d9f1a12e-9dbb-4782-bf00-5535e3026bb4}"
    firefox::AddExtensionByName "$defaultExts" google-reverse-image-search

    # EXT search-site
    firefox::AddExtensionByName "$defaultExts" search-site-we
#     sys::Write --append <<EOF "$defaultPrefs"
# /* EXT search-site */
# user_pref("extensions.searchsite.hidecursor", true);
# user_pref("extensions.searchsite.legacydonotshow", true);
# user_pref("extensions.searchsite.legacyfirsttime", true);
# user_pref("extensions.searchsite.legacysecondtime", true);
# user_pref("extensions.searchsite.legacythirdtime", true);
# EOF


    ############
    # download #
    ############

# BUG: empty window
#     # EXT open-in-browser
#     firefox::AddExtensionByName "$defaultExts" open-in-browser
#     sys::Write --append <<EOF "$defaultProfile/handlers.json.iob"
# .mimeTypes += { "application/prs.oib-ask-once":{"action":0} }
# EOF
#     sys::Write --append <<EOF "$defaultProfile/browser-extension-data/openinbrowser@www.spasche.net/storage.js"
# {"override-download-type":true}
# EOF

}



firefox_60_feat::Content()
{

#     # CFG: Force our fonts
#     sys::Write --append <<EOF "$defaultPrefs"
# user_pref("browser.display.use_document_fonts", 0);
# user_pref("font.minimum-size.x-western", 14);
# user_pref("font.minimum-size.x-unicode", 14);
# EOF


    firefox::AddExtensionByName "$defaultExts" i-dont-care-about-cookies
    sys::Write --append <<EOF "$defaultPrefs"
/* EXT: i-dont-care-about-cookies */
user_pref("extensions.jid1-KKzOGWgsW3Ao4Q@jetpack.contextmenu", false); /* BUG NO EFFECT */
EOF
    # TODO integrate list into ublock-origin
    # https://www.i-dont-care-about-cookies.eu/abp/
    # TODO IMPL firefox::AddBlocklistByUrl "Name" "http://url"


    # TOCHECK
    # firefox::AddExtensionByName "$defaultExts" behind-the-overlay-revival
    # TODO ? "browser.pageActions.persistedActions"
    # JSON: add "_c0e1baea-b4cb-4b62-97f0-278392ff8c37_" to "idsInUrlbar"


    ##########
    # google #
    ##########


    # EXT searchpreview
    firefox::AddExtensionByName "$defaultExts" searchpreview
    sys::Write --append <<EOF "$defaultProfile/browser-extension-data/{EF522540-89F5-46b9-B6FE-1829E2B572C6}/storage.js"
{"insertpreviews":true,"insertranks":false}
EOF


    ###########
    # youtube #
    ###########


    # EXT YouTube Video and Audio Downloader
    firefox::AddExtensionByName "$defaultExts" youtube_downloader_webx "{f73df109-8fb4-453e-8373-f59e61ca4da3}"
    firefox_60::ShadowfoxExclude "{f73df109-8fb4-453e-8373-f59e61ca4da3}"

    # DEP: Native client
    local tempdir=$( mktemp -d )
    net::DownloadGithubLatestRelease andy-portmen/native-client '/linux\\.zip$' \
        $tempdir/linux.zip
    unzip $tempdir/linux.zip -d $tempdir
    sys::Chk
    chown -hR $user:$user $tempdir "$profileParent/.."
    pushd $tempdir/app
       sudo --set-home -u $user ../node/x64/node install.js --add_node --custom-dir=$userHome/.mozilla/ \
    || sudo --set-home -u $user ../node/x64/node install.js --add_node --custom-dir=$userHome/.mozilla/
    sys::Chk
    popd
    rm -rf $userHome/.config/{google-chrome,chromium,vivaldi}/NativeMessagingHosts/com.add0n.node.json
    rmdir $userHome/.config/{google-chrome,chromium,vivaldi}/NativeMessagingHosts/
    rmdir $userHome/.config/{google-chrome,chromium,vivaldi}/

    # DEP: ffmpeg
    if ! [[ -x "$userHome/.mozilla/com.add0n.node/ffmpeg" ]] ; then 
        net::DownloadGithubLatestRelease inbasic/ffmpeg '/ffmpeg-linux-x64$' \
            "$userHome/.mozilla/com.add0n.node/ffmpeg"
        chmod +x "$userHome/.mozilla/com.add0n.node/ffmpeg"
    fi

    # Config
    sys::Write <<EOF "$defaultProfile/browser-extension-data/{f73df109-8fb4-453e-8373-f59e61ca4da3}/storage.js"
{"version":"0.7.2","ffmpeg":"$userHome/.mozilla/com.add0n.node/ffmpeg","doMerge":true,"pretendHD":true,"remove":true,"toAudio":false,"toMP3":true,"opusmixing":true,"pattern":"[file_name].[extension]","savein":"","saveAs":false,"notification":true,"faqs":false,"commands":{"toAudio":"-loglevel error -i %input -acodec copy -vn %output","toMP3":"-loglevel error -i %input -q:a 0 %output","muxing":"-loglevel error -i %audio -i %video -acodec copy -vcodec copy %output"}}
EOF


    # EXT h264ify
    firefox::AddExtensionByName "$defaultExts"  h264ify "jid1-TSgSxBhncsPBWQ@jetpack"
    # TODO layers.acceleration.force-enabled=true

    firefox::AddExtensionByName "$defaultExts" autoplay-no-more "jid1-XQEcUtyD5PwB8w@jetpack"
    # TOCHECK ALT flashstopper

    firefox::AddExtensionByName "$defaultExts" youtubes-annotations-no-more
    # ALT youtube-zero-annotations
}



firefox_60_feat::Misc()
{

    # EXT gsconnect
    #    [[ "$UBUNTU_RELEASE" != "xenial" ]] \
    # && str::InList app::Android $INSTALL_BUNDLES \
    # && firefox::AddExtensionByName "$defaultExts" gsconnect
    # TODO uiCustomization

    # EXT tab-session-manager
    firefox::AddExtensionByName "$defaultExts" tab-session-manager
    sys::Write --append <<EOF "$defaultProfile/browser-extension-data/Tab-Session-Manager@sienori/storage.js"
{"Settings":{"ifSupportTst":true}}
EOF

}



firefox_60_feat::Dev()
{

    firefox::AddExtensionByName "$defaultExts" rester

    firefox::AddExtensionByName "$defaultExts" json-lite

}



firefox_60_feat::Tor()
{
    Meta --no-default true


    # Handle captchas for Cloudflare owned internet
    firefox::AddExtensionByName "$defaultExts" privacy-pass "{48748554-4c01-49e8-94af-79662bf34d50}"

    # searchengines
    firefox::AddSearchEngine 84531 "DuckDuck"


    # CONF
    sys::Write --append <<EOF "$defaultPrefs"
user_pref("network.dns.blockDotOnion", false);
user_pref("browser.search.defaultenginename", "DuckDuckGo");
user_pref("browser.startup.page", 1);
user_pref("browser.startup.homepage", "https://check.torproject.org/?lang=en_US");
user_pref("network.proxy.type", 1);
user_pref("network.proxy.socks", "127.0.0.1");
user_pref("network.proxy.socks_port", 9090);
user_pref("network.proxy.no_proxies_on", "");
user_pref("plugin.state.java", 0);
user_pref("plugin.state.flash", 0);
user_pref("plugin.state.libgnome-shell-browser-plugin", 0);
user_pref("media.peerconnection.enabled", false); // Disable WebRTC interfaces
user_pref("media.navigator.enabled", false);

/* FROM https://gitweb.torproject.org/tor-browser.git/tree/browser/app/profile/000-tor-browser.js?h=tor-browser-45.7.0esr-7.0-1 */

/* Disk activity: Disable Browsing History Storage */
user_pref("browser.privatebrowsing.autostart", true);
user_pref("browser.cache.disk.enable", false);
user_pref("browser.cache.offline.enable", false);
user_pref("dom.indexedDB.enabled", false); /* BREAKS MEGA.nz */
user_pref("permissions.memory_only", true);
user_pref("network.cookie.lifetimePolicy", 2);
user_pref("browser.download.manager.retention", 1);
user_pref("security.nocertdb", true);

/* Misc privacy: Disk */
user_pref("signon.rememberSignons", false);
user_pref("browser.formfill.enable", false);
user_pref("signon.autofillForms", false);
user_pref("browser.sessionstore.privacy_level", 2);
user_pref("media.cache_size", 0);

/* sync */
user_pref("services.sync.engine.addons", false);
user_pref("services.sync.engine.user_prefs", false);
user_pref("services.sync.engine.tabs", false);
//
user_pref("services.sync.engine.bookmarks", false);
user_pref("services.sync.engine.history", false);
user_pref("services.sync.engine.passwords", false);

/* https://blog.mozilla.org/addons/how-to-opt-out-of-add-on-metadata-updates/ */
user_pref("extensions.getAddons.cache.enabled", false);
user_pref("media.gmp-provider.enabled", false);
user_pref("media.gmp-manager.url.override", "data:text/plain,");

/* Prevent .onion fixups */
user_pref("browser.fixup.alternate.enabled", false);

/* Fingerprinting */
user_pref("webgl.min_capability_mode", true);
user_pref("webgl.disable-extensions", true);
user_pref("webgl.disable-fail-if-major-performance-caveat", true);
user_pref("dom.battery.enabled", false);
user_pref("gfx.downloadable_fonts.fallback_delay", -1);
user_pref("dom.enable_performance", false);
user_pref("browser.zoom.siteSpecific", false);
user_pref("dom.gamepad.enabled", false);
/* Disable video statistics fingerprinting vector (bug 15757) */
user_pref("media.video_stats.enabled", false);
/* Disable device sensors as possible fingerprinting vector (bug 15758) */
user_pref("device.sensors.enabled", false);
user_pref("dom.enable_resource_timing", false);
user_pref("dom.enable_user_timing", false);
user_pref("privacy.resistFingerprinting", true);
user_pref("dom.event.highrestimestamp.enabled", true);
/* Make Reader View users uniform if they really want to use that feature. See */
/* bug 18950 for more details. */
user_pref("browser.reader.detectedFirstArticle", true);

/* Third party stuff */
user_pref("network.http.spdy.enabled", false);
user_pref("network.http.spdy.enabled.", false);

/* WebIDE */
user_pref("devtools.webide.autoinstallADBHelper", false);
user_pref("devtools.webide.autoinstallFxdtAdapters", false);
user_pref("devtools.webide.enabled", false);
user_pref("devtools.debugger.chrome-debugging-host", "127.0.0.1");
user_pref("devtools.debugger.remote-host", "127.0.0.1");

user_pref("network.jar.block-remote-files", true);
user_pref("security.cert_pinning.enforcement_level", 2);

EOF
}



firefox_60_feat::Firejail ()
{
    # WORKAROUND https://github.com/netblue30/firejail/issues/1847
    sys::Write --append <<EOF "$defaultPrefs"
user_pref("media.cubeb.sandbox", false);
EOF

    cli::Firejail

    # create profile
    local browserName=${profileParent##*/}
    local fjProfile=$userHome/.config/firejail/"$browser-$user-$name".profile

    local cachePath
    case $browser in
        firefox)        cachePath="~/.cache/mozilla/$name" ;;
        firefox-esr)    cachePath="~/.cache/.mozilla/$name" ;;
        firefox-trunk)  cachePath="~/.cache/.mozilla/$browser-$name" ;;
        waterfox)       cachePath="~/.cache/.waterfox/$name" ;;
        palemoon)       cachePath="~/.cache/.moonchild productions/$name" ;;
        basilisk)       cachePath="~/.cache/.moonchild productions/$name" ;;
    esac

    local parentPath=~/${profileParent#$userHome/}
    local parentParentPath=${parentPath%/*}

    sys::Write <<EOF "$fjProfile" $user:$user
name $browser
noblacklist $parentParentPath
# include /etc/firejail/disable-mgmt.inc
# include /etc/firejail/disable-secret.inc
include /etc/firejail/disable-common.inc
include /etc/firejail/disable-devel.inc
include /etc/firejail/disable-programs.inc
include /etc/firejail/whitelist-common.inc
caps.drop all
# BUG crashes FF60
# seccomp
protocol unix,inet,inet6,netlink
netfilter
tracelog
# BUG crashes FF60
# shell none
nodvd
nogroups
noroot
notv
noexec ~
# noexec $HOME
noexec /tmp
disable-mnt
private-dev
# TODO private-bin
# TODO private-etc

# Prevent dbus, e helper
private-tmp
blacklist /usr/bin/dbus-launch

# Prevent mime discovery
blacklist /etc/mailcap
blacklist /usr/share/applications
blacklist /usr/local/share/applications
blacklist /usr/share/gnome/mime
blacklist /usr/local/share/mime
blacklist ~/.config/mimeapps.list
blacklist ~/.local/share/mime
blacklist /var/lib/snapd/desktop/mime
blacklist /var/lib/flatpak/exports/share/mime
blacklist ~/.local/share/flatpak/exports/share/mime

whitelist ~/Downloads
whitelist ~/.config/browser
whitelist $parentPath
whitelist $cachePath
EOF

    # Prevent application launch
    firefox_60::AddSchemeHandler file /bin/true "Don't launch from Firejail"

    # Enable flash
       str::InList Flash $features \
    && sys::Write --append <<'EOF' "$fjProfile"
whitelist ~/.macromedia
EOF

    # PATCH launcher
    sys::SedInline 's#^(FF_BRANDING=[^ ]+ exec)#\1 firejail --profile="'"$fjProfile"'"#' \
        "$shellLauncher"


    if str::InList Content $features ; then

        # bindmount
        sys::Write --append <<EOF "$fjProfile" $user:$user
whitelist $parentParentPath
whitelist $parentParentPath/native-messaging-hosts
whitelist $parentParentPath/com.add0n.node
EOF

    fi
}
