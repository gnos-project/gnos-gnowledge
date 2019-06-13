########
# FUNC #  BUNDLES::ENGINE
########

ZFS_VIRT_DSET=virt



PACKAGES_ENGINE="
    app::Docker
    app::Kubernetes
    app::Lxc
    app::Lxd
    app::Kvm
    app::Virtualbox
    app::Virtualbox_NONFREE
    app::Wine
    "



app::Kvm ()
{
    Meta --desc "VM hypervisor" \
         --no-default true

    apt::AddPackages \
        qemu-kvm qemu-utils bridge-utils \
        virt-manager libvirt-bin
    gui::AddAppFolder Runtimes virt-manager
    gui::SetAppName virt-manager "Virt Manager"

    local services
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPackages gir1.2-spice-client-gtk-3.0
        services="qemu-kvm.service libvirt-bin.service libvirt-guests.service"
        rm /etc/systemd/system/libvirtd.service
    else
        services="qemu-kvm.service libvirtd.service libvirt-guests.service"
    fi

    adduser $( id -nu 1000 ) libvirtd
    sys::Write <<'EOF' /var/lib/AccountsService/users/libvirtd-qemu
[User]
SystemAccount=true
EOF

grep libvirt /etc/passwd # DBG

    # systemd switch
    for srv in $services ; do systemctl mask $srv ; done
    gui::AddSystemdSwitch libvirt "$services" 3

    # Manual ZFS storage backend
    if which zpool && zfs::IsDataset "$ZFS_POOL_NAME" ; then

        if [[ "$INSTALL_MODE" == "MenuInstall" ]] ; then

            zfs::CreateDataset "$ZFS_POOL_NAME/${ZFS_DATA_DSET:-$ZFS_VIRT_DSET}/libvirt" \
                -o mountpoint=/var/lib/libvirt/zfs

            sys::Mkdir /var/lib/libvirt/zfs/images 1000:1000
            sys::Mkdir /var/lib/libvirt/zfs/passthru 1000:1000

            rm -rf /var/lib/libvirt/images
        fi

        pushd /var/lib/libvirt
        ln -s /var/lib/libvirt/zfs/images
        ln -s /var/lib/libvirt/zfs/passthru/
        popd
    fi

    # Configure 'lxc:///' connection
    if which lxc &>/dev/null; then
        # DEV: using $POSTINST_USER_SESSION_SCRIPT
        sys::Write <<EOF --append $POSTINST_USER_SESSION_SCRIPT
gsettings set org.virt-manager.virt-manager.connections uris "['qemu:///system', 'lxc:///']"
gsettings set org.virt-manager.virt-manager.connections autoconnect "['qemu:///system', 'lxc:///']"
EOF
    fi

# TIP passthru fs
# http://troglobit.github.io/blog/2013/07/05/file-system-pass-through-in-kvm-slash-qemu-slash-libvirt/
# http://unix.stackexchange.com/questions/90423/can-virtfs-9p-be-used-as-root-file-system
# https://lists.gnu.org/archive/html/qemu-devel/2010-05/msg02673.html

# TIP Build 1.4
# apt-get build-dep virt-manager
# apt-get install qemu-kvm libvirt-bin ubuntu-vm-builder bridge-utils python-libvirt libgtk-3-dev libvirt-glib-1.0 gir1.2-gtk-vnc-2.0 gir1.2-spice-client-gtk-3.0 libosinfo-1.0 python-ipaddr gir1.2-vte-2.91 python-libxml2 python-requests libvirt-glib-1.0-dev
# wget https://virt-manager.org/download/sources/virt-manager/virt-manager-1.4.0.tar.gz
# tar -xvzf virt-manager-1.4.0.tar.gz
# cd virt-manager-1.4.0/
# python setup.py install

}



