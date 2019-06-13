#   ▞▀▖▌ ▌▜▘  ▛▀▖   ▗
#   ▌▄▖▌ ▌▐   ▌ ▌▙▀▖▄▌ ▌▞▀▖▙▀▖▞▀▘
#   ▌ ▌▌ ▌▐   ▌ ▌▌  ▐▐▐ ▛▀ ▌  ▝▀▖
#   ▝▀ ▝▀ ▀▘  ▀▀ ▘  ▀▘▘ ▝▀▘▘  ▀▀




GetUbuntuDrivers () # $1:ONLY_FREE $2:BLACKLIST
{
    ubuntu-drivers devices | awk -v free=$1 -v blacklist="$2" '
BEGIN { split(blacklist,b1); for (k in b1) b2[b1[k]]=1 }

($1=="==") { if (NR>1) commit(); delete a; c=0; }

( ( $1=="driver" ) && ( ($3 in b2) == 0) ) {
    if ($0~/recommended/)
    {
        if ($0~/non-free/) a["nr"]=$3;
        else               a["fr"]=$3;
    }
    else
    {
        if ($0~/non-free/) a["nu"]=$3;
        else               a["fu"]=$3;
    }
    c=c+1;
}

END { commit(); for (k in d) print k; }

function commit() {
    if (c==0) return;
    if (free=="1")
    {
        if      (a["fr"]) d[a["fr"]]=1;
        else if (a["fu"]) d[a["fu"]]=1;
    }
    else
    {
        if      (a["fr"]) d[a["fr"]]=1;
        else if (a["nr"]) d[a["nr"]]=1;
        else if (a["fu"]) d[a["fu"]]=1;
        else if (a["nu"]) d[a["nu"]]=1;
    }
}
'
}


InstallDrivers ()
{
    # Ubuntu drivers
    apt::AddPackages ubuntu-drivers-common

    ubuntu-drivers devices # DBG

    local drv_black drv_force
    local ubu_force ubu_black=" virtualbox-guest virtualbox-guest-x11 virtualbox-guest-dkms virtualbox-guest-x11-hwe virtualbox-guest-dkms-hwe"

    for i in $INSTALL_DRIVERS; do
        if [[ $i =~ ^drv:: ]] ; then
            drv_force="$drv_force $i"
        elif [[ $i =~ ^-drv:: ]] ; then
            drv_black="$drv_black $i"
        elif [[ $i =~ ^- ]] ; then
            ubu_black="$ubu_black $i"
        else
            ubu_force="$ubu_force $i"
        fi
    done
    ubu_force=${ubu_force:1}
    ubu_black=${ubu_black:1}
    drv_black=${drv_black:1}
    drv_force=${drv_force:1}

    # Ubuntu Drivers
    local ubu_probe=$( GetUbuntuDrivers "$INSTALL_FREE" "$ubu_black" )
    [[ -n "$ubu_force$ubu_probe" ]] && apt::AddPackages $ubu_force $ubu_probe
    gui::FixDkmsAllModules

    # Custom Drivers
    local drvs
    for drv in $( sys::GetFuncsNamesByRegex '^drv::' | cut -d':' -f3- ) ; do
        if  ! str::InList $drv $drv_black \
        && (  str::InList $drv $drv_force \
           || (  ! [[ "$( GetFuncMetaByKey "drv::$drv" "no-default" )" == "true" ]] \
              && ! ( [[ "$INSTALL_FREE" == 1 ]] && [[ $drv != *_NONFREE ]]  )       \
              ) \
           ) ; then
            drv::$drv
        fi
    done

}



########
# FUNC #  BUNDLES::DRIV
########


drv::VmwareTools ()
{
    Meta --desc "VmWare Guest"

    grep -q VMware /proc/bus/input/devices || return

    apt::AddPackages open-vm-tools open-vm-tools-desktop
}



