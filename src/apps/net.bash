########
# FUNC #  BUNDLES::NET
########



PACKAGES_NET="

    app::Gstm
    app::Hamachi_NONFREE

    app::Synergy
    app::Teamviewer_NONFREE
    app::Vnc

    app::Wireshark
    app::Zapproxy
    app::Zenmap
    "



app::Zenmap ()
{
    Meta --no-default true \
         --desc "Nmap GUI"

    apt::AddPackages zenmap
    gui::HideApps zenmap-root
    gui::AddAppFolder Net zenmap
    gui::SetAppIcon zenmap zenmap
    gui::SetAppProp zenmap Exec "/usr/bin/pkexec zenmap"
    gui::AddPkexecPolicy /usr/bin/zenmap org.nmap.zenmap
}



app::Synergy ()
{
    Meta --desc "Virtual KVM" \
         --no-default true

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then

        apt::AddPpaPackages jonathonf/synergy synergy

    else
        # BIONIC unavailable
        apt::AddPpaPackages --release xenial jonathonf/synergy synergy
    fi
    gui::SetAppIcon synergy synergy
    gui::AddAppFolder Net synergy
}



app::Zapproxy () # owasp zap attack proxy project
{
    Meta --no-default true \
         --desc "Man-in-the-middle proxy"

    local url=$(
          curl -sSL  "https://raw.githubusercontent.com/zaproxy/zap-admin/master/ZapVersions.xml" \
        | xmllint --xpath "string(/ZAP/core/linux/url)" /dev/stdin
        )

    net::DownloadUntarGzip "$url" /opt/

    # launcher
    sys::Write <<EOF /usr/local/share/applications/owaspzap.desktop
[Desktop Entry]
Name=Zap Proxy
Exec=/opt/ZAP_$( basename $( dirname "$url" ) )/zap.sh
Terminal=false
Type=Application
Icon=knetwalk
StartupWMClass=OWASP ZAP
EOF
    # TODO Icon= from /opt/ZAP_2.5.0/zap-2.5.0.jar#/resource/zap256x256.png
    gui::AddAppFolder Net owaspzap

    # TIP: Configure mitm SSL proxy CACERT
    # ZAP: Tools > Options > 'Dynamic SSL Certificates' [Save] to Downloads
    # Firefox: Preferences > Advanced > Certificates > [ViewCertificates] Authorities [Import...] X Trust
    # Firefox: Preferences > Advanced > Network Connection [Settings] X Manual: localhost 8080 X for all
    # ALT: Install Plug-n-Hack Addon
    # https://github.com/mozmark/ringleader/raw/master/fx_pnh.xpi
}



app::Gstm ()
{
    Meta --no-default true \
         --desc "Ssh tunnel manager"

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPackages gstm
    else
        apt::AddRemotePackages \
        "https://mirrors.kernel.org/ubuntu/pool/universe/g/gstm/gstm_1.2-8.1ubuntu1_amd64.deb"
    fi

    gui::SetAppIcon gstm hotwire-openssh
    gui::AddAppFolder Net gstm

    # TODO: ugly systray icon /usr/share/pixmaps/gstm/gSTM.xpm
}



app::Vnc ()
{
    Meta --desc "Remote desktop (vino+remmina)"

    # vino
    # TIP: systemctl --user start vino-server.service
    apt::AddPackages vino
    sys::Write <<EOF /usr/share/glib-2.0/schemas/$PRODUCT_NAME-vino.gschema.override
[org.gnome.Vino]
vnc-password='$( echo -n "s3cr3t" | base64 )'
authentication-methods=['none']
network-interface='lo'
prompt-enabled=false
EOF
# network-interface=''
# require-encryption=false
# [org.gnome.desktop.remote-access]
    glib-compile-schemas /usr/share/glib-2.0/schemas/
    gui::AddSystemdSwitch vnc vino-server.service 1 user=true


    # FIX /etc/xdg/autostart/vino-server.desktop
    sed -E 's#^OnlyShowIn=.*##' \
        /etc/xdg/autostart/vino-server.desktop \
        >$HOME/.config/autostart/vino-server.desktop
    chown 1000:1000 $HOME/.config/autostart/vino-server.desktop

    apt::AddPpaPackages remmina-ppa-team/remmina-next \
        remmina \
        remmina-plugin-nx \
        remmina-plugin-rdp \
        remmina-plugin-spice \
        remmina-plugin-vnc \
        remmina-plugin-xdmcp

    gui::AddAppFolder Net org.remmina.Remmina

    # TOCHECK autostart: $HOME/.config/autostart/remmina-applet.desktop

    # TODO fail2ban for VNC rules
}