app::Lxc ()
{
    Meta --desc "Container engine" \
         --no-default true

    apt::AddPackages \
        lxc lxc1 lxc-templates python3-lxc lxcfs libpam-cgfs \
        lxctl

    # FIX: Unrule dhclient from apparmor enforcements, triggered by liblxc-common
       aa-enabled -q &>/dev/null \
    && apparmor_parser -R /etc/apparmor.d/sbin.dhclient \
    && aa-status # DEBUG

    # ZFS backend
    if which zpool \
    && zfs::IsDataset "$ZFS_POOL_NAME" \
    && [[ "$INSTALL_MODE" == "MenuInstall" ]] ; then

        local dataset="$ZFS_POOL_NAME/${ZFS_DATA_DSET:-$ZFS_VIRT_DSET}/lxc"
        rm -rfv /var/lib/lxc/*
        zfs::CreateDataset "$dataset" -o mountpoint=/var/lib/lxc

    fi

    systemctl mask lxc.service
    systemctl mask lxcfs.service
    systemctl mask lxc-net.service
    gui::AddSystemdSwitch lxc "lxcfs.service lxc-net.service lxc.service" 3

    # TODO https://github.com/ustuehler/lxc-desktop

    # # TOCHECK  LXC web panel
    # apt::AddPackages debootstrap # DEPS
    #   net::Download http://lxc-webpanel.github.com/tools/install.sh \
    # | bash
    # TIP config file :  /srv/lwp/lwp.conf
}



post::Lxd ()
{
    local services="lxc-net.service lxcfs.service lxc.service lxd.socket lxd.service"
    sys::StartServices $services

    local initOpt
    if which zpool && zfs::IsDataset "$ZFS_POOL_NAME" ; then
        local dataset="$ZFS_POOL_NAME/${ZFS_DATA_DSET:-$ZFS_VIRT_DSET}/lxd"
        initOpt="--storage-backend zfs --storage-pool $dataset/storage"
    fi

    lxd init --auto \
        --network-address localhost \
        --network-port 8443 \
        $initOpt

    sys::StopServices $services
}



app::Lxd ()
{
    Meta --desc "Container engine" \
         --no-default true

    # DEP: lxc
    # BUG which lxc &>/dev/null || app::Lxc
    # TODO apt::isPackageInstalled

    # apt::AddPpaPackages ubuntu-lxc/lxd-stable \
    apt::AddPackages lxd lxd-client lxd-tools

    adduser $( id -nu 1000 ) lxd

    apt::AddPackages criu

    # ZFS backend
    if which zpool \
    && zfs::IsDataset "$ZFS_POOL_NAME" \
    && [[ "$INSTALL_MODE" == "MenuInstall" ]] ; then

        local dataset="$ZFS_POOL_NAME/${ZFS_DATA_DSET:-$ZFS_VIRT_DSET}/lxd"
        rm -rfv /var/lib/lxd/*
        zfs::CreateDataset "$dataset"       -o mountpoint=none -o canmount=off
        zfs::CreateDataset "$dataset/state" -o mountpoint=/var/lib/lxd-tools # TODO rename $dataset/varlib ?
    fi

    # LXD recommended production-setup
    sys::Write --append <<EOF /etc/sysctl.conf
fs.inotify.max_queued_events=1048576
fs.inotify.max_user_instances=1048576
fs.inotify.max_user_watched=1048576
vm.max_map_count=262144
EOF

    systemctl mask lxd.socket
    systemctl mask lxd.service
    systemctl mask lxd-containers.service

    gui::AddSystemdSwitch lxd "lxc-net.service lxcfs.service lxc.service lxd.socket lxd.service lxd-containers.service" 3

    if [[ "$INSTALL_MODE" == "MenuInstall" ]] ; then
        RegisterPostInstall post::Lxd 40
    fi

    # TOCHECK https://github.com/bmullan/lxd-webgui
}



app::Kubernetes ()
{
    Meta --no-default true \
         --desc "Container orchestrator"

    [[ -x "/usr/local/bin/docker-machine" ]] || app::Docker

    # BIONIC: kubernetes-bionic not released yet
    apt::AddSource kubernetes \
        "https://packages.cloud.google.com/apt" \
        "kubernetes-xenial main" \
        "https://packages.cloud.google.com/apt/doc/apt-key.gpg"

    ## kubectl
    apt::AddPackages kubectl
    sudo --set-home -u \#1000 kubectl completion bash >$HOME/.bashrc.d/completion.kubectl
    chown -hR $USER_USERNAME:$USER_USERNAME $HOME/.bashrc.d/completion.kubectl
    sys::Touch $HOME/.kube/config

    ## crictl
    # DEV: 1.13 not in repo yet
    apt::AddPackages cri-tools
    sudo --set-home -u \#1000 crictl completion bash >$HOME/.bashrc.d/completion.crictl

    ## minikube: sudo minikube start --vm-driver=none
    apt::AddPackages conntrack
    net::InstallGithubLatestRelease kubernetes/minikube '/minikube_.*\\.deb$'
    sudo --set-home -u \#1000 minikube completion bash >$HOME/.bashrc.d/completion.minikube
    chown -hR $USER_USERNAME:$USER_USERNAME $HOME/.bashrc.d/completion.minikube
    sys::Mkdir $HOME/.minikube
    local bashrc=$HOME/.bashrc
    [[ -d "$HOME/.bashrc.d" ]] && bashrc=$HOME/.bashrc.d/env.minikube
    sys::Write --append <<'EOF' "$bashrc" 1000:1000 700
export KUBECONFIG=$HOME/.kube/config
export MINIKUBE_HOME=$HOME
export MINIKUBE_WANTREPORTERRORPROMPT=false
export CHANGE_MINIKUBE_NONE_USER=true
EOF
# export MINIKUBE_WANTUPDATENOTIFICATION=false

    ## helm
    net::Download \
        https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get \
        /usr/local/bin/helm_installer
    chmod +x /usr/local/bin/helm_installer
    /usr/local/bin/helm_installer
    sys::Chk
    sudo --set-home -u \#1000 helm completion bash >$HOME/.bashrc.d/completion.helm
    chown -hR $USER_USERNAME:$USER_USERNAME $HOME/.bashrc.d/completion.helm
    # rm /usr/local/bin/helm_installer

    # microk8s
    # TIP: snap install microk8s --classic
    gui::AddSwitch "microk8s" \
        'microk8s.status | grep \"is running\"' \
        'which microk8s.start || { pkexec bash -c \"systemctl unmask snapd.socket snapd.service ; systemctl start snapd.socket snapd.service ; snap install microk8s --classic --channel=1.12/stable\" ; } ; o bash -c \"echo Start microk8s; microk8s.start && sleep 30 && microk8s.enable dashboard dns storage\"' \
        'o bash -c \"echo Stop microk8s ; microk8s.stop\"' \
        3


    ## UNUSED kubeadm kubelet
    # apt::AddPackages kubeadm kubelet
    # sudo --set-home -u \#1000 kubeadm completion bash >$HOME/.bashrc.d/completion.kubeadm
    # chown -hR $USER_USERNAME:$USER_USERNAME $HOME/.bashrc.d/completion.kubeadm
    # systemctl mask kubelet.service
    # gui::AddSystemdSwitch kubelet "kubelet.service" 3

    # kompose
    # net::InstallGithubLatestRelease kubernetes/kompose '/_amd64\\.deb$'
}



app::Docker ()
{
    Meta --desc "Container engine"

    # DOCS http://docs.master.dockerproject.org/installation/binaries/
    # LATEST https://master.dockerproject.org/linux/amd64/docker

    # apt-get --yes purge lxc-docker*
    # apt-get --yes purge docker.io*

    # TIPS: https://github.com/just-containers/s6-overlay/

    apt::AddSource docker \
        "[arch=amd64] https://download.docker.com/linux/ubuntu" \
        "$(lsb_release -cs) stable" \
        "https://download.docker.com/linux/ubuntu/gpg"

    # DEV: K8s does not support >18.06
    apt::AddPackages docker-ce=18.06.0~ce~3-0~ubuntu
    apt-mark hold docker-ce
    sys::Chk
    gui::AddAptIndicatorIgnore docker-ce

    adduser $( id -nu 1000 ) docker

    # systemd switch
    systemctl mask docker.service
    systemctl mask docker.socket
    systemctl mask containerd.service
    gui::AddSystemdSwitch docker "containerd.service docker.service docker.socket" 3

    # ZFS backend
    if which zpool && zfs::IsDataset "$ZFS_POOL_NAME" ; then

        local dataset="$ZFS_POOL_NAME/${ZFS_DATA_DSET:-$ZFS_VIRT_DSET}/docker"

        if [[ "$INSTALL_MODE" == "MenuInstall" ]] ; then
            rm -rfv /var/lib/docker/*
            zfs::CreateDataset "$dataset" -o mountpoint=/var/lib/docker
        fi

        # PATCH /etc/defaults/docker
        sys::Write --append <<EOF /etc/default/docker
DOCKER_OPTS="--storage-driver=zfs --storage-opt zfs.fsname=$dataset"
EOF
    fi

    # Compose
    net::DownloadGithubLatestRelease  docker/compose 'Linux-x86_64$' \
        /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    # dcsg is a command-line utility for Linux that generates systemd services for Docker Compose projects
    net::DownloadGithubLatestRelease  andreaskoch/dcsg '_linux_amd64$' \
        /usr/local/bin/dcsg
    chmod +x /usr/local/bin/dcsg

    # Machine
    net::DownloadGithubLatestRelease  docker/machine 'Linux-x86_64$' \
        /usr/local/bin/docker-machine
    chmod +x /usr/local/bin/docker-machine

    # UNMAINTAINED # systemd-docker
    # # DOC: https://github.com/ibuildthecloud/systemd-docker
    # apt::AddPackages systemd-docker

    # x11docker
    # ALT: https://github.com/mviereck/kaptain/raw/master/kaptain_0.73-1_amd64_ubuntu.deb
    apt::AddRemotePackages \
        "http://archive.ubuntu.com/ubuntu/pool/universe/k/kaptain/kaptain_0.73-1_amd64.deb"
    local tmpdir=$( mktemp -d )
    net::Download \
        "https://raw.githubusercontent.com/mviereck/x11docker/master/x11docker" \
        "$tmpdir/x11docker"
    chmod +x "$tmpdir/x11docker"
    chmod 777 "$tmpdir/"
    pushd "$tmpdir"
    sys::Write <<'EOF' "$tmpdir/logname" 0:0 755
#!/bin/bash
EOF
    # xvfb-run --auto-servernum --server-num=3 "$tmpdir/x11docker" --update
    # SUDO_USER=$USER_USERNAME xvfb-run --auto-servernum --server-num=3 "$tmpdir/x11docker" --update
    DISPLAY= SUDO_USER=$USER_USERNAME PATH=.:$PATH "$tmpdir/x11docker" --update
    sys::Chk
    popd
    rm -rf "$tmpdir" "$HOME/timetosaygoodbye.fifo"


    # FIX x11docker launcher
    sys::Write <<'EOF' /usr/local/share/applications/x11docker.desktop
[Desktop Entry]
Encoding=UTF-8
Name=x11docker
Exec=x11docker-gui
Terminal=false
Type=Application
Icon=asc-de
StartupWMClass=kaptain
EOF
    gui::AddAppFolder Runtimes x11docker


    # Kitematic
    local temp=$( mktemp )
    net::DownloadGithubLatestRelease docker/kitematic '-Ubuntu\\.zip$' \
        $temp
    local tempdir=$( mktemp -d )
    unzip "$temp" -d "$tempdir"
    sys::Chk
    apt::AddLocalPackages "$tempdir"/*.deb

    gui::AddAppFolder Runtimes kitematic
    gui::SetAppName kitematic Kitematic
    # TODO THEME: https://github.com/docker/kitematic/blob/master/styles/variables.less

    # TOCHECK GS ext
    # https://extensions.gnome.org/extension/1065/docker-status/
    # gui::AddShellExtensionsById 1065

    chown -hv 1000:1000 $HOME/.wget-hsts
}



app::Virtualbox ()
{
    Meta --desc "VM hypervisor"

    apt::AddSource virtualbox \
        "[arch=amd64] http://download.virtualbox.org/virtualbox/debian" \
        "$(lsb_release -cs) contrib" \
        "https://www.virtualbox.org/download/oracle_vbox_2016.asc"

    # 6.0
    apt::AddPackages virtualbox-6.0
    # 5.0 apt::AddPackages virtualbox-5.2

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        # Fix DKMS vboxhost
        gui::FixDkmsAllModules
        # gui::FixDkmsModule vboxhost
    fi

    # TOSYNC post::Virtualbox post::Virtualbox_NONFREE
    # 5.0 local services="vboxdrv.service vboxballoonctrl-service.service vboxautostart-service.service vboxweb-service.service"
    # 6.0
    local services="vboxdrv.service vboxballoonctrl-service.service vboxautostart-service.service vboxweb-service.service"

    gui::AddAppFolder Runtimes virtualbox
    gui::AddSystemdSwitch vbox "$services" 3

    gui::SetAppProp virtualbox StartupWMClass "VirtualBox Manager"
    gui::SetAppName virtualbox VirtualBox

    # Kvantum theming
    InstallKvantumTheme
    sys::SedInline 's#^(Exec=)(.*)#\1env QT_STYLE_OVERRIDE=kvantum \2#' \
        /usr/local/share/applications/virtualbox.desktop

    # zfs dataset
    if which zpool && zfs::IsDataset "$ZFS_POOL_NAME" ; then

        if [[ "$INSTALL_MODE" == "MenuInstall" ]]; then
            if [[ -n "$ZFS_DATA_DSET" ]] ; then
                local dataset="$ZFS_POOL_NAME/$ZFS_DATA_DSET/$USER_USERNAME/vbox"
            else
                local dataset="$ZFS_POOL_NAME/$ZFS_VIRT_DSET/vbox"
            fi
            zfs::CreateDataset "$dataset" -o mountpoint=$HOME/Virtualbox
        fi
    else
        sys::Mkdir "$HOME/Virtualbox"
    fi

    for srv in $services ; do systemctl mask $srv ; done

    RegisterPostInstall post::Virtualbox 30

    # BUGGED gui::AddShellExtensionsById 308
}



post::Virtualbox ()
{

    # TOSYNC app::Virtualbox
    # 5.0 local services="vboxdrv.service vboxballoonctrl-service.service vboxautostart-service.service vboxweb-service.service"
    # 6.0
    local services="vboxdrv.service vboxballoonctrl-service.service vboxautostart-service.service vboxweb-service.service"

    sys::StartServices $services

    # Configure VM path
    chown 1000:1000 $HOME/Virtualbox
    sudo --set-home -u \#1000 VBoxManage setproperty machinefolder "$HOME/Virtualbox"

    # Disable updates
    sudo --set-home -u \#1000 VBoxManage setextradata global GUI/UpdateDate never
    sys::Chk

    sys::StopServices $services
}



app::Virtualbox_NONFREE ()
{
    Meta --desc "Extension Pack"

    which virtualbox &>/dev/null || app::Virtualbox

    # Virtualbox ExtensionPack
    RegisterPostInstall post::Virtualbox_NONFREE 31

    # Vmware vdiskmanager
    local tmpdir=$( mktemp -d )
    net::DownloadUnzip \
        "https://kb.vmware.com/sfc/servlet.shepherd/version/download/068f4000009EgK0AAK" \
        $tmpdir
    mv $tmpdir/*-vmware-vdiskmanager-linux.* /usr/local/bin/vmware-vdiskmanager
    rm -rf "$tmpdir"
}



post::Virtualbox_NONFREE ()
{
    # TOSYNC app::Virtualbox
    # 5.0 local services="vboxdrv.service vboxballoonctrl-service.service vboxautostart-service.service vboxweb-service.service"
    # 6.0
    local services="vboxdrv.service vboxballoonctrl-service.service vboxautostart-service.service vboxweb-service.service"
    sys::StartServices $services

    local vboxVersion=$( VBoxManage --version )
    vboxVersion=${vboxVersion%%r*}
    vboxVersion=${vboxVersion%%_*}

       [[ -n "$vboxVersion" ]] \
    && vbox::InstallExtensionPack_NONFREE $vboxVersion \
    || sys::Die "Failed to install Virtualbox ExtensionPack"

    sys::StopServices $services
}



app::Wine ()
{
    Meta --no-default true \
         --desc "Win32 compatibility layer"

    [[ "$UBUNTU_RELEASE" == "xenial" ]] && return

    # 32bit support
    dpkg --add-architecture i386
    sys::Chk
    apt::Update

    apt::AddSource winehq \
        "http://dl.winehq.org/wine-builds/ubuntu/" \
        "bionic main" \
        "https://dl.winehq.org/wine-builds/winehq.key"

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        # WORKAROUND apt version break on libglib2.0-0, libglib2.0-bin
        # DEV: [i386+amd64] upgrade required to exceed gnome ppa [amd64] version
        # DEV: using bionic versions
        apt::AddRemotePackages \
            "https://launchpad.net/ubuntu/+archive/primary/+files/libglib2.0-0_2.56.1-2ubuntu1_i386.deb" \
            "https://launchpad.net/ubuntu/+archive/primary/+files/libglib2.0-0_2.56.1-2ubuntu1_amd64.deb" \
            "https://launchpad.net/ubuntu/+archive/primary/+files/libglib2.0-bin_2.56.1-2ubuntu1_i386.deb" \
            "https://launchpad.net/ubuntu/+archive/primary/+files/libglib2.0-bin_2.56.1-2ubuntu1_amd64.deb"
    fi
    apt::AddPackages wine-stable
    gui::AddAppFolder Runtimes wine winetricks

    # # UPD winetricks
    # apt::AddPackages cabextract unzip p7zip zenity # deps
    # net::Download \
    #     "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks" \
    #     "/usr/local/bin/winetricks"
    # chmod +x /usr/local/bin/winetricks
    # gui::AddAppFolder Runtimes winetricks

    # vineyard
    apt::AddPpaPackages cybolic/vineyard-testing vineyard
    gui::AddAppFolder Runtimes vineyard-preferences
    gui::SetAppName vineyard-preferences "Wine"
    mv /etc/xdg/autostart/vineyard-indicator.desktop{,.ORIG}

    # TODO q4wine
    # https://sourceforge.net/projects/q4wine/
}