drv::VirtualBoxGuestAdditions ()
{
    Meta --desc "VirtualBox Guest"

    grep -q VirtualBox /proc/bus/input/devices || return

    apt::AddPackages dkms libnotify-bin # mesa-utils

    apt::AddPackages dmidecode
    local vboxHostVersion=$( dmidecode | awk -F_ '$1~/vboxVer$/{print $2}' )

    local tmpDir=$( mktemp -d )
    net::Download "$( vbox::GetGuestAdditionsUrl $vboxHostVersion )" "$tmpDir/ga.iso"

    apt::AddPackages p7zip-full
    7z x -o"$tmpDir" "$tmpDir/ga.iso" VBoxLinuxAdditions.run
    sys::Chk
    chmod +x "$tmpDir/VBoxLinuxAdditions.run"

    echo 'yes' | "$tmpDir/VBoxLinuxAdditions.run"
    # sys::Chk
    # BUG FAILS because missing current kernel headers

    # DEV: keeping for uninstallation
    # TIP: /opt/vbox-guest/VBoxLinuxAdditions.run uninstall
    sys::Mkdir /opt/vbox-guest/
    mv "$tmpDir/VBoxLinuxAdditions.run" /opt/vbox-guest/

    rm -rf "$tmpDir/"

    gui::FixDkmsAllModules
}



drv::Bluetooth ()
{
    Meta --desc "Bluetooth"

       dmesg | grep -i bluetooth \
    || return

    apt::AddPackages \
        bluez \
        bluez-obexd \
        bluez-tools \
        gnome-bluetooth \
        gnome-user-share \
        pulseaudio-module-bluetooth \
        rfkill

    adduser $USER_USERNAME bluetooth
    sys::Chk

    systemctl mask bluetooth

    gui::AddSystemdSwitch "bluetooth" bluetooth 1

    RegisterPostInstall post::Bluetooth 10

}



post::Bluetooth ()
{
    apt::AddPackages blueman
    gui::AddAppFolder Settings blueman blueman-manager
}