app::Hamachi_NONFREE ()
{
    Meta --desc "Hosted VPN service (LogMeIn)" \
         --no-default true

    apt::AddRemotePackages \
        "https://www.vpn.net/installers/logmein-hamachi_2.1.0.198-1_amd64.deb"
        # "https://www.vpn.net/installers/logmein-hamachi_2.1.0.174-1_amd64.deb"

    # WORKAROUND hamachid runs during install
    systemctl stop logmein-hamachi
    systemctl mask logmein-hamachi
    killall hamachid

    gui::AddSystemdSwitch "hamachi" logmein-hamachi 1

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages webupd8team/haguichi haguichi
    else
        apt::AddPpaPackages --release xenial webupd8team/haguichi haguichi
        # apt::AddRemotePackages \
        #     "https://launchpad.net/~webupd8team/+archive/ubuntu/haguichi/+files/haguichi_1.3.8~ubuntu16.04.1_arm64.deb"
    fi

    mv /etc/xdg/autostart/haguichi-autostart.desktop{,.DISABLED}
    gui::AddAppFolder Net haguichi com.github.ztefn.haguichi
}



app::Teamviewer_NONFREE ()
{
    Meta --desc "Remote desktop (TeamViewer)"

    apt::AddRemotePackages \
        "https://download.teamviewer.com/download/linux/teamviewer_amd64.deb"

    # # BUG cacert: Comodo intermediate CA cert not found
    # # WORKAROUND
    # local tmpdir=$( mktemp -d )
    # net::Download \
    #     https://support.comodo.com/index.php?/Knowledgebase/Article/GetAttachment/970/821027 \
    #     $tmpdir/comodo.crt
    # net::Download --opts "--cacert $tmpdir/comodo.crt" \
    #     "https://download.teamviewer.com/download/linux/teamviewer_amd64.deb" \
    #     $tmpdir/tv.deb
    # apt::AddLocalPackages $tmpdir/tv.deb
    # rm -rf $tmpdir

    gui::SetAppName com.teamviewer.TeamViewer TeamViewer
    gui::SetAppIcon com.teamviewer.TeamViewer teamviewer
    gui::SetAppProp com.teamviewer.TeamViewer StartupWMClass TeamViewer
    gui::AddAppFolder Net com.teamviewer.TeamViewer
    

    # Mask systemd service
    mv /etc/systemd/system/teamviewerd.service /lib/systemd/system/
    systemctl mask teamviewerd

    # Menu toggle
    gui::AddSystemdSwitch teamviewer teamviewerd 1 post_start=teamviewer

    # THEMING
    sys::Write <<EOF $HOME/.config/teamviewer/client.conf
TeamViewer User Settings
# It is not recommended to edit this file manually


[int32] ColorScheme = 2

EOF

    RegisterPostInstall post::Teamviewer_NONFREE 60
}



post::Teamviewer_NONFREE ()
{
   sudo --set-home -u \#1000 \
       xauth generate :0 . trusted
}



