#   ▞▀▖▙ ▌▞▀▖▞▀▖  ▞▀▖▜ ▗
#   ▌▄▖▌▌▌▌ ▌▚▄   ▌  ▐ ▄
#   ▌ ▌▌▝▌▌ ▌▖ ▌  ▌ ▖▐ ▐
#   ▝▀ ▘ ▘▝▀ ▝▀   ▝▀  ▘▀▘



com::Cli ()
{
    sys::Mkdir $HOME/.cache
    sys::Mkdir $HOME/.config

    apt::Update

    # KERNEL
    # apt::AddPackages kexec-tools
    # TODO kexec -l --reuse-cmdline --initrd=/boot/initrd.img-$(uname -r) /boot/vmlinuz-$(uname -r); kexec -e
    # TODO COMMENT /etc/default/grub.d/kexec-tools.cfg
    # TIP: kexec -l --reuse-cmdline --initrd=/initrd.img /vmlinuz; kexec -e

    # BIN
    apt::AddPackages dhex binwalk

    # FLOW
    apt::AddPackages most socat mbuffer pv bsdmainutils pick parallel asciinema toilet toilet-fonts

    ## bat, A cat(1) clone with wings.
    net::InstallGithubLatestRelease sharkdp/bat '_amd64\\.deb$'

    # SYS
    apt::AddPackages lsof strace ltrace gdb psmisc pslist tree lnav iotop

    # lsofc
    net::Download "https://raw.githubusercontent.com/stephane-chazelas/misc-scripts/master/lsofc" /usr/local/bin/lsofc
    chmod +x /usr/local/bin/lsofc

    # shc
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages neurobin/ppa shc
    else
        apt::AddPackages shc
    fi

    # htop
    cli::Htop


    # HARDWARE
    apt::AddPackages linux-tools-common \
        dmidecode lshw hwinfo hwdata \
        cpufrequtils pciutils usbutils pm-utils powertop \
        ethtool wireless-tools \
        inxi
    # msr-tools

    ## linux-tools-common/turbostat kernel supoort
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPackages linux-tools-generic-hwe-16.04-edge
    else
        apt::AddPackages linux-tools-generic
    fi

    # STORAGE
    apt::AddPackages \
        hdparm gdisk parted attr kpartx libatasmart-bin \
        dosfstools ntfs-3g \
        hfsplus hfsutils hfsprogs dmg2img libplist-utils \
        partimage testdisk \
        clonezilla partclone \
        ncdu

    # BACKUP
    apt::AddPackages bup # DOC https://github.com/bup/bup
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages costamagnagianfranco/borgbackup borgbackup libb2-1
    else
        apt::AddPackages borgbackup
    fi

    # COMPRESSION
    apt::AddPackages \
        zip unzip \
        rar unrar \
        p7zip p7zip-rar \
        xz-utils lzop cabextract unar # lz4-tools


    ########
    # BASH #
    ########

    cli::Bash

    cli::Sugar


    #######
    # ZFS #
    #######

    if str::InList ZFS $STORAGE_OPTIONS ; then

        # Enable password-less sudo
        sys::SedInline 's/^#//' /etc/sudoers.d/zfs
        sys::SedInline 's#^(Cmnd_Alias C_ZFS =)#\1 /sbin/zfs mount "",#' \
            /etc/sudoers.d/zfs


        # Enable sudo-less zfs/zpool
        sys::Write --append <<'EOF' "$HOME/.bashrc.d/56_func_zfs" 1000:1000
if [[ "$( id -u )" != "0" ]] ; then
    zfs ()   { sudo zfs   "$@"; }
    zpool () { sudo zpool "$@"; }
fi

EOF
        declare -f zfs::GetFileSnapshots >>"$HOME/.bashrc.d/56_func_zfs"

        cli::Sanoid
    fi


    #######
    # DEV #
    #######

    # GCC
    apt::AddPackages build-essential

    # GIT
    apt::AddPpaPackages git-core/ppa git git-man # git-cvs git-svn
    sys::Touch $HOME/.gitconfig 1000:1000 600
    sudo --set-home -u \#1000 git config --global alias.co checkout
    sudo --set-home -u \#1000 git config --global alias.br branch
    sudo --set-home -u \#1000 git config --global alias.ci commit
    sudo --set-home -u \#1000 git config --global alias.st status
    sudo --set-home -u \#1000 git config --global alias.ll \
        "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
    # git alias: logline https://ma.ttias.be/pretty-git-log-in-one-line/

    # gnos-gitr
    net::CloneGitlabRepo gnos/gnos-gitr /opt
    ln -s /opt/gnos-gitr/gitr /usr/local/bin/
    sys::Chk

    # github hub
    local tempdir=$( mktemp -d )
    net::DownloadGithubLatestRelease github/hub '/hub-linux-amd64-.*\\.tgz$' \
        $tempdir/hub.tgz
    pushd $tempdir
    tar xzvf hub.tgz
    sys::Chk
    pushd hub-linux-*
    sys::Copy bin/hub /usr/local/bin/
    sys::Copy etc/hub.bash_completion.sh "$HOME/.bashrc.d/completion.hub"
    sys::Mkdir /usr/local/share/man/man1
    cp share/man/man1/*.1 /usr/local/share/man/man1
    sys::Chk
    popd ; popd
    rm -rf "$tempdir"

    # tig
    apt::AddPackages tig                          # http://jonas.nitro.dk/tig/
    sys::Write <<'EOF' $HOME/.tigrc
set line-number-interval = 4
set show-rev-graph = yes
set tab-size = 4
EOF

    # myrepos
    apt::AddPackages myrepos --install-recommends # https://myrepos.branchable.com/




    #############
    # PACKAGERS #
    #############

    # APT: POSTINST
    RegisterPostInstall post::AptUpgrade 01

    # APT: CONF
    sys::Write <<'EOF' /etc/apt/apt.conf.d/99norecommends
APT::Install-Recommends "0";
EOF
    sys::Write <<'EOF' /etc/apt/apt.conf.d/99nopdiff
Acquire::PDiffs "false";
EOF
    sys::Write <<'EOF' /etc/apt/apt.conf.d/99progressbar
Dpkg::Progress-Fancy "1";
APT::Color "true";
EOF
    sys::Write <<'EOF' /etc/apt/apt.conf.d/99nolang
Acquire::Languages "none";
EOF
    sys::Write <<'EOF' /etc/apt/apt.conf.d/99parallel
APT::Acquire::Queue-Mode "access";
APT::Acquire::Retries 3;
EOF

    # APT: helpers
    apt::AddPackages \
        aptitude debconf-utils apt-transport-https apt-transport-tor \
        apt-file deborphan ppa-purge apt-rdepends

    RegisterPostInstall post::AptFile 20

    # aptly
    apt::AddSource aptly \
        "http://repo.aptly.info/" \
        "squeeze main" \
        "https://www.aptly.info/pubkey.txt"
    apt::AddPackages aptly graphviz

    # apt-fast
    apt::AddPpaPackages apt-fast/stable apt-fast

    # DPKG: dpkg-buildpackage DEPS
    apt::AddPackages fakeroot dpkg-dev debhelper

    # Snappy
    apt::AddPackages ubuntu-snappy
    systemctl mask snapd.refresh.timer
    systemctl mask snapd.socket
    systemctl mask snapd.service

    # Flatpak
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages alexlarsson/flatpak flatpak
    else
        apt::AddPackages flatpak
    fi
    # REMOVED
    # flatpak remote-add --if-not-exists gnome https://sdk.gnome.org/gnome.flatpakrepo
    # sys::Chk
    flatpak remote-add flathub https://flathub.org/repo/flathub.flatpakrepo
    sys::Chk
    # flatpak update
    # sys::Chk

    # ubuntu-make
    apt::AddPackages ubuntu-make



    #############
    # LANGUAGES #
    #############


    # PYTHON + pip3 pip2
    cli::Python

    # NODE + nvm npm
    cli::Node

    # RUBY + rvm gem
    cli::Ruby

    # GO + gvm
    cli::Golang

    # PHP + composer prestissimo
    cli::Php

    # yarn
    npm::Install yarn

    # meson
    pip::Install meson

    # TODO ? grunt gulp rake



    ###########
    # NETWORK #
    ###########

    # local-mail delivery
    cli::Mail

    # Network HTTP, FTP
    pip::Install sauth pyftpdlib

    # Network SSH
    cli::Ssh

    # Network NFS
    apt::AddPackages nfs-kernel-server
    systemctl mask nfs-kernel-server.service
    systemctl mask nfs-server.service
    systemctl mask nfs-config.service
    systemctl mask proc-fs-nfsd.mount
    systemctl mask rpcbind.socket
    systemctl mask rpcbind.service
    # TIP: zfs set sharenfs="rw=@10.10.10.0/24" pool/data/srv ; zfs share pool/data/srv
    # TIP: zfs set sharenfs="rw=@10.10.10.0/24,sync,no_root_squash,no_wdelay" pool/data/srv ; zfs share pool/data/srv
    # WORKAROUND: NFS daemon will not start unless there is an export
    #    str::InList ZFS $STORAGE_OPTIONS \
    # && sys::Write /etc/exports <<<'/mnt localhost(ro)'

    # Network SAMBA
    apt::AddPackages samba samba-dsdb-modules samba-vfs-modules smbclient cifs-utils
    adduser $( id -nu 1000 ) sambashare
    systemctl mask nmbd.service
    systemctl mask smbd.service
    systemctl mask samba-ad-dc.service
    # TIP: zfs create -o xattr=sa -o casesensitivity=mixed pool/data/srv
    # TIP: zfs set sharesmb=on pool/data/srv ; zfs share pool/data/srv
    # TIP: smbpasswd -a USERNAME

    # Network tools
    apt::AddPackages \
        net-tools iptables bridge-utils macchanger wakeonlan \
        iftop mtr-tiny nmap ettercap-text-only iptraf-ng  nethogs \
        tcpdump ngrep \
        libnss3-tools \
        curl httpie wget w3m w3m-img  \
        telnet hping3 dnsutils whois \
        geoip-bin geoip-database

    # Network: tshark
    apt::AddSelection "wireshark-common wireshark-common/install-setuid boolean true"
    apt::AddPackages tshark

    # Network: proxychains-ng
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages hda-me/proxychains-ng proxychains-ng
    else
        apt::AddPackages proxychains4
        # apt::AddPpaPackages --release xenial hda-me/proxychains-ng proxychains-ng
    fi

    # Network SYNC
    apt::AddPackages \
        rsync \
        lsyncd \
        rdiff-backup \
        unison

    # Network SYNC: rclone
    cli::Rclone

    # Network SYNC crypto: gocryptfs
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages ondrej/php libssl1.1
        apt::AddRemotePackages \
            "https://launchpad.net/ubuntu/+archive/primary/+files/gocryptfs_1.4.3-5build1_amd64.deb"
    else
        apt::AddPackages gocryptfs
    fi

    # Network SYNC crypto: cryfs
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages hda-me/zulucrypt cryfs
    else
        apt::AddPackages cryfs
    fi

    # Network VPN: Softether
    cli::Softether

    # Network VPN: WireGuard
    apt::AddPpaPackages wireguard/wireguard wireguard wireguard-tools wireguard-dkms

    # Network TUN: gost
    local tmpdir=$( mktemp -d )
    net::DownloadGithubLatestRelease ginuerzh/gost '_amd64\\.tar\\.gz$' $tmpdir/
    pushd $tmpdir
    tar xzvf "$tmpdir"/*.tar.gz --directory "/usr/local/bin" --strip-components=1
    sys::Chk
    popd


    # Network TUN: tun2socks
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages hda-me/badvpn-tun2socks badvpn-tun2socks
    else
        apt::AddPpaPackages --release xenial hda-me/badvpn-tun2socks badvpn-tun2socks
    fi

    # Network TUN: ngrok
    local tempzip=$( mktemp )
    # net::Download "https://dl.ngrok.com/ngrok_2.0.19_linux_amd64.zip" $tempzip
    net::Download "https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip" $tempzip
    unzip $tempzip ngrok -d /usr/local/bin/
    sys::Chk
    rm $tempzip

    # Network magic-wormhole.io
    pip::Install magic-wormhole

    # gnos-serve
    net::CloneGitlabRepo gnos/gnos-serve /opt
    ln -s /opt/gnos-serve/srv /usr/local/bin/
    sys::Chk

    # gnos-sockets
    net::CloneGitlabRepo gnos/gnos-sockets /opt
    ln -s /opt/gnos-sockets/sss /usr/local/bin/
    sys::Chk

    # gnos-socksjail
    apt::AddPpaPackages shevchuk/dnscrypt-proxy dnscrypt-proxy
    systemctl mask dnscrypt-proxy.socket
    systemctl mask dnscrypt-proxy.service
    net::CloneGitlabRepo gnos/gnos-socksjail /opt
    ln -s /opt/gnos-socksjail/socksjail /usr/local/bin/
    sys::Chk

    cli::Vpngate



    ###########
    # PARSERS #
    ###########


    # Parser: INI
    apt::AddPackages crudini

    # Parser: TEXT
    apt::AddPackages gawk
    # DEV Keep mawk as defaut for scripts compat
    update-alternatives --install /usr/bin/awk awk /usr/bin/gawk 4

    # Parser: TSV as SQL
    net::InstallGithubLatestRelease harelba/q '\\.deb$'

    # Parser: TEXT, CSV, TSV, and JSON converter
    apt::AddPackages miller # TIP: mlr

    # Parser: JSON
    cli::Jq

    # Parser: YAML
    pip::Install shyaml

    # Parser: XML
    apt::AddPackages xmlstarlet

    # Parser: HTML
    gog::Install github.com/ericchiang/pup





    ##########
    # SEARCH #
    ##########

    # SEARCH locate
    apt::AddPackages locate
    sys::Mkdir /var/cache/locate
    RegisterPostInstall post::Updatedb 99

    # SEARCH ack http://beyondgrep.com/
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPackages ack-grep
    else
        apt::AddPackages ack
    fi
    sys::Write <<'EOF' $HOME/.ackrc
--ignore-dir=_site
--type-add
js=.json
EOF
# --pager=less -R -F -X

    # SEARCH ag https://github.com/ggreer/the_silver_searcher
    apt::AddPackages silversearcher-ag



    #########
    # SHELL #
    #########


    cli::Zsh

    cli::Fish

    cli::Tmux

    cli::Vim

    cli::Powerline

    cli::Direnv

    cli::Hstr

    cli::Z



    #######
    # SYS #
    #######

    cli::Neofetch

    cli::Firejail

    cli::Sysdig

    cli::Osquery



    #########
    # CLOUD #
    #########

    ## Amazon AWS CLI
    pip::Install awscli

    ## Google cloud SDK
    apt::AddSource google-cloud \
        "https://packages.cloud.google.com/apt" \
        "cloud-sdk-$( lsb_release -cs ) main" \
        "https://packages.cloud.google.com/apt/doc/apt-key.gpg"
    apt::AddPackages google-cloud-sdk

    ## Microsoft Azure CLI
    apt::AddSource ms-azure \
        "[arch=amd64] https://packages.microsoft.com/repos/azure-cli/" \
        "$( lsb_release -cs ) main" \
        "52E16F86FEE04B979B07E28DB02C46DF417A0893"
    apt::AddPackages azure-cli

    ## Terraform
    local tfv=$(
        net::Download https://releases.hashicorp.com/terraform/ \
        | awk -F'href="' '$2~/^\/terraform\//&&$2!~/alpha/{split($2,a,"/"); print a[3]; exit}'
    ) # 0.11.8
    net::DownloadUnzip \
        "https://releases.hashicorp.com/terraform/$tfv/terraform_${tfv}_linux_amd64.zip" \
        "/usr/local/bin/"

    ## Packer
    local pcv=$(
        net::Download https://releases.hashicorp.com/packer/ \
        | awk -F'href="' '$2~/^\/packer\//&&$2!~/alpha/{split($2,a,"/"); print a[3]; exit}'
    ) # 0.11.8
    net::DownloadUnzip \
        "https://releases.hashicorp.com/packer/$pcv/packer_${pcv}_linux_amd64.zip" \
        "/usr/local/bin/"


    #######
    # END #
    #######

    chown -hR 1000:1000 $HOME/.cache/dconf

    # ZFS DEBUG
    # str::InList ZFS $STORAGE_OPTIONS && zfs::CreateSnapshot $ZFS_POOL_NAME/$ZFS_ROOT_DSET $PRODUCT_NAME-cli
}



post::AptUpgrade ()
{
    apt::GenerateSources / $UBUNTU_RELEASE "http://archive.ubuntu.com/ubuntu/"
    apt::Update
    apt::Upgrade
}

post::AptFile ()
{
    apt-file update
    sys::Chk
}
post::Updatedb ()
{
    sys::Mkdir /var/cache/locate
    updatedb
    sys::Chk
}


cli::InitDockerBuild ()
{

    # /etc/default/keyboard
    # /etc/timezone
    sys::Write /etc/gnos.conf <<EOF
BOOT_PARTITION=""
GRUB_DEVICE=""
HOST_HOSTNAME="$HOSTNAME"
HOST_TIMEZONE="Europe/Paris"
INSTALL_BUNDLES=""
KEYBOARD_LAYOUT="fr"
KEYBOARD_MODEL="pc105"
KEYBOARD_VARIANT=""
POOL_TOPOLOGY=""
STORAGE_OPTIONS=""
SWAP_PARTITION=""
UBUNTU_RELEASE="bionic"
USER_USERNAME="user"
EOF
}