drv::BroadcomWlan ()
{

       lshw -class network \
    |  grep -q "product: BCM43" \
    || return

    # Enable Wifi
    # Broadcom driver
    apt::AddPackages firmware-b43-installer

    # Broadcom firmware
    apt::AddPackages b43-fwcutter
    local tmpdir=$( mktemp -d )
    net::DownloadUntarBzip \
        http://www.lwfinger.com/b43-firmware/broadcom-wl-6.30.163.46.tar.bz2 \
        $tmpdir
    b43-fwcutter -w /lib/firmware $tmpdir/*.o
    sys::Chk

    # ALT Broadcom proprietary firmware
    # Linux® STA 64-bit driver
    # https://docs.broadcom.com/docs-and-downloads/docs/linux_sta/hybrid-v35_64-nodebug-pcoem-6_30_223_271.tar.gz
    
    # Enable Bluetooth
    sys::Write <<'EOF' /etc/modprobe.d/b43.conf
options b43 btcoex=1 qos=0
EOF

}



drv::Mac ()
{
    
       lshw -class system \
    |  grep -Eq "product: (MacBook|iMac)" \
    || return


    # TOCHECK Facetime drivers
    # https://github.com/patjak/bcwc_pcie/wiki/Get-Started
    # https://launchpad.net/~psanford/+archive/ubuntu/facetimehd


    # Keyboard: fnmode toogle
    sys::Write <<'EOF' /etc/systemd/system/fnmode-perms.service
[Unit]
Description=Macbook fnmode switch

[Service]
Type=oneshot
User=root
ExecStart=/bin/chmod a+w /sys/module/hid_apple/parameters/fnmode

[Install]
WantedBy=multi-user.target
EOF
    ln -s /etc/systemd/system/fnmode-perms.service /etc/systemd/system/display-manager.service.wants/
    sys::Chk
    gui::AddKeybinding fnmode "<Shift>Escape" \
        'bash -c "echo \$( [[ \$( </sys/module/hid_apple/parameters/fnmode ) -eq 2 ]] && { echo 1; notify-send --hint int:transient:1 --icon keyboard \\\"Media mode keyboard\\\"; } || { echo 2; notify-send --hint int:transient:1 --icon keyboard \\\"Function mode keyboard\\\"; } ) >/sys/module/hid_apple/parameters/fnmode"'
    sys::Write <<'EOF' /etc/modprobe.d/hid_apple.conf # Keyboard: default fnmode to media keys (func=1, media=2)
options hid_apple fnmode=2
EOF

    # Keyboard: eject as delete, ALT-eject as eject
    # TOCHECK ejectcd_as_delete=1 https://github.com/free5lot/hid-apple-patched
    sys::Write --append <<'EOF' /usr/share/glib-2.0/schemas/$PRODUCT_NAME-gnome-keybindings.gschema.override
[org.gnome.settings-daemon.plugins.media-keys]
eject='<Alt>Eject'
EOF
    sys::Write --append "$HOME/.Xmodmap" 1000:1000 <<<"keycode 169 = Delete"
    # TODO auto(re)load Xmodmap http://joefreeman.weebly.com/uploads/1/3/7/7/13770951/xmodmap-reload-hack

}



drv::Macbook ()
{

       lshw -class system \
    |  grep -q "product: MacBook" \
    || return

    # Enable Touchpad
    drv::InputSynaptics

    # WORKAROUND wakeup after suspend
    sys::Write <<'EOF' /etc/pm/sleep.d/45_fixapplewakeup 0:0 755
#!/bin/bash
case $1 in
    hibernate|suspend)
        echo LID0 >/proc/acpi/wakeup
esac
EOF
}



drv::Macbookpro55 ()
{
       lshw -class system \
    |  grep -q "product: MacBookPro5,5" \
    || return

    # Enable backlight: https://github.com/madsherlock/nvidiabl
    apt::AddRemotePackages \
        https://github.com/madsherlock/nvidiabl/raw/master/install/deb/nvidiabl-dkms_0.88_all.deb
}



drv::Macbookpro82 ()
{
       lshw -class system \
    |  grep -q "product: MacBookPro8,2" \
    || return
    # ALT  "$( dmidecode -s system-product-name )" == "MacBookPro8,2"

    # Disable Radeon
    sys::Write <<'EOF' /etc/grub_force_options
# MacBookPro8,2
# switch gmux to IGD
outb 0x728 1
outb 0x710 2
outb 0x740 2
# power down ATI
outb 0x750 0
EOF
    sys::Write <<'EOF' /etc/default/grub.d/99-mbp82.cfg
GRUB_CMDLINE_LINUX_DEFAULT="$GRUB_CMDLINE_LINUX_DEFAULT radeon.modeset=0 i915.modeset=1"
EOF
    update-grub
    sys::Chk

    # UNUSED InstallDriverGraphicsIntel_NONFREE

}



drv::WifiAp ()
{
    Meta --desc "Wifi Access Point" \

    local wl=$( GetNetworkDeviceList --wireless )
    local et=$( GetNetworkDeviceList --ethernet )

    [[ -n "$wl" && -n "$et" ]] || return
    iw list | grep -E '^\s+\* AP$' || return

    apt::AddPackages hostapd dnsmasq
    # systemctl mask hostapd

    sys::Write <<EOF /etc/hostapd/hostapd.conf 644
# DOC: systemd env file for gnos-ap-hostapd & gnos-ap-dnsmasq
WLIF=$wl
ETIF=$et
GWIP=10.10.10.10
GWMA=255.255.255.0
DHCP=10.10.10.11-10.10.10.99
EOF

    sys::Write <<EOF /etc/gnos-ap-hostapd.conf 644
# DOC: hostapd configuration file for gnos-ap

# RADIO
interface=$wl
driver=nl80211
hw_mode=g
# g=2.4GHz, a=5GHz
#ieee80211n=1          # 802.11n support
#ieee80211ac=1         # 802.11ac support
#ieee80211d=1          # limit the frequencies used to those allowed in the country
#country_code=FR       # the country code
#wmm_enabled=1         # QoS support

# SECURITY
macaddr_acl=0
auth_algs=1            # 1=wpa, 2=wep, 3=both
wpa=2                  # 2=WPA2 only
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
ignore_broadcast_ssid=0

# CUSTOMIZATION
channel=6              # 0=autodetect (ACP)
ssid=$HOST_HOSTNAME
wpa_passphrase=12345678
EOF

    sys::Write <<EOF /etc/gnos-ap-dnsmasq.conf 644
# DOC: dnsmasq configuration file for gnos-ap

interface=$wl
except-interface=lo
bind-interfaces
dhcp-range=10.10.10.11,10.10.10.99,12h
#address=/#/10.10.10.10
EOF

    sys::Write <<'EOF' /lib/systemd/system/gnos-ap-hostapd.service 644
[Unit]
Description=GNOS Access Point: hostapd
After=network.target

[Service]
Type=forking
PIDFile=/run/gnos-ap-hostapd.pid
EnvironmentFile=/etc/default/gnos-ap.conf
ExecStartPre=/usr/bin/nmcli radio wifi off
ExecStartPre=/usr/sbin/rfkill unblock wlan
ExecStartPre=-/usr/bin/killall wpa_supplicant hostapd
ExecStartPre=/sbin/ifconfig ${WLIF} down
ExecStartPre=/sbin/iwconfig ${WLIF} mode monitor
ExecStartPre=/sbin/ifconfig ${WLIF} ${GWIP} netmask ${GWMA} up
ExecStart=/usr/sbin/hostapd -P /run/gnos-ap-hostapd.pid -B /etc/gnos-ap-hostapd.conf
ExecStartPost=/bin/bash -c "sleep 1"
ExecStopPost=/bin/systemctl restart network-manager.service
ExecStopPost=/usr/bin/nmcli radio wifi on
ExecStopPost=/bin/bash -c "sleep 1"
ExecStopPost=-/usr/bin/nmcli device connect ${WLIF}

[Install]
WantedBy=multi-user.target
EOF

    sys::Write <<'EOF' /lib/systemd/system/gnos-ap-dnsmasq.service 644
[Unit]
Description=GNOS Access Point: dnsmasq & forwarding
Requires=gnos-ap-hostapd
After=gnos-ap-hostapd

[Service]
Type=forking
EnvironmentFile=/etc/default/gnos-ap.conf
PIDFile=/run/gnos-ap-dnsmasq.pid
ExecStartPre=/bin/bash -c "sleep 2"
ExecStart=/usr/sbin/dnsmasq --conf-file=/etc/gnos-ap-dnsmasq.conf --pid-file=/run/gnos-ap-dnsmasq.pid
ExecStartPost=/bin/bash -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
ExecStartPost=/sbin/iptables -A POSTROUTING -t nat -m iprange --src-range ${DHCP} -o $ETIF -j MASQUERADE
ExecStartPost=/sbin/iptables -A FORWARD --match state --state RELATED,ESTABLISHED --jump ACCEPT
ExecStartPost=/sbin/iptables -A FORWARD -i $WLIF --match state --state NEW --jump ACCEPT
ExecStartPost=/sbin/iptables -A FORWARD -o $WLIF --match state --state NEW --jump ACCEPT
ExecStopPost=/sbin/iptables  -D FORWARD -o $WLIF --match state --state NEW --jump ACCEPT
ExecStopPost=/sbin/iptables  -D FORWARD -i $WLIF --match state --state NEW --jump ACCEPT
ExecStopPost=/sbin/iptables  -D FORWARD --match state --state RELATED,ESTABLISHED --jump ACCEPT
ExecStopPost=/sbin/iptables  -D POSTROUTING -t nat -m iprange --src-range ${DHCP} -o $ETIF -j MASQUERADE
ExecStopPost=/bin/bash -c "echo 0 > /proc/sys/net/ipv4/ip_forward"

[Install]
WantedBy=multi-user.target
EOF

    systemctl mask gnos-ap-hostapd
    systemctl mask gnos-ap-dnsmasq
    gui::AddSystemdSwitch "Wifi AP" "gnos-ap-hostapd gnos-ap-dnsmasq" 1
}



drv::Hibernation ()
{
    Meta --desc "Hibernation" \

    [[ -n "$SWAP_PARTITION" ]] || return

    # TODO HIBERNATION GNOME PANEL
    # https://extensions.gnome.org/extension/755/hibernate-status-button/

    sys::Write <<'EOF' /var/lib/polkit-1/localauthority/50-local.d/hibernate.pkla
[Re-enable Hibernate in upower]
Identity=unix-user:*
Action=org.freedesktop.upower.hibernate
ResultActive=yes

[Re-enable hibernate by default in logind]
Identity=unix-user:*
Action=org.freedesktop.login1.hibernate;org.freedesktop.login1.handle-hibernate-key;org.freedesktop.login1;org.freedesktop.login1.hibernate-multiple-sessions;org.freedesktop.login1.hibernate-ignore-inhibit
ResultActive=yes
EOF
}



drv::AutoHibernation ()
{
     Meta --desc "Hibernate after 30 min suspend" \
          --no-default true

    [[ -n "$SWAP_PARTITION" ]] || return

    # TOCHECK ALT systemd https://wiki.debian.org/SystemdSuspendSedation

    # DOC: https://www.kernel.org/doc/Documentation/power/basic-pm-debugging.txt
    # TEST echo platform > /sys/power/disk; echo disk > /sys/power/state
    # TODO UI ? https://help.ubuntu.com/14.04/ubuntu-help/power-hibernate.html

    # Hibernate after 30 minutes in Suspend state
    # FROM: http://superuser.com/q/298672
    sys::Write <<'EOF' /etc/pm/sleep.d/10_autohibernate 0:0 # STUB 755
#!/bin/bash

# CONF
WAIT_SECS=1800
LOCK_PATH=/var/run/pm-utils/locks/autohibernate.lock

# MAIN
curtime=$(date +%s)
case "$1" in
    suspend)
        echo "$curtime" >$LOCK_PATH                     # Record current time
        rtcwake --auto --mode disable                   # Cancel the rtc timer
        rtcwake --auto --mode no --seconds $WAIT_SECS   # Setup a wake timer
        ;;
    resume)
        sustime=$(cat $LOCK_PATH)
        rm "$LOCK_PATH"

        if [ $(($curtime - $sustime)) -ge $WAIT_SECS ]; then
            rm /var/run/pm-utils/locks/pm-suspend.lock
            /usr/sbin/pm-hibernate  # Hibernate
        else
            rtcwake --auto --mode disable               # Cancel the rtc timer
        fi
        ;;
esac
EOF
}



drv::IntelGraphics ()
{
     Meta --desc "Intel i915"

       lshw -class display \
    |  grep -q 'driver=i915' \
    || return

    # TODO grub 915resolution
    # https://wiki.archlinux.org/index.php/GRUB/Tips_and_tricks#915resolution_hack

    sys::Write <<'EOF' --append /etc/initramfs-tools/modules
# KMS
intel_agp
drm
i915 modeset=1
EOF

#     sys::Write <<'EOF' /usr/share/X11/xorg.conf.d/20-intel-graphics.conf
# Section "Device"

# Identifier "Intel Graphics"
#   Driver     "intel"
#   Option     "AccelMethod"    "sna"
#   Option     "TearFree"       "true"

# EndSection
# EOF

    # VA-API
    apt::AddPackages i965-va-driver vainfo # libva-intel-vaapi-driver

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then

        apt::AddPackages libva-glx1 libva-x11-1 \
            i965-va-driver \
            vainfo

        apt::AddPpaPackages nilarimogard/webupd8 libvdpau-va-gl1
        sed -i -E \
            -e "s/^# \[/\[/g" \
            -e "s/^#   export/  export/g" \
            /etc/X11/Xsession.d/20vdpau-va-gl
    else
        apt::AddPackages libva2 libva-glx2 libva-x11-2 libva-drm2 \
            i965-va-driver libvdpau-va-gl1 \
            gstreamer1.0-vaapi \
            vainfo
    fi

    # TIP: vainfo
}



drv::NvidiaGraphics ()
{
     Meta --desc "NVIDIA"

       lshw -class display \
    |  grep -q NVIDIA \
    || return

    gui::AddAppFolder Settings nvidia-settings

    # VDPAU
    apt::AddPackages mesa-vdpau-drivers vdpauinfo # libvdpau-va-gl1

# TODO nvidia
# GRUB_TERMINAL_OUTPUT=console
# GRUB_GFXPAYLOAD_LINUX=text
# https://extensions.gnome.org/extension/843/bumblebee-indicator/
}



drv::IntelWlan ()
{
     Meta --desc "Intel wireless"

       lshw -class network \
    |  grep -q 'driver=iwlwifi' \
    || return

    apt::AddPackages wireless-tools horst

    sys::Write <<'EOF' /etc/pm/sleep.d/00_iwlwifi 0:0 755
#!/bin/bash
case $1 in

    hibernate)
        killall wpa_supplicant
        echo disable > /proc/acpi/ibm/bluetooth
        modprobe -v -r iwlmvm
    ;;

    thaw)
        modprobe -v iwlwifi iwlmvm mac80211 cfg80211
        killall wpa_supplicant
    ;;

esac
EOF
}



drv::Hidpi ()
{
    Meta --desc "High DPI screens" \
         --no-default true


    # GNOME
    sys::Write --append <<'EOF' /usr/share/glib-2.0/schemas/$PRODUCT_NAME-hidpi.gschema.override
[org.gnome.desktop.interface]
scaling-factor=2
EOF

    # QT5
    sys::Write <<'EOF' /etc/X11/Xsession.d/90hidpi 0:0 644
#!/bin/sh
export QT_SCREEN_SCALE_FACTORS="2;1;1"
EOF
}



# drv::Laptop ()
# {
#     ls -la /sys/class/power_supply/BAT0 || return

#     # TODO https://extensions.gnome.org/extension/826/suspend-button/

#     # TLP
#     # DOC: http://linrunner.de/en/tlp/docs/tlp-linux-advanced-power-management.html
#     apt-get --yes remove laptop-mode-tools
#     apt::AddPpaPackages linrunner/tlp tlp tlp-rdw

#     drv::InputSynaptics
# }



drv::NoIpv6 ()
{
    Meta --desc "Disable IPv6" \
         --no-default true

    sys::Write <<'EOF' /etc/sysctl.d/90-no-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

}



drv::HpPrinters ()
{
    Meta --desc "HP Printers/Scanners" \
          --no-default true

    apt::AddPackages hplip-gui cups-pk-helper
    gui::HideApps display-im6 display-im6.q16
    gui::AddAppFolder Settings hplip
    touch \
        /usr/local/share/applications/hplip-kubuntu.desktop \
        /usr/local/share/applications/hp-fab.desktop \
        /usr/local/share/applications/hp-sendfax.desktop \
        /usr/local/share/applications/hplip-systray.desktop
    mv /etc/xdg/autostart/hplip-systray.desktop{,.ORIG}
    adduser $USER_USERNAME lpadmin

    gui::SetAppName hplip "HP LIP"
    gui::SetAppIcon hplip hplip
    gui::SetAppIcon hplip-systray hplip
    gui::SetAppProp hplip StartupWMClass hp-toolbox

    # SimpleScan
    apt::AddPackages simple-scan
    gui::AddAppFolder Office simple-scan
    # ATWORK quiteInsane gimp plugin compilation
    # local tmpDir=$( mktemp -d )
    # local projDir="quiteinsanegimpplugin-0.3"
    #   net::Download "https://sourceforge.net/projects/quiteinsane/files/latest/quiteinsanegimpplugin-0.3.tar.gz" \
    # | tar xz --directory "$tmpDir" $projDir/
    # sys::Chk
    # apt::AddPackages # qt3d5-dev # xserver-xorg-dev
    # pushd "$tmpDir/$projDir"
    # ./configure
    # rm -rf "$tmpDir"

}



drv::InputSynaptics ()
{
    Meta --desc "Synaptics touchpads" \

    # TIP: detect synaptic
    grep -Ei 'synaptics|alps' /proc/bus/input/devices || return

    # TIP: detect multitouch
    # grep "TouchPad: buttons:" /var/log/Xorg.0.log | grep -e "double|triple"

    # TIP: enable syndaemon
    # sys::Write /etc/X11/Xsession.d/98x11-syndaemon <<<"/usr/bin/syndaemon -d -t -k -i 1"


    [[ -f /usr/share/X11/xorg.conf.d/72-synaptics-custom.conf ]] && return

    apt::AddPackages xserver-xorg-input-synaptics

    # DOC: http://www.x.org/archive/X11R7.5/doc/man/man4/synaptics.4.html
    # sys::Write <<'EOF' /usr/share/X11/xorg.conf.d/52-synaptics-custom.conf
    sys::Write <<'EOF' /usr/share/X11/xorg.conf.d/72-synaptics-custom.conf

Section "InputClass"
    Identifier "Custom synaptics config"
    MatchDriver "synaptics"

    # Tapping
    Option      "TapButton3"                "2"
    Option      "MaxTapTime"                "100"
    # Option    "FingerLow"                 "10"
    # Option    "FingerHigh"                "15"

    # Disable edge scrolling
    Option      "HorizEdgeScroll"           "0"
    Option      "VertEdgeScroll"            "0"

    # Natural scrolling
    Option      "VertTwoFingerScroll"       "1"
    Option      "VertScrollDelta"           "-30"
    Option      "HorizTwoFingerScroll"      "1"
    Option      "HorizScrollDelta"          "-30"

    # Drag lock
    Option      "LockedDrags"               "1"
    Option      "LockedDragTimeout"         "30000"

    # Prevent accidental clicks
    Option      "PalmDetect"                "1"
    Option      "PalmMinWidth"              "10"
    Option      "PalmMinZ"                  "5"

    # Calm the pad down while clicking
    Option "VertHysteresis" "50"
    Option "HorizHysteresis" "50"


    # Do not emulate mouse buttons in the touchpad corners.
    # Option "RTCornerButton" "0"
    # Option "RBCornerButton" "0"
    # Option "LTCornerButton" "0"
    # Option "LBCornerButton" "0"

    # The following modifies how long and how fast scrolling continues
    # after lifting the finger when scrolling
    # Option "CoastingSpeed" "20"
    # Option "CoastingFriction" "200"
EndSection
EOF

    sys::Write <<'EOF' $HOME/.config/autostart/syndaemon.desktop 1000:1000
[Desktop Entry]
Type=Application
Exec=syndaemon -i 2.0 -K -R -t
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=syndaemon
Comment=
EOF

    sys::Write <<'EOF' /etc/pm/sleep.d/05_psmouse 0:0 755
#!/bin/bash

# MAIN
case $1 in

    "suspend"|"hibernate")

        modprobe -v -r psmouse

        ;;

    "resume"|"thaw")

        modprobe -v psmouse

        ;;

esac
EOF

#     sys::Write --append <<'EOF' /usr/share/glib-2.0/schemas/$PRODUCT_NAME-touchpad.gschema.override
# [org.gnome.desktop.peripherals.touchpad]
# tap-to-click=true
# EOF
        sys::Write <<'EOF' --append "$POSTINST_USER_SESSION_SCRIPT"
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
EOF
}