app::Wireshark ()
{
    Meta --no-default true \
         --desc "Packet analyzer"

    apt::AddSelection "wireshark-common wireshark-common/install-setuid boolean true"

    apt::AddPackages wireshark wireshark-gtk

    gui::AddAppFolder Net wireshark wireshark-gtk
    gui::SetAppName wireshark-gtk "Wireshark"


    adduser $( id -nu 1000 ) wireshark

    # TODO more dissectors

# TODO THEMING .config/wireshark/preferences
# gui.layout_type: 4
# gui.qt.font_name: Hack,11,-1,5,50,0,0,0,0,0
# # gui.gtk2.font_name: Hack 11
# gui.ignored_frame.bg: 212121
# gui.stream.client.fg: ffaaff
# gui.stream.client.bg: 550000
# gui.stream.server.fg: 8bffd5
# gui.stream.server.bg: 00007f
# gui.color_filter_bg.valid: 005500
# gui.color_filter_bg.invalid: 550000
# gui.color_filter_bg.deprecated: aa5500

# TODO colorfilters
#     sys:Write <<EOF /home/user/.config/wireshark/colorfilters
# @Bad TCP@tcp.analysis.flags && !tcp.analysis.window_update@[4626,10023,11822][63479,34695,34695]
# @HSRP State Change@hsrp.state != 8 && hsrp.state != 16@[4626,10023,11822][65535,64764,40092]
# @Spanning Tree Topology  Change@stp.type == 0x80@[4626,10023,11822][65535,64764,40092]
# @OSPF State Change@ospf.msg != 1@[4626,10023,11822][65535,64764,40092]
# @ICMP errors@icmp.type eq 3 || icmp.type eq 4 || icmp.type eq 5 || icmp.type eq 11 || icmpv6.type eq 1 || icmpv6.type eq 2 || icmpv6.type eq 3 || icmpv6.type eq 4@[4626,10023,11822][47031,63479,29812]
# @ARP@arp@[8481,8481,8481][21845,43690,65535]
# @ICMP@icmp || icmpv6@[8481,8481,8481][21845,21845,65535]
# @TCP RST@tcp.flags.reset eq 1@[42148,0,0][65535,64764,40092]
# @SCTP ABORT@sctp.chunk_type eq ABORT@[42148,0,0][65535,64764,40092]
# @TTL low or unexpected@( ! ip.dst == 224.0.0.0/4 && ip.ttl < 5 && !pim && !ospf) || (ip.dst == 224.0.0.0/24 && ip.dst != 224.0.0.251 && ip.ttl != 1 && !(vrrp || carp))@[42148,0,0][60652,61680,60395]
# @Checksum Errors@eth.fcs.status=="Bad" || ip.checksum.status=="Bad" || tcp.checksum.status=="Bad" || udp.checksum.status=="Bad" || sctp.checksum.status=="Bad" || mstp.checksum.status=="Bad" || cdp.checksum.status=="Bad" || edp.checksum.status=="Bad" || wlan.fcs.status=="Bad" || stt.checksum.status=="Bad"@[4626,10023,11822][63479,34695,34695]
# @SMB@smb || nbss || nbns || nbipx || ipxsap || netbios@[8481,8481,8481][21845,65535,65535]
# @HTTP@http || tcp.port == 80 || http2@[8481,8481,8481][21845,43690,65535]
# @IPX@ipx || spx@[65535,58339,58853][4626,10023,11822]
# @DCERPC@dcerpc@[51143,38807,65535][4626,10023,11822]
# @Routing@hsrp || eigrp || ospf || bgp || cdp || vrrp || carp || gvrp || igmp || ismp@[8481,8481,8481][43690,21845,65535]
# @TCP SYN/FIN@tcp.flags & 0x02 || tcp.flags.fin == 1@[15163,15163,15163][18504,40606,47802]
# @TCP@tcp@[8481,8481,8481][21845,65535,32639]
# @UDP@udp@[0,65535,32639][4626,10023,11822]
# @Broadcast@eth[0] & 1@[8481,8481,8481][47802,48573,46774]
# EOF

}
