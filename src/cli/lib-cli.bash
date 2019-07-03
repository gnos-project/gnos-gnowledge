# ▌  ▗ ▌   ▞▀▖▌  ▜▘
# ▌  ▄ ▛▀▖ ▌  ▌  ▐
# ▌  ▐ ▌ ▌ ▌ ▖▌  ▐
# ▀▀▘▀▘▀▀  ▝▀ ▀▀▘▀▘



    ###########
    # HELPERS #
    ###########


pip::Install ()
{
    cli::Python
    HOME=/root pip3 install $*
    sys::Chk
}
npm::Install ()
{
    cli::Node
    sudo --set-home -u \#1000 bash -c \
        "( source ~/.nvm/nvm.sh ; npm install -g $* ; )"
    sys::Chk
}
npm::UserInstall () # DEV: USED BY THEME BUILDER
{
    cli::Node
    sudo --set-home -u \#1000 bash -c \
        "( source ~/.nvm/nvm.sh ; npm install $* ; )"
    sys::Chk
}

gem::UserInstall ()
{
    cli::Ruby
    sudo --set-home -u \#1000 bash -c \
        "( source /etc/profile.d/rvm.sh ; gem install $* ; )"
    sys::Chk
}
gem::Install ()
{
    cli::Ruby
    # sudo --set-home -u \#1000
    bash -c \
        "( source /etc/profile.d/rvm.sh ; rvm @global do gem install $* ; )"
    sys::Chk
}

gog::Install ()
{
    cli::Golang
    for i in "$@" ; do
        sudo --set-home -u \#1000 bash -c \
            'source ~/.gvm/scripts/gvm ; go get -u '"$i"
        sys::Chk
    done
}



    ##############
    # INSTALLERS #
    ##############


cli::Neofetch ()
{
    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages dawidd0811/neofetch neofetch
    else
        apt::AddPackages neofetch
    fi

    sys::Write <<'EOF' /etc/apt/apt.conf.d/99update-stats
APT::Update::Post-Invoke-Success {"/usr/lib/update-notifier/apt-check >/dev/null 2>/var/lib/apt/periodic/update-stats  || true";};
DPkg::Post-Invoke {"/usr/lib/update-notifier/apt-check >/dev/null 2>/var/lib/apt/periodic/update-stats  || true";};
EOF

    sys::Write <<'EOF' /etc/neofetch/config.conf 1000:1000
print_info() {

    info "Model     " model
    info "CPU       " cpu
    info "GPU       " gpu
    info "Kernel    " kernel
    info "Booted    " uptime

    info line_break
    info "Default IP" ip_config
    if [[ -n "$nic" ]] ; then
        info "Public IP " ip_public
        info "Config NS " dns_config
        info "Public NS " dns_public
    fi

    info line_break
    info "CPU usage " cpu_usage
    info "Memory    " memory
    info "Disk  " disk
    info "Battery  " battery

    info line_break
    info "Packages  " packages
    info "Upgraded  " upgrade_last
    info "Updated   " update_last
    info "Updates   " updates_available
    info "Security  " updates_security
}


get_updates_available ()
{
    updates_available=$( cut -d';' -f1 /var/lib/apt/periodic/update-stats )
    [[ "$updates_available" == "0" ]] && unset updates_available || updates_available=$(color 3)$updates_available
}

get_updates_security ()
{
    updates_security=$( cut -d';' -f2 /var/lib/apt/periodic/update-stats )
    [[ "$updates_security" == "0" ]] && unset updates_security || updates_security=$(color 1)$updates_security
}

get_upgrade_last ()
{
    local ud=$(
          tac /var/log/apt/history.log 2>/dev/null \
        | awk ' $1=="End-Date:"{u=0;d=$2" "$3}
                $1=="Upgrade:"{u=1}
                $1=="Start-Date:"{if (u) {print d;exit 0}}'
    )

    [[ -n "$ud" ]] && upgrade_last=$( timestamp $( date -d "$ud" "+%s" ) )
}

get_update_last ()
{
    local stamp=/var/lib/apt/periodic/update-success-stamp
    update_last=$( timestamp $( stat --format=%Y "$stamp" ) )
}

timestamp ()
{
    if [[ "$dates_human" == "on" ]] ; then
        timestamp2human $1
    else
        date -d @$1 "+%Y-%m-%d %H:%M"
    fi
}

timestamp2human ()
{
    local now=$( date -d now "+%s" )
    local mins=$((  ( $now - $1 ) /60 ))
    local hours=$((  ( $now - $1 ) /3600 ))
    [[ $hours -gt 168 ]] && echo -n $(color 3)

    local val unit
    if   [[ $mins -le 59 ]]   ; then val=$mins          ; unit=minute
    elif [[ $hours -gt 720 ]] ; then val=$((hours/720)) ; unit=month
    elif [[ $hours -gt 168 ]] ; then val=$((hours/168)) ; unit=week
    elif [[ $hours -gt 24 ]]  ; then val=$((hours/ 24)) ; unit=day
    else                             val=$hours         ; unit=hour
    fi
    [[ $val -ne 1 ]] && unit="${unit}s"
    echo "$val $unit ago"
}

get_uptime ()
{
    seconds="$(< /proc/uptime)"
    seconds="${seconds/.*}"
    uptime=$( timestamp $((  $( date -d now "+%s" ) - $seconds )) )
}

get_ip_config ()
{
    ip_config=$( net::GetDefaultAddress )
    if [[ -n "$ip_config" ]] ;then
        ip_config=$( printf "%-15s" $ip_config )" $HOSTNAME"
        nic=$( net::GetDefaultNic )
        [[ -n "$nic" ]] && ip_config="$ip_config ($nic)"
    fi
}

get_ip_public ()
{
    ip_public=$( net::GetPublicAddress )
       [[ $ip_public =~ ^[1-9] ]] \
    && ip_public=$( printf "%-15s" $ip_public )" "$( net::GetDnsReverse $ip_public ) \
    || ip_public=$(color 3)"[Unknown]"
}

get_dns_config ()
{
    dns_config=$( net::GetDefaultDns )
    [[ -n "$dns_config" ]] \
    && dns_config=$( printf "%-15s %s %s %s" $dns_config ) \
    || dns_config=$(color 1)"[None]"
}

get_dns_public ()
{
    dns_public=$( net::GetPublicDns )
       [[ $dns_public =~ ^[1-9] ]] \
    && dns_public=$( printf "%-15s" $dns_public )" "$( net::GetDnsReverse $dns_public ) \
    || dns_public=$(color 3)"[Unknown]"
}


# NET HELPERS
net::GetDefaultAddress ()
{
  ip address show $(net::GetDefaultNic) | awk '$1=="inet"{print $2; exit}'
}
net::GetDefaultDns ()
{
  if net::IsNetworkManagerDns ; then
    nmcli -f IP4.DNS device show $( net::GetDefaultNic ) | awk '{print $2}'
  else
    awk '$1=="nameserver" {print $2}' /etc/resolv.conf
  fi
}
net::GetPublicAddress ()
{
  dig -4 +time=0 +tries=0 +retry=0 +short whoami.akamai.net. @193.108.88.1 \
    2>/dev/null
  # ALT dig -4 +time=0 +tries=0 +retry=0 myip.opendns.com. @resolver1.opendns.com.
}
net::GetPublicDns ()
{
  # dig -4 +time=0 +tries=0 +retry=0 +short 109.0.65.2 \
  dig -4 +time=0 +tries=0 +retry=0 +short whoami.akamai.net. \
    2>/dev/null
}
net::GetDefaultNic ()
{
  ip route | awk '$1=="default"{print $5; exit 0}'
}
net::IsNetworkManagerDns ()
{
    local nmdns=127.0.0.53 # DEV: XENIAL 127.0.1.1, BIONIC 127.0.0.53
     awk -v nmdns="$nmdns" '$1=="nameserver" {if (nm==0 && $2==nmdns) {nm=1} else {nm=2}} END { if (nm==1) exit 0; exit 2;}' /etc/resolv.conf \
  && ps -u nobody --no-headers -o args | grep '^/usr/sbin/dnsmasq .*--listen-address='$nmdns' .* --conf-dir=/etc/NetworkManager/dnsmasq.d' >/dev/null
}
net::GetDnsReverse () # 192.168.1.32 @192.168.1.1
{
    local rev=$( dig -4 +time=0 +tries=0 +retry=0 +short -x $* 2>/dev/null 2>/dev/null )
    [[ ! $rev =~ ^\; ]] && echo ${rev%.} || echo $(color 3)"[Unknown]"
}


# WORKAROUND trim alignment
trim()
{
    builtin echo -E "${1}"
}

# WORKAROUND user config file creation
config_file=/etc/neofetch/config.conf


# STYLING
colors=(208 251 241 33 0 251) # title, @, underline, subtitle, colon, info

bar_length=15
bar_color_elapsed=208
bar_color_total=241
bar_border="off"
bar_char_elapsed="▬"
bar_char_total="▬"

underline_char="─"

cpu_temp=C
cpu_display=barinfo
memory_display=barinfo
disk_display=barinfo
battery_display=barinfo

kernel_shorthand=on
distro_shorthand=off
dates_human=on
EOF

    sys::Write --append <<EOF /etc/neofetch/config.conf 1000:1000

image_backend=ascii
if [[ \$TERM =~ 256 ]] ; then
    ascii_length_force=42
    image_source=/usr/share/themes/$THEME_GS/branding/logo.ansi
else
    ascii_length_force=21
    image_source=/usr/share/themes/$THEME_GS/branding/logo-min.ansi
fi
EOF

    local bashrc=$HOME/.bashrc
    [[ -d "$HOME/.bashrc.d" ]] && bashrc=$HOME/.bashrc.d/10_neofetch
    sys::Write --append <<'EOF' $bashrc 1000:1000
if shopt -q login_shell ; then
    neofetch --config none
fi
EOF

    # Disable ALL motd
    RegisterPostInstall post::Neofetch 90
}

post::Neofetch ()
{
    sys::Mkdir /etc/update-motd.d/real
    for i in /etc/update-motd.d/??-* ; do
        dpkg-divert --add --rename --divert "/etc/update-motd.d/real/$( basename $i )" "$i"
        sys::Chk
    done

    dpkg-divert --add --rename --divert /etc/legal.real /etc/legal
    sys::Touch /etc/legal
}


cli::Direnv ()
{
    apt::AddPackages direnv

    # bash
    local bashrc=$HOME/.bashrc
    [[ -d "$HOME/.bashrc.d" ]] && bashrc=$HOME/.bashrc.d/85_direnv
    sys::Write --append <<'EOF' $bashrc 1000:1000
# direnv
eval "$(direnv hook bash)"
EOF

    # zsh
    sys::Write --append <<'EOF' $HOME/.zshrc 1000:1000

# direnv
eval "$(direnv hook zsh)"
EOF

    # fish
    sys::Write --append <<'EOF' $HOME/.config/fish/config.fish 1000:1000

# direnv
eval (direnv hook fish)
EOF

    # direnvrc: layout python-venv
    # DOC: https://github.com/direnv/direnv/wiki/Python#venv-stdlib-module
    sys::Write --append <<'EOF' ~/.config/direnv/direnvrc 1000:1000
realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
layout_python-venv() {
    local python=${1:-python3}
    [[ $# -gt 0 ]] && shift
    unset PYTHONHOME
    if [[ -n $VIRTUAL_ENV ]]; then
        VIRTUAL_ENV=$(realpath "${VIRTUAL_ENV}")
    else
        local python_version
        python_version=$("$python" -c "import platform; print(platform.python_version())")
        if [[ -z $python_version ]]; then
            log_error "Could not detect Python version"
            return 1
        fi
        VIRTUAL_ENV=$PWD/.direnv/python-venv-$python_version
    fi
    export VIRTUAL_ENV
    if [[ ! -d $VIRTUAL_ENV ]]; then
        log_status "no venv found; creating $VIRTUAL_ENV"
        "$python" -m venv "$VIRTUAL_ENV"
    fi
    PATH_add "$VIRTUAL_ENV/bin"
}
EOF
}


cli::Python ()
{
    [[ -f "$HOME/.config/pip/pip.conf" ]] && return

    # PIP3
    apt::AddPackages python3-pip python3-gi python3-dev
    HOME=/root pip3 install --upgrade pip
    sys::Chk

    # WORKAROUND
    hash -r pip3

    HOME=/root pip3 install setuptools
    sys::Chk
    HOME=/root pip3 install wheel
    sys::Chk
    sys::Write <<'EOF' $HOME/.config/pip/pip.conf 1000:1000 755
[list]
format=columns
EOF
    sys::Copy $HOME/.config/pip/pip.conf /root/.config/pip/

    # PIP2
    apt::AddPackages python-pip python-requests
    HOME=/root pip2 install --upgrade pip
    sys::Chk

    # WORKAROUND
    hash -r pip2

    HOME=/root pip2 install setuptools
    sys::Chk
    HOME=/root pip2 install wheel
    sys::Chk
}


cli::Php ()
{
    apt::AddPackages php-cli

    # composer
    local tempdir=$( mktemp -d )
    php -r "copy('https://getcomposer.org/installer', '$tempdir/composer-setup.php');"
    sys::Chk
    EXPECTED_SIGNATURE=$( wget https://composer.github.io/installer.sig -O - -q )
    ACTUAL_SIGNATURE=$( php -r "echo hash_file('SHA384', '$tempdir/composer-setup.php');" )
    [[ "$EXPECTED_SIGNATURE" == "$ACTUAL_SIGNATURE" ]] || sys::Die "$tempdir/composer-setup.php: Invalid installer signature"
    php $tempdir/composer-setup.php --install-dir=/usr/local/bin # --quiet
    sys::Chk
    mv /usr/local/bin/composer{.phar,}
    rm -rf $tempdir
    chown -hR 1000:1000 $HOME/.composer/

    # prestissimo
    apt::AddPackages php-curl
    sudo --set-home -u \#1000 \
        composer global require hirak/prestissimo

    # usual deps
    apt::AddPackages php-mbstring php-xml
    sys::SedInline 's/^;(opcache.enable_cli=1)/\1/' /etc/php/*/cli/php.ini
}


cli::Node () # node.js + nvm + npm
{
    [[ -d "$HOME/.nvm" ]] && return

    # WORKAROUND
    cp -p $HOME/.bashrc{,.SAVE}
    sys::Write $HOME/.bashrc <<<""

      net::Download https://raw.githubusercontent.com/creationix/nvm/v0.33.8/install.sh \
    | sudo --set-home -u \#1000 bash

    sudo --set-home -u \#1000 \
        bash -c 'source ~/.nvm/nvm.sh && nvm install "lts/*" && nvm alias default "lts/*"'
        # bash -c 'source ~/.nvm/nvm.sh && nvm install stable && nvm alias default stable'
    sys::Chk

    # WORKAROUND
    local bashrc=$HOME/.bashrc
    if [[ -d "$HOME/.bashrc.d" ]] ; then
        bashrc=$HOME/.bashrc.d/nvm
        sys::Write $bashrc <<<'[[ -r ~/.bashrc.d/nvm ]] || return'
        cat $HOME/.bashrc >$bashrc
        mv $HOME/.bashrc{.SAVE,}
    else
        bashrc=$HOME/.nvm/bashrc
        mv $HOME/.bashrc{.SAVE,}
        sys::Write --append $HOME/.bashrc <<<'[[ -r ~/.nvm/bashrc ]] && source ~/.nvm/bashrc'
    fi

        sys::Write --append <<'EOF' "$bashrc" 1000:1000
# npm: disable update notifier, https://github.com/yeoman/update-notifier#user-settings
export NO_UPDATE_NOTIFIER=1
EOF

        sys::Write <<'EOF' "$HOME/.config/configstore/update-notifier-npm.json" 1000:1000
{
    "optOut": true
}
EOF

    chown -hR 1000:1000 $HOME/.config/configstore
}


cli::Ruby ()
{
    [[ -f "/etc/profile.d/rvm.sh" ]] && return

    # ALT: curl -sSL https://get.rvm.io | bash -s stable
    # TIP: NO AUTOLIBS: bash -s -- --autolibs=read-fail

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages rael-gc/rvm rvm
        apt::AddPackages libgmp3-dev

        # WORKAROUND BUG in rvm dpkg scripts
        rm -rf $HOME/1

        (
            set +x
            source /etc/profile.d/rvm.sh

            rvm autolibs disable
            sys::Chk
            rvm requirements
            sys::Chk
            rvm rvmrc warning ignore all.rvmrcs
            sys::Chk

            rvm install ruby
            sys::Chk
        )

    else # BIONIC

        apt::AddPackages gpg
        net::Download "https://rvm.io/mpapis.asc"     | sudo --set-home -u \#1000 gpg --import -
        net::Download "https://rvm.io/pkuczynski.asc" | sudo --set-home -u \#1000 gpg --import -

        net::Download "https://get.rvm.io" | bash -s stable

        adduser $( id -nu 1000 ) rvm
        sys::Chk
        adduser root rvm
        sys::Chk

        # TOCHECK
        # rvm autolibs disable
        # rvm requirements
        # rvm rvmrc warning ignore all.rvmrcs

        (
            set +x
            source /etc/profile.d/rvm.sh

            rvm pkg install openssl
            sys::Chk
            DYLD_LIBRARY_PATH= rvm install 1.8.7 -C --with-openssl-dir=/usr/local/rvm/usr
            sys::Chk
            DYLD_LIBRARY_PATH= rvm install 2.5 # -C --with-openssl-dir=/usr/local/rvm/usr
            sys::Chk

            rvm remove 1.8.7
            sys::Chk
            rvm use 2.5 --default
            sys::Chk

            gem update --system
            sys::Chk
        )

    fi

    # CONF: GEM will not install documentation files
    sys::Write --append <<'EOF' "$HOME/.gemrc" 1000:1000
gem: --no-document
EOF

    # WORKAROUND
    sys::Write --append <<'EOF' "$HOME/.rvmrc" 1000:1000
export rvm_autoupdate_flag=2
export rvm_silence_path_mismatch_check_flag=1
EOF

    # WORKAROUND: interactive help
    local bashrc=$HOME/.bashrc
    [[ -d "$HOME/.bashrc.d" ]] && bashrc=$HOME/.bashrc.d/rvm
    sys::Write --append <<'EOF' "$bashrc" 1000:1000
if [[ "$( id -u )" != "0" ]] ; then
    source /etc/profile.d/rvm.sh
    alias rvm="PAGER= rvm"
fi
EOF

    # Clean perms
    chown -hR 1000:1000 $HOME/.rvm*

    # Install bundler
    gem::UserInstall bundler
}


cli::Golang ()
{
    [[ -d $HOME/.gvm ]] && return

    # WORKAROUND
    cp -p $HOME/.bashrc{,.SAVE}
    sys::Write $HOME/.bashrc <<<""

    apt::AddPackages git bison

      net::Download https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer \
    | sudo --set-home -u \#1000 bash

    sudo --set-home -u \#1000 bash -c "source ~/.gvm/scripts/gvm \
        && goVers=\$( gvm listall | grep -E '^\s*go[0-9.]+$' | sort -Vr | head -1 ) \
        && gvm install go1.4 --binary \
        && gvm install \$goVers --binary \
        && gvm alias create default \$goVers \
        && gvm uninstall go1.4"
    sys::Chk

    # WORKAROUND
    local bashrc=$HOME/.bashrc
    [[ -d "$HOME/.bashrc.d" ]] && bashrc=$HOME/.bashrc.d/gvm
    sys::Write --append <<'EOF' "$bashrc" 1000:1000
[[ -s "$HOME/.gvm/scripts/gvm" ]] && source "$HOME/.gvm/scripts/gvm"
EOF
    mv $HOME/.bashrc{.SAVE,}

}




cli::Jq ()
{
    which jq &>/dev/null && return

    apt::AddPackages jq

}


cli::Mail ()
{
    # Local mail delivery with femtomail
    # DOC: https://git.lekensteyn.nl/femtomail/tree/README.md
    local tmpdir=$( mktemp -d )
    net::Download "https://git.lekensteyn.nl/femtomail/plain/Makefile" $tmpdir/
    net::Download "https://git.lekensteyn.nl/femtomail/plain/femtomail.c" $tmpdir/
    pushd $tmpdir
    make USERNAME=$USER_USERNAME MAILBOX_PATH=/home/$USER_USERNAME/.local/share/localhost.Maildir
    sys::Chk
    make install setcap
    sys::Chk
    popd
    apt::AddPackages lsb-invalid-mta
    mv /usr/sbin/sendmail{,.lsb-invalid-mta}
    sys::Chk
    update-alternatives --install /usr/sbin/sendmail mta /usr/sbin/sendmail.lsb-invalid-mta 25
    sys::Chk
    update-alternatives --install /usr/sbin/sendmail mta /usr/sbin/femtomail 25
    sys::Chk
    update-alternatives --set mta /usr/sbin/femtomail
    sys::Chk
    sys::Write <<EOF /$HOME/.local/share/localhost.Maildir/new/$( date -d now "+%s" ).1.localhost 1000:1000
Date: $( date )
From: root
Subject: Local mail initialized

Enjoy $PRODUCT_NAME
EOF
# TIP sendmail DEST_EMAIL < <( echo -e "Subject: SUBJECT\nFrom: FROM_NAME <FROM_EMAIL>\n\nBODY" )

}


cli::Ssh ()
{

    apt::AddSelection "iptables-persistent iptables-persistent/autosave_v6 boolean false"
    apt::AddSelection "iptables-persistent iptables-persistent/autosave_v4 boolean false"
    apt::AddPackages iptables-persistent

    apt::AddPackages \
        ssh ssh-import-id sshfs \
        proxytunnel rssh autossh sshuttle \
        fail2ban # TIP: fail2ban unban ip: fail2ban-client set sshd unbanip 10.0.2.2
        # ssh-askpass

    sed -i -E 's#^(\s*HostKey )#\# \1#' /etc/ssh/sshd_config

    # DOC: ssh & sshd advanced configuration
    # https://github.com/stribika/duraconf/blob/master/configs/sshd/sshd-pfs_config

    sys::Write --append <<'EOF' /etc/ssh/sshd_config

##########
# CRYPTO # # DOC: https://stribika.github.io/2015/01/04/secure-secure-shell.html
##########

# Key exchange
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256

# Symmetric ciphers
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr

# Message authentication codes
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com

############
# SECURITY #
############

# Server authentication
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# User Authentication
AllowGroups users

# Disable password authentication
# PasswordAuthentication no
# ChallengeResponseAuthentication no

###############
# PERFORMANCE #
###############

UseDNS no

EOF


    sys::Write <<'EOF' /etc/ssh/ssh_config

###########
# DEFAULT #
###########

Host *

    ##########
    # CRYPTO # # DOC: https://stribika.github.io/2015/01/04/secure-secure-shell.html
    ##########

    # Key exchange
    KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256

    # Client authentication
    HostKeyAlgorithms ssh-ed25519-cert-v01@openssh.com,ssh-rsa-cert-v01@openssh.com,ssh-ed25519,ssh-rsa

    # Symmetric ciphers
    Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr

    # Message authentication codes
    MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com

    ############
    # SECURITY #
    ############

    # Disable password authentication
    # PasswordAuthentication no
    # ChallengeResponseAuthentication no

    # Enable VisualHostKey
    # VisualHostKey yes

    # Permit auto-completion
    HashKnownHosts no

    ###############
    # PERFORMANCE #
    ###############

    # Enable Compression
    Compression yes

    # Enable ControlMaster
    # TIP: ssh -O check host.com
    # TIP: ssh -O exit host.com
    ControlMaster auto
    ControlPath ~/.ssh/%r@%h:%p
    ControlPersist 600

    # # DEFAULT Disable GSSAPI
    # # DEFAULT GSSAPIAuthentication no
    # # DEFAULT GSSAPIDelegateCredentials no


##########
# PUBLIC #
##########

Host *.onion
    ProxyCommand socat - SOCKS4A:localhost:%h:%p,socksport=9050
    VerifyHostKeyDNS no

Host github.com
    KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256,diffie-hellman-group-exchange-sha1,diffie-hellman-group14-sha1

Host heroku.com
    KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256,diffie-hellman-group14-sha1,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group1-sha1
    MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com,hmac-sha1


###########
# PRIVATE #
###########

# Host example
#   HostName server.example.com
#   IdentityFile       ~/.ssh/id_rsa_example
#   UserKnownHostsFile ~/.ssh/alt_host_file
#   User root
#   CompressionLevel 9
#   ControlPersist 0
#   OLD ProxyCommand ssh -q -W %h:%p gateway.example.com
#   NEW ProxyJump user1@jumphost1.example.org:22,user2@jumphost2.example.org:2222


EOF

    # Key exchange
    local modFile=$( mktemp )
    awk '$5 > 2000' /etc/ssh/moduli >"$modFile"
    local modCount=$( awk '{print $1}' <( wc -l "$modFile" ) )
    if [[ $modCount -gt 1 ]] ; then
        cp /etc/ssh/moduli{,.ORIG}
        cat "$modFile" > /etc/ssh/moduli
    else # DEV: 8min
        ssh-keygen -G "$modFile" -b 4096
        sys::Chk
        ssh-keygen -T /etc/ssh/moduli -f "$modFile"
        sys::Chk
    fi
    rm "$modFile"

    # Server authentication
    rm /etc/ssh/ssh_host_*key*
    ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key     </dev/null
    sys::Chk
    ssh-keygen -t ed25519     -f /etc/ssh/ssh_host_ed25519_key </dev/null
    sys::Chk

    # Client authentication
    rm "$HOME/.ssh/id_"*
    sys::Mkdir "$HOME/.ssh/"
    sudo --set-home -u \#1000 ssh-keygen \
        -t rsa -b 4096 -o -a 100 -f "$HOME/.ssh/id_rsa"     -N ""
    sys::Chk
    sudo --set-home -u \#1000 ssh-keygen \
        -t ed25519     -o -a 100 -f "$HOME/.ssh/id_ed25519" -N ""
    sys::Chk
    chown -hR 1000:1000 "$HOME/.ssh/"

    # Replace IRFS dropbear authorized_keys with user key
    if str::InList SSH_UNLOCK $STORAGE_OPTIONS ; then
        rm "$HOME/.ssh/dropbear.id_rsa"
        echo -n 'command="/bin/unlock" ' \
            >/etc/initramfs-tools/root/.ssh/authorized_keys
        cat "$HOME/.ssh/id_rsa.pub" \
            >>/etc/initramfs-tools/root/.ssh/authorized_keys
        update-initramfs -u
    fi
}


cli::Tmux ()
{

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        # 2.7 from PPA
        apt::AddPpaPackages superstructor/devops tmux
    else
        # 2.6 from repo
        apt::AddPackages tmux
    fi

        sys::Write --append <<'EOF' $HOME/.tmux.conf 1000:1000
# Fix windows numbers
set-option -g base-index 1
set-window-option -g pane-base-index 1
set-option -g renumber-windows on

# Fix keyboard: Window 10
bind-key 0 select-window -t :10

# Fix keyboard: Remap prefix: Ctrl+a
unbind C-b
set -g prefix C-a
bind C-a send-prefix
# TIP: Ctrl+a twice in bash

# Fix keyboard: split panes using | and -
bind | split-window -h
bind - split-window -v
unbind '"'
unbind %

bind -n C-M-n new-window
#bind -n C-M-w confirm kill-window

# Fix keyboard: Switch windows using Ctrl+Alt+ARROW without prefix
bind -n C-M-Left previous-window
bind -n C-M-Right next-window

# Fix keyboard: Switch sessions using Ctrl+Alt+ARROW without prefix
bind -n C-M-Up switch-client -p
bind -n C-M-Down switch-client -n

# Fix keyboard: Reload config file: 'C-r'
bind r source-file ~/.tmux.conf

# Fix keyboard: Enable xterm keys
set-window-option -g xterm-keys on

# Fix mouse
set -g mouse on
bind -n WheelUpPane if-shell -F -t = "#{mouse_any_flag}" "send-keys -M" "if -Ft= '#{pane_in_mode}' 'send-keys -M' 'select-pane -t=; copy-mode -e; send-keys -M'"
bind -n WheelDownPane select-pane -t= \; send-keys -M
bind-key -n MouseDrag1Status swap-window -t=

# Fix history
set -g history-limit 99999

# Copy selection to os clipboard
set-option -s set-clipboard off
unbind -n -Tcopy-mode-vi MouseDragEnd1Pane
bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xsel -i --clipboard"
bind-key -T copy-mode    MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xsel -i --clipboard"

# Set xterm title
set -g set-titles on
set -g set-titles-string "#T" # DEV: "window name — hostname" '#H:#S.#I.#P #W #T' # window number,program name, active(or not)

# Fix login shell
set -g default-command "${SHELL}"

# Theming: Set inactive/active window bg
set -g window-style 'fg=default,bg=colour233'
set -g window-active-style 'fg=default,bg=black'

# Theming: Set pane border
set -g pane-border-fg colour236
set -g pane-active-border-fg colour208
set -g pane-border-bg colour233
set -g pane-active-border-bg colour233

# Fix SSH agent when tmux is detached
set-environment -g SSH_AUTH_SOCK $HOME/.ssh/ssh_auth_sock

# TPM https://github.com/tmux-plugins/tpm
set-environment -g TMUX_PLUGIN_MANAGER_PATH '~/.tmux/plugins/'
set -g @plugin '~/.tmux-plugins/tpm'
source-file ~/.tmux/plugins.tmux
run -b '~/.tmux/plugins/tpm/tpm'

EOF


    # bash
    local bashrc=$HOME/.bashrc
    [[ -d "$HOME/.bashrc.d" ]] && bashrc=$HOME/.bashrc.d/tmux
        sys::Write --append <<'EOF' "$bashrc" 1000:1000
# Fix tmux TERM
[[ "$TERM" == "xterm" ]] && TERM=screen-256color

# Disable XON/XOFF
[[ $- == *i* ]] && stty -ixon
EOF

    # zsh
    which zsh && sys::Write --append <<'EOF' $HOME/.zshrc 1000:1000

# Fix tmux TERM
[[ "$TERM" == "xterm" ]] && TERM=screen-256color
EOF


    # YANK copy paste
    apt::AddPackages xsel
    sys::Write --append <<'EOF' $HOME/.tmux/plugins.tmux 1000:1000

# https://github.com/tmux-plugins/tmux-yank
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @yank_selection_mouse 'clipboard'
EOF

    # tmux-resurrect
    sys::Write --append <<'EOF' $HOME/.tmux/plugins.tmux 1000:1000

# https://github.com/tmux-plugins/tmux-resurrect
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @resurrect-capture-pane-contents 'on'
set -g @resurrect-strategy-vim 'session'
EOF
# set -g @resurrect-se-shell-history 'on'

    # tmux-continuum
    sys::Write --append <<'EOF' $HOME/.tmux/plugins.tmux 1000:1000

# https://github.com/tmux-plugins/tmux-continuum
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @continuum-restore 'on'
EOF

    # Install TMP plugins
    sudo --set-home -u \#1000 git clone --depth=1 https://github.com/tmux-plugins/tpm $HOME/.tmux/plugins/tpm
    sys::Chk

    sudo --set-home -u \#1000 $HOME/.tmux/plugins/tpm/bin/install_plugins
    sys::Chk

    # TODO tmuxinator
    # gem::UserInstall tmuxinator
    # net::Download \
    #     https://raw.githubusercontent.com/tmuxinator/tmuxinator/master/completion/tmuxinator.bash \
    #     $HOME/.bashrc.d/completion.tmuxinator
}


cli::Z ()
{
    # z - jump around https://github.com/rupa/z
    net::Download \
        "https://raw.githubusercontent.com/rupa/z/master/z.1" \
        /usr/local/share/man/man1/
    net::Download \
        "https://raw.githubusercontent.com/rupa/z/master/z.sh" \
        "$HOME/.bashrc.d/81_z"
    sys::Touch "$HOME/.z"
    chown 1000:1000 "$HOME/.bashrc.d/81_z"

    # fish z
    if which fish ; then
     
        net::Download \
            https://raw.githubusercontent.com/mnacamura/z-fish/master/z.fish \
            $HOME/.config/fish/z.fish

        sys::Write --append <<'EOF' $HOME/.config/fish/config.fish 1000:1000
# z https://github.com/mnacamura/z-fish
source $HOME/.config/fish/z.fish

EOF
        chown 1000:1000 \
            "$HOME/.config/fish/z.fish" \
            "$HOME/.config/fish/config.fish"

    fi

}


cli::Hstr ()
{
    local $tempdir="$( mktemp -d )"
    net::DownloadGithubLatestRelease dvorka/hstr \
        '/hh-.*-bin-64b\\.tgz$' \
        "$tempdir/hh.tgz"
    tar --directory /usr/local/bin -xzvf "$tempdir/hh.tgz"
    sys::Chk
    rm -rf "$tempdir"

    # bash
    local bashrc=$HOME/.bashrc
    [[ -d "$HOME/.bashrc.d" ]] && bashrc=$HOME/.bashrc.d/70_history
        sys::Write --append <<'EOF' "$bashrc" 1000:1000

# HSTR DOC: https://github.com/dvorka/hstr/
export HH_CONFIG="keywords,hicolor,noconfirm"
bind '"\C-r": "\C-a hh -- \C-j"'
EOF

    # zsh
       [[ -f $HOME/.zshrc ]] \
    && sys::Touch "$HOME/.zsh_history" 1000:1000 \
    && sys::Write --append <<'EOF' "$HOME/.zshrc" 1000:1000

# HSTR DOC: https://github.com/dvorka/hstr/
export HH_CONFIG="keywords,hicolor,noconfirm"
bindkey -s "\C-r" "\eqhh --\n"
EOF
}


cli::Powerline ()
{
    # DEPS: pip
    cli::Python

    # DEPS: pygit2
    apt::AddPackages python3-pygit2

    # INST
    pip::Install git+https://github.com/Lokaltog/powerline

    HOME=/root pip3 show powerline-status # DEBUG

    local pipPath=$( HOME=/root pip3 show powerline-status \
                   | awk '$1=="Location:"{print $2}'
                   ) # TIP: /usr/local/lib/python3.6/dist-packages
    [[ -z "$pipPath" ]] && sys::Die "Failed to identify powerline location"

    # EXT: gitstatus
    # DOC: https://github.com/jaspernbrouwer/powerline-gitstatus#installation
    pip::Install powerline-gitstatus

    # EXT: netns
    sys::Write <<'EOF' "$pipPath/powerline_netns/__init__.py" 0:0 644
from .segment import netns
EOF
    sys::Write <<'EOF' "$pipPath/powerline_netns/segment.py" 0:0 644
import string, os
from subprocess import PIPE, Popen
from powerline.segments import Segment
from powerline.theme import requires_segment_info


@requires_segment_info
class NetnsSegment(Segment):
    pl = None

    def execute(self, command):
        self.pl.debug('Executing command: %s' % ' '.join(command))

        proc = Popen(command, stdout=PIPE, stderr=PIPE)
        out, err = [item.decode('utf-8') for item in proc.communicate()]

        if out:
            self.pl.debug('Command output: %s' % out.strip(string.whitespace))
        if err:
            self.pl.debug('Command errors: %s' % err.strip(string.whitespace))

        return out.splitlines(), err.splitlines()

    def __call__(self, pl, segment_info):
        self.pl = pl
        pl.debug('Running Netns')

        return self.build_segments()

    def build_segments(self):
        self.pl.debug('Build Context segment')

        netns_name, err = self.execute(['ip', 'netns', 'identify', str(os.getpid())])

        if not err and netns_name:
            netns_name = netns_name.pop(0)
            if netns_name:
                return [{
                    'contents': netns_name,
                    'highlight_groups': ['netns'],
                }]

        return []


netns = NetnsSegment()
EOF


    sys::Write <<'EOF' $HOME/.config/powerline/colorschemes/default.json 1000:1000 644
{
  "groups": {
    "warning:regular":           { "fg": "white",           "bg": "gnos:manage", "attrs": ["bold"] },
    "critical:failure":          { "fg": "white",           "bg": "gnos:manage", "attrs": ["bold"] },
    "user":                      { "fg": "white",           "bg": "gnos:select", "attrs": ["bold"] },
    "netns":                     { "fg": "white",           "bg": "darkestgreen", "attrs": [] },
    "gitstatus":                 { "fg": "gray8",           "bg": "gray1", "attrs": [] },
    "gitstatus_branch":          { "fg": "gray8",           "bg": "gray1", "attrs": [] },
    "gitstatus_branch_clean":    { "fg": "green",           "bg": "gray1", "attrs": [] },
    "gitstatus_branch_dirty":    { "fg": "gray8",           "bg": "gray1", "attrs": [] },
    "gitstatus_branch_detached": { "fg": "mediumpurple",    "bg": "gray1", "attrs": [] },
    "gitstatus_tag":             { "fg": "darkcyan",        "bg": "gray1", "attrs": [] },
    "gitstatus_behind":          { "fg": "gray10",          "bg": "gray1", "attrs": [] },
    "gitstatus_ahead":           { "fg": "gray10",          "bg": "gray1", "attrs": [] },
    "gitstatus_staged":          { "fg": "green",           "bg": "gray1", "attrs": [] },
    "gitstatus_unmerged":        { "fg": "brightred",       "bg": "gray1", "attrs": [] },
    "gitstatus_changed":         { "fg": "mediumorange",    "bg": "gray1", "attrs": [] },
    "gitstatus_untracked":       { "fg": "brightestorange", "bg": "gray1", "attrs": [] },
    "gitstatus_stashed":         { "fg": "darkblue",        "bg": "gray1", "attrs": [] },
    "gitstatus:divider":         { "fg": "gray8",           "bg": "gray1", "attrs": [] }
  }
}
EOF

    # CONF CUSTOM powerline colors
    sys::Write <<'EOF' $HOME/.config/powerline/colors.json
{
    "colors": {
        "gnos:manage": 1,
        "gnos:select": 4
    }
}
EOF
        # "gnos:select": 25

    # CONF CUSTOM powerline shell themes including netns & gitstatus
    pip::Install psutil # DEP powerline.segments.common.sys.cpu_load_percent
    pip::Install powerline-mem-segment # DEP powerlinemem.mem_usage.mem_usage_percent
    sys::Write <<'EOF' $HOME/.config/powerline/themes/tmux/default.json
{
    "segments": {
        "left": [
            {
                "function": "powerline.segments.tmux.attached_clients",
                "args": {
                    "minimum": 2
                }
            }
        ],
        "right": [
            {
                "function": "powerline.segments.common.sys.cpu_load_percent",
                "args": {
                    "format": "□{0:3.0f}"
                },
                "priority": 40
            },
            {
                "function": "powerlinemem.mem_usage.mem_usage_percent",
                "args": {
                    "format": "⬙%3d",
                    "mem_type": "active"
                },
                "priority": 50
            },
            {
                "function": "powerline.segments.common.net.network_load",
                "args": {
                    "interface": "auto",
                    "suffix": "",
                    "si_prefix": true,
                    "recv_format": "▼{value:>5}",
                    "sent_format": "▲{value:>5}"
                },
                "priority": 45
            },
            {
                "function": "powerline.segments.common.net.hostname"
            }
        ]
    }
}
EOF
    sys::Write <<'EOF' $HOME/.config/powerline/themes/shell/default.json
{
    "segments": {
        "left": [
            {
                "function": "powerline.segments.shell.mode"
            },
            {
                "function": "powerline.segments.common.net.hostname",
                "priority": 10
            },
            {
                "function": "powerline.segments.common.env.user",
                "priority": 30
            },
            {
                "function": "powerline.segments.common.env.virtualenv",
                "priority": 50
            },
            {
                "function": "powerline.segments.shell.cwd",
                "priority": 10
            },
            {
                "function": "powerline.segments.shell.jobnum",
                "priority": 20
            }
        ],
        "right": [
            {
                "function": "powerline.segments.common.env.environment",
                "priority": 30,
                "args": {
                  "variable": "container"
                }
            },
            {
                "function": "powerline_netns.netns",
                "priority": null
            },
            {
                "function": "powerline_gitstatus.gitstatus",
                "priority": 40
            },
            {
                "function": "powerline.segments.shell.last_pipe_status",
                "priority": 10
            }
        ]
    }
}
EOF
    # FIX custom bash theme as no right segment available
    sys::Write <<'EOF' $HOME/.config/powerline/themes/shell/${PRODUCT_NAME}_bash.json
{
    "segments": {
        "left": [
            {
                "function": "powerline.segments.common.env.environment",
                "priority": 30,
                "args": {
                  "variable": "container"
                }
            },
            {
                "function": "powerline_netns.netns",
                "priority": null
            },
            {
                "function": "powerline.segments.common.net.hostname",
                "priority": 10
            },
            {
                "function": "powerline.segments.common.env.user",
                "priority": 30
            },
            {
                "function": "powerline.segments.common.env.virtualenv",
                "priority": 50
            },
            {
                "function": "powerline.segments.shell.cwd",
                "priority": 10
            },
            {
                "function": "powerline.segments.shell.jobnum",
                "priority": 20
            },
            {
                "function": "powerline_gitstatus.gitstatus",
                "priority": 40
            },
            {
                "function": "powerline.segments.shell.last_pipe_status",
                "priority": 10
            }
        ]
    }
}
EOF

    # root + skel
    cp -R "$HOME/.config/powerline" /root/.config
    cp -R "$HOME/.config/powerline" /etc/skel/.config

    # CONF BASH
    local bashrc=$HOME/.bashrc
    [[ -d "$HOME/.bashrc.d" ]] && bashrc=$HOME/.bashrc.d/80_prompt_powerline
    sys::Write --append <<EOF "$bashrc" 1000:1000
# CONF options
POWERLINE_BASH_CONTINUATION=1
POWERLINE_BASH_SELECT=1

# CONF Custom bash layout theme
export POWERLINE_CONFIG_OVERRIDES="ext.shell.theme=${PRODUCT_NAME}_bash;"

# CONF Force ascii top_theme for non-graphic & remote users
if [[ -z "\$DISPLAY"  || -n "\$SSH_TTY" || -n "\$SSH_CONNECTION" ]] ; then
    export POWERLINE_CONFIG_OVERRIDES="\$POWERLINE_CONFIG_OVERRIDES;common.default_top_theme=ascii"
    alias vi="vi --cmd 'let g:powerline_config_overrides={\"common\":{\"default_top_theme\":\"unicode\"}}'"
    alias vim="vi"
fi

# RUN
powerline-daemon -q
. $pipPath/powerline/bindings/bash/powerline.sh

# TIP: Manually set PS1, override powerline
# example: append newline to prompt
# _powerline_set_prompt_BACK=\$(declare -f _powerline_set_prompt)
# eval "_powerline_set_prompt_ORIG\${_powerline_set_prompt_BACK#_powerline_set_prompt}"
# unset _powerline_set_prompt_BACK
# _powerline_set_prompt ()
# {
#     _powerline_set_prompt_ORIG
#     local ret=\$?
#     PS1="\$PS1\n" # Modify PS1 here
#     return \$ret
# }
EOF

    local bashrc=$HOME/.bashrc
    if [[ -d "$HOME/.bashrc.d" ]] ; then
        sys::Write --append <<'EOF' "$HOME/.bashrc.d/90_prompt_xtrace" 1000:1000
# DEV: should be ran as latest PROMPT_COMMAND setter

# Disable xtrace in PROMPT_COMMAND
PROMPT_COMMAND="{ last_exit_code=\$? last_pipe_status=("\${PIPESTATUS[@]}") ; } 2>/dev/null
if [[ ! \$- =~ x ]] 2>/dev/null ; then
    $PROMPT_COMMAND
else
    { set +x; } 2>/dev/null; HIDDEN_XTRACE=1
    $PROMPT_COMMAND
    unset HIDDEN_XTRACE ; set -x
fi"

   [[ "$( type -t _powerline_status_wrapper 2>/dev/null )" == "function" ]] \
&& function _powerline_status_wrapper () { _powerline_set_prompt $last_exit_code "${last_pipe_status[*]}"; return $last_exit_code ; }


# Disable xtrace in bash-completion
unxtrace-bash-completion ()
{
    for unxtrace_func in $( [[ "$( type -t _cd  2>/dev/null )" == "function" ]] && echo _cd ) \
        $( grep -rhPo '^(?=[\s]*+[^#])complete\s+(-\S\s+)*-F\s+\K[^\$]\S+' /usr/share/bash-completion | sort -u ) ; do
            eval "$unxtrace_func ()
{
    if [[ \$- =~ x ]] ; then { builtin set +x; } 2>/dev/null ; local unxtrace_$unxtrace_func=1; fi 2>/dev/null
    $( declare -f $unxtrace_func | perl -pe 'BEGIN{undef $/;} s/^\S+\s*\(\).*\n\{//g, s/\}$//' )
    [[ -n \"\$unxtrace_$unxtrace_func\" ]] && { builtin set -x; } 2>/dev/null ; { return \$ret ; } 2>/dev/null
}"
    done
}

# `set` OVERRIDE: Auto unxtrace-bash-completion
set ()
{
    [[ ! -v PS1 || ! $- =~ i ]] && { builtin set "$@" ; return $? ; } 2>/dev/null
    local check=0 match=0 skip=0
    for opt in "$@" ; do
        [[ $skip -eq 1 ]] && { skip=0 ; continue ; }
        if [[ $check -eq 1 ]] ; then
            [[ "$opt" == "xtrace" ]] && { match=1 ; break ; }
            check=0 ; continue
        fi
        [[ "$opt" == "+o" ]] && { skip=1 ; continue ; }
        [[ $opt =~ ^\+ ]] && continue
        [[ "$opt" == "-o" ]] && { check=1 ; continue ; }
        [[ "$opt" == "--" ]] && break
        [[ $opt =~ ^-.*x ]] && { match=1 ; break ; }
        break
    done

    if [[ $match -eq 1 ]] ; then
        echo "INFO: unxtrace-bash-completion" >&2
        unxtrace-bash-completion
        unset -f set
    fi

    builtin set "$@"
}

EOF

        sys::Write --append <<'EOF' "$HOME/.bashrc.d/89_prompt_xtitle" 1000:1000
function SetTitle () # $1:TITLE
{
    echo -ne "\033]0;${1}\007"
}
function SetShellTitle ()
{
    SetTitle "$(basename -- "$0"):$USER@${HOSTNAME}"
}
function SetCommandTitle () # $*:CMD
{
    local user=$USER host=$HOSTNAME ssh=0
    local ssh_opt=":1246AaCfGgKkMNnqsTtVvXxYyb:c:D:E:e:F:I:i:J:L:l:m:O:o:p:Q:R:S:W:w:"
    local sudo_opt=":AbEkHnPSa:C:c:g:h:p:r:t:u:"
    while [[ -n "$1" ]]; do
        case "$1" in
            ls|cd|z|echo|trap|[[)
                return ;;
            time)
                shift ;;
            *=*)
                shift ;;
            sudo)
                user=ROOT
                shift
                local first=1
                while [[ $first -eq 1 || $1 =~ ^-- ]] ; do
                    first=0
                    [[ $1 =~ ^-- ]] && shift
                    while getopts $sudo_opt opt "$@" ; do
                        [[ "$opt" == "u" ]] && user="$OPTARG"
                    done
                    shift $((OPTIND-1))
                done ;;
            ssh)
                ssh=1
                shift
                if [[ $1 =~ ^- ]] ; then
                    while getopts $ssh_opt opt "$@" ; do : ; done
                    shift $((OPTIND-1))
                fi
                if [[ $1 =~ @ ]] ; then
                    host="${1##*@}"
                    user="${1%%@*}"
                else
                    host="$1"
                fi
                shift
                if [[ $1 =~ ^- ]] ; then
                    while getopts $ssh_opt opt "$@" ; do : ; done
                    shift $((OPTIND-1))
                fi
                break ;;
            *)  break ;;
        esac
    done
    local cmd=$1
    local max=16
    [[ $cmd =~ / ]] && cmd="$( basename "$cmd" )"
    [[ "${#cmd}" -gt $max ]] && cmd="${cmd:0:$max}…"
    [[ -n "$cmd" || $ssh -eq 1 ]] && SetTitle "${cmd:-SSH}:$user@$host"
}
function _KillQuoted ()
{
    local cmd=${@//\\\"/?}
    while [[ $cmd =~ ^([^\"\']+)?\".*\"(.*) || $cmd =~ ^([^\"\']+)?\'.*\'(.*) ]] ; do
        cmd="${BASH_REMATCH[1]}?${BASH_REMATCH[2]}"
    done
    echo "${cmd//\\\ /?}"
}

PROMPT_COMMAND="trap - DEBUG
$PROMPT_COMMAND
SetShellTitle
[[ ! \$- =~ x && -z \"\$HIDDEN_XTRACE\" ]] && trap 'SetCommandTitle \$( _KillQuoted \$BASH_COMMAND )' DEBUG"
EOF
    fi

    # CONF ZSH
    which zsh && sys::Write --append <<EOF $HOME/.zshrc 1000:1000

# powerline
. $pipPath/powerline/bindings/zsh/powerline.zsh

EOF
    # root + skel
    cp "$HOME/.zshrc" /root/
    cp "$HOME/.zshrc" /etc/skel/

    # CONF FISH
    which fish && sys::Write --append <<EOF $HOME/.config/fish/config.fish 1000:1000

# powerline
set fish_function_path \$fish_function_path "$pipPath/powerline/bindings/fish"
powerline-setup

EOF
    # root + skel
    cp -R "$HOME/.config/fish" /root/.config
    cp -R "$HOME/.config/fish" /etc/skel/.config

    # CONF TMUX
    which tmux && sys::Write --append <<EOF $HOME/.tmux.conf 1000:1000

# powerline
source "$pipPath/powerline/bindings/tmux/powerline.conf"
EOF
    # root + skel
    cp "$HOME/.tmux.conf" /root/
    cp "$HOME/.tmux.conf" /etc/skel/


    # CONF VIM
    which vim && sys::Write --append <<EOF $HOME/.vimrc 1000:1000

" powerline
set t_Co=256
set rtp+=$pipPath/powerline/bindings/vim
python3 from powerline.vim import setup as powerline_setup
python3 powerline_setup()
python3 del powerline_setup
set laststatus=2
set showtabline=2
set noshowmode
EOF
    # root + skel
    cp "$HOME/.vimrc" /root/
    cp "$HOME/.vimrc" /etc/skel/

}


cli::Osquery ()
{

    apt::AddSource osquery \
        "[arch=amd64] https://pkg.osquery.io/deb" \
        "deb main" \
        "1484120AC4E9F8A1A577AEEE97A80C63C9D8B80B"
    apt::AddPackages osquery
    systemctl mask osqueryd.service

}


cli::Sysdig ()
{
    apt::AddSource sysdig \
        "http://download.draios.com/stable/deb" \
        "stable-amd64/" \
        "https://s3.amazonaws.com/download.draios.com/DRAIOS-GPG-KEY.public"
    apt::AddPackages sysdig

    # TIP bash FUNCS
    # https://github.com/draios/sysdig/wiki/Sysdig%20Examples
    # https://github.com/draios/sysdig/wiki/sysdig%20Quick%20Reference%20Guide#basic-command-list
}




cli::Vim ()
{
    apt::AddPackages vim-gtk3

    gui::HideApps gvim

    sys::Write --append <<'EOF' $HOME/.vimrc 1000:1000

" FROM https://github.com/captbaritone/dotfiles

" Allow vim to break compatibility with vi, must be first
set nocompatible

" vim-plug: install
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" vim-plug: source plugins
call plug#begin('~/.vim/plugged')
source $HOME/.vim/plug.vim
call plug#end()

"
set nohidden                    " Don't allow buffers to exist in the background
set ttyfast                     " Indicates a fast terminal connection
set backspace=indent,eol,start  " Allow backspaceing over autoindent, line breaks, starts of insert
set shortmess+=I                " No welcome screen
set shortmess+=A                " No .swp warning
set history=99                  " Remember the last 200 :ex commands
set secure                      " disable unsafe commands in local .vimrc files


" Buffer Area Visuals
set scrolloff=7             " Minimal number of screen lines to keep above and below the cursor.
set visualbell              " Use a visual bell, don't beep!
set cursorline              " Highlight the current line
set number                  " Show line numbers
set wrap                    " Soft wrap at the window width
set linebreak               " Break the line on words
set textwidth=79            " Break lines at just under 80 characters
set formatoptions-=t        " Don't insert line breaks automatically
if exists('+colorcolumn')
  set colorcolumn=+1        " Highlight the column after `textwidth`
endif
set numberwidth=4           " Width of the line number column


" Highlight tabs and trailing spaces
set listchars=tab:▸\ ,trail:•
set list                    " Make whitespace characters visible

" Splits
set splitbelow              " Open new splits below
set splitright              " Open new vertical splits to the right

" Colors
syntax enable               " This has to come after colorcolumn in order to draw it.
set t_Co=256                " enable 256 colors

" Mouse
set mouse+=a  " Add mouse support for 'all' modes, may require iTerm
if &term =~ '^screen'
    " tmux knows the extended mouse mode
    set ttymouse=xterm2
endif

" Search
set incsearch               " Show search results as we type
set showmatch               " Show matching brackets
set hlsearch                " Highlight search results
set ignorecase              " Ignore case when searching
set smartcase               " Don't ignore case if we have a capital letter

" Tabs
set tabstop=4               " Show a tab as four spaces
set shiftwidth=4            " Reindent is also four spaces
set softtabstop=4           " When hit <tab> use four columns
set expandtab               " Create spaces when I type <tab>
set shiftround              " Round indent to multiple of 'shiftwidth'.
set autoindent              " Put my cursor in the right place when I start a new line
filetype plugin indent on   " Rely on file plugins to handle indenting

" Auto detect filetype
autocmd BufRead,BufNewFile *.md,*.markdown set filetype=markdown
autocmd BufRead,BufNewFile ~/dotfiles/ssh/config set filetype=sshconfig
autocmd BufRead,BufNewFile *.git/config,.gitconfig,.gitmodules,gitconfig set ft=gitconfig
autocmd BufRead,BufNewFile *.py setlocal foldmethod=indent
autocmd BufRead,BufNewFile *.scss set filetype=scss

" Nobody ever uses "Ex" mode, and it's annoying to leave
noremap Q <nop>

" Allow saving of files as sudo when I forgot to start vim using sudo.
" Seems to have a problem where Vim sees that the file has changed and tries to
" reload it. When it does it thinks the file is blank (but it's not really).
cmap w!! %!sudo tee > /dev/null %

" Local .vim/plugrc.vim
if filereadable(glob("$HOME/.vim/plugrc.vim"))
    source $HOME/.vim/plugrc.vim
endif

" Local .vim/local.vim
if filereadable(glob("$HOME/.vim/local.vim"))
    source $HOME/.vim/local.vim
endif

EOF


    sys::Write <<<"" $HOME/.vim/plug.vim 1000:1000
    sys::Write <<<"" $HOME/.vim/plugrc.vim  1000:1000
    sys::Write <<<"" $HOME/.vim/local.vim  1000:1000


    # LOCAL: BACKUP
    sys::Write --append <<'EOF' $HOME/.vim/local.vim

" Disable swap files
set noswapfile

" Keep undo history in ~/.vim/backup, if exists
let myUndoDir = expand('$HOME/.vim/backup')
if has('persistent_undo') && isdirectory(myUndoDir)
    let &undodir = myUndoDir
    set undofile
endif
EOF

    # LOCAL: KEYBOARD
    sys::Write --append <<'EOF' $HOME/.vim/local.vim
" Enable xterm-keys
if &term =~ '^screen'
    " tmux will send xterm-style keys when its xterm-keys option is on
    execute "set <xUp>=\e[1;*A"
    execute "set <xDown>=\e[1;*B"
    execute "set <xRight>=\e[1;*C"
    execute "set <xLeft>=\e[1;*D"
endif

" Copy to clipboard on mouse select
noremap <LeftRelease> "+y<LeftRelease>


" <space> toggles folds opened and closed
nnoremap <space> za

" Shift + Up/Down to switch buffers
nnoremap <silent> <S-Down> :bn<CR>
imap <S-Down> <C-o>:bn<CR>
nnoremap <silent> <S-Up> :bp<CR>
imap <S-Up> <C-o>:bp<CR>

" Shift + Left/Right to switch tabs
nnoremap <silent> <S-Right> :tabnext<CR>
imap <S-Right> <C-o>:tabnext<CR>
nnoremap <silent> <S-Left> :tabprevious<CR>
imap <S-Left> <C-o>:tabprevious<CR>

" Ctrl + Q to quit immediately
nnoremap <silent> <C-q> :qa!<CR>
imap <C-q> <C-o>:qa!<CR>

" Ctrl + B to new buffer
nnoremap <silent> <C-b> :new<CR>
imap <C-n> <C-o>:new<CR>

" Ctrl + W to close buffer
nnoremap <silent> <C-w> :bd!<CR>
imap <C-w> <C-o>:bd!<CR>

" Ctrl + T to new tab
nnoremap <C-t>     :tabnew<CR>
imap <C-t> <C-o>:tabnew<CR>

EOF


    # LOCAL: THEMING
    # Afterglow colorscheme
    net::Download \
        https://raw.githubusercontent.com/danilo-augusto/vim-afterglow/master/colors/afterglow.vim \
        $HOME/.vim/colors/
    chown -hR $USER_USERNAME:$USER_USERNAME $HOME/.vim/colors/
    sys::Write --append $HOME/.vim/local.vim 1000:1000 <<'EOF'

" Theming
colorscheme afterglow
set background=dark
set noshowmode
hi Normal guibg=NONE ctermbg=NONE
hi EndOfBuffer ctermfg=0
EOF

    ########
    # TMUX #
    ########

    sys::Write --append <<'EOF' $HOME/.vim/local.vim

" tmux like vertical separator
set fillchars+=vert:│
hi VertSplit ctermbg=NONE guibg=NONE
EOF

    # vim-tmux
    sys::Write --append $HOME/.vim/plug.vim \
        <<<"Plug 'tmux-plugins/vim-tmux'"

    # vim-tmux-focus-events
    sys::Write --append $HOME/.vim/plug.vim \
        <<<"Plug 'tmux-plugins/vim-tmux-focus-events'"

       grep -q '^set -g focus-events on' $HOME/.tmux.conf \
    || sys::Write --append <<'EOF' $HOME/.tmux.conf

# DOC: https://github.com/tmux-plugins/vim-tmux-focus-events
set -g focus-events on
EOF

    # vim-tmux-navigator
    sys::Write --append $HOME/.vim/plug.vim \
        <<<"Plug 'christoomey/vim-tmux-navigator'"

       grep -q '^is_vim=' $HOME/.tmux.conf \
    || sys::Write --append <<'EOF' $HOME/.tmux.conf

# DOC: https://github.com/christoomey/vim-tmux-navigator
is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
    | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|n?vim?x?)(diff)?$'"
bind-key -n C-S-Left if-shell "$is_vim" "send-keys C-S-Left"  "select-pane -L"
bind-key -n C-S-Down if-shell "$is_vim" "send-keys C-S-Down"  "select-pane -D"
bind-key -n C-S-Up if-shell "$is_vim" "send-keys C-S-Up"  "select-pane -U"
bind-key -n C-S-Right if-shell "$is_vim" "send-keys C-S-Right"  "select-pane -R"
bind-key -n C-\ if-shell "$is_vim" "send-keys C-\\" "select-pane -l"
bind-key -T copy-mode-vi C-S-Left select-pane -L
bind-key -T copy-mode-vi C-S-Down select-pane -D
bind-key -T copy-mode-vi C-S-Up select-pane -U
bind-key -T copy-mode-vi C-S-Right select-pane -R
bind-key -T copy-mode-vi C-\ select-pane -l
bind C-l send-keys 'C-l'
EOF
    sys::Write --append $HOME/.vim/plugrc.vim  <<'EOF'

" vim-tmux-navigator
let g:tmux_navigator_no_mappings = 1
nnoremap <silent> <C-S-Left> :TmuxNavigateLeft<cr>
nnoremap <silent> <C-S-Down> :TmuxNavigateDown<cr>
nnoremap <silent> <C-S-Up> :TmuxNavigateUp<cr>
nnoremap <silent> <C-S-Right> :TmuxNavigateRight<cr>
nnoremap <silent> <C-S-Tab> :TmuxNavigatePrevious<cr>
imap <C-S-Left> <C-o>:TmuxNavigateLeft<cr>
imap <C-S-Down> <C-o>:TmuxNavigateDown<cr>
imap <C-S-Up> <C-o>:TmuxNavigateUp<cr>
imap <C-S-Right> <C-o>:TmuxNavigateRight<cr>
imap <C-S-Tab> <C-o>:TmuxNavigatePrevious<cr>
EOF


    #########
    # FILES #
    #########

    # ctrlp http://ctrlpvim.github.io/ctrlp.vim/
    # ALT sys::Write --append $HOME/.vim/plug.vim <<<"Plug 'kien/ctrlp.vim'"
    sys::Write --append $HOME/.vim/plug.vim <<<"Plug 'ctrlpvim/ctrlp.vim'"
    sys::Write --append $HOME/.vim/plugrc.vim  <<'EOF'

" Plugin: Ctrl-P
let g:ctrlp_working_path_mode = 'rc'
let g:ctrlp_custom_ignore = {
    \ 'dir':  '\v[\/]\.(git|hg|svn|sass-cache|pip_download_cache|wheel_cache)$',
    \ 'file': '\v\.(png|jpg|jpeg|gif|DS_Store|pyc)$',
    \ 'link': '',
    \ }
let g:ctrlp_show_hidden = 1
let g:ctrlp_clear_cache_on_exit = 0
" Wait to update results (This should fix the fact that backspace is so slow)
let g:ctrlp_lazy_update = 1
" Show as many results as our screen will allow
let g:ctrlp_match_window = 'max:1000'
" If we have The Silver Searcher
if executable('ag')
    " Use ag over grep
    set grepprg=ag\ --nogroup\ --nocolor

    " Use ag in CtrlP for listing files. Lightning fast and respects .gitignore
    let g:ctrlp_user_command = 'ag %s --files-with-matches -g "" --hidden --ignore "\.git$\|\.hg$\|\.svn|\.pyc$"'

    " ag is fast enough that CtrlP doesn't need to cache
    let g:ctrlp_use_caching = 0
endif
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlP'
EOF


    # ctrlp-funky
    sys::Write --append $HOME/.vim/plug.vim <<<"Plug 'tacahiroy/ctrlp-funky'"
    sys::Write --append $HOME/.vim/plugrc.vim  <<'EOF'

" Plugin: ctrlp-funky
nnoremap <Leader>f :CtrlPFunky<Cr>
" Initialise list by a word under cursor
nnoremap <Leader>u :execute 'CtrlPFunky ' . expand('<cword>')<Cr>
EOF


    # NERDTree
    sys::Write --append $HOME/.vim/plug.vim <<<"Plug 'scrooloose/nerdtree'"
    sys::Write --append $HOME/.vim/plug.vim <<<"Plug 'Xuyuanp/nerdtree-git-plugin'"
    sys::Write --append $HOME/.vim/plug.vim <<<"Plug 'Nopik/vim-nerdtree-direnter'"
    sys::Write --append $HOME/.vim/plugrc.vim  <<'EOF'

" Plugin: NERDTree
map <C-n> :NERDTreeToggle<CR>
let NERDTreeMapOpenInTab='<ENTER>'
" let NERDTreeShowHidden=1
EOF


    ########
    # CODE #
    ########

    # Syntastic
    sys::Write --append $HOME/.vim/plug.vim <<<"Plug 'vim-syntastic/syntastic'"
    sys::Write --append $HOME/.vim/plug.vim <<<"Plug 'myint/syntastic-extras'"

    # YouCompleteMe
    apt::AddPackages build-essential cmake python3-dev
    sys::Write --append $HOME/.vim/plug.vim <<'EOF'
Plug 'Valloric/YouCompleteMe', { 'do': 'source ~/.gvm/scripts/gvm ; python3 install.py --clang-completer --gocode-completer' }
EOF

    # vim-javascript
    sys::Write --append $HOME/.vim/plug.vim <<<"Plug 'pangloss/vim-javascript'"

    # vim-markdown
    sys::Write --append $HOME/.vim/plug.vim <<<"Plug 'gabrielelana/vim-markdown'"


    #######
    # GIT #
    #######

    # vim-fugitive
    sys::Write --append $HOME/.vim/plug.vim <<<"Plug 'tpope/vim-fugitive'"

    # vim-gitgutter
    sys::Write --append $HOME/.vim/plug.vim <<<"Plug 'airblade/vim-gitgutter'"


    ########
    # MISC #
    ########

    # editorconfig-vim
    sys::Write --append $HOME/.vim/plug.vim <<<"Plug 'editorconfig/editorconfig-vim'"

    # PreserveNoEOL
    sys::Write --append $HOME/.vim/plug.vim <<<"Plug 'vim-scripts/PreserveNoEOL'"
    sys::Write --append $HOME/.vim/plugrc.vim  <<'EOF'

" Plugin: PreserveNoEOL
let g:PreserveNoEOL = 1
EOF

    # install plugins
    sudo --set-home -u \#1000 vim +'PlugInstall --sync' +'PlugClean!' +qa
    sys::Chk

    # root
    cp -R $HOME/.vim/ /root
    sys::Chk
}


cli::Htop ()
{
    apt::AddPackages htop
    mkdir -p \
            /root/.config/htop/ \
            $HOME/.config/htop  \
        /etc/skel/.config/htop
    sys::Write <<'EOF' /root/.config/htop/htoprc
fields=0 48 49 2 18 39 47 46 1
sort_key=46
sort_direction=1
hide_threads=0
hide_kernel_threads=1
hide_userland_threads=1
shadow_other_users=0
show_thread_names=1
highlight_base_name=1
highlight_megabytes=1
highlight_threads=1
tree_view=0
header_margin=0
detailed_cpu_time=0
cpu_count_from_zero=0
update_process_names=1
color_scheme=0
delay=15
left_meters=AllCPUs Memory Swap
left_meter_modes=1 1 1
right_meters=Clock Hostname Tasks LoadAverage Uptime Battery
right_meter_modes=2 2 2 2 2 2
EOF
    cp /root/.config/htop/htoprc /etc/skel/.config/htop
    cp /root/.config/htop/htoprc     $HOME/.config/htop
    chown -hR 1000:1000 $HOME/.config/htop

    # sudo htop
    sys::Write <<'EOF' /usr/local/bin/shtop 0:0 755
#!/bin/bash
echo "[htop] Password to run as root or CTRL-C to skip"
if sudo --set-home htop ; then
     echo -ne "\033]0;htop:ROOT@local\007"
else
    htop
fi
EOF
    mkdir -p /usr/local/share/applications
    sed -E 's#^(Exec=)htop(.*)#\1/usr/local/bin/shtop#' \
        /usr/share/applications/htop.desktop \
        >/usr/local/share/applications/htop.desktop

}


cli::Bash ()
{
    apt::AddPackages bash-completion command-not-found

    # .bashrc.d parts
    for dir in $HOME/ /root/ /etc/skel/ ; do

        mkdir $dir/.bashrc.d

        mv $dir/.bashrc $dir/.bashrc.d/50_default

        sys::Write <<'EOF' $dir/.bashrc
# TIP: Ubuntu ~/.bashrc moved to ~/.bashrc.d/50_default

# DEV: Source ~/.bashrc.d/* parts
shopt -s extglob
for i in "$( dirname "$( readlink -f "$BASH_SOURCE" )" )/.bashrc.d"/!(*.disabled) ; do source "$i"; done
true
EOF

        sys::Write <<'EOF' $dir/.profile 1000:1000
# DEV: source ~/.bashrc
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        export PROMPT_COMMAND= # FIX: tmux
        source "$HOME/.bashrc"
    fi
fi
true
EOF
        sys::Write <<'EOF' $dir/.bashrc.d/50_path
# DEV: source ~/bin
[[ -d "$HOME/bin" ]] && export PATH="$HOME/bin:$PATH"
EOF

    done
    chown -R 1000:1000 $HOME/.bashrc $HOME/.bashrc.d $HOME/.profile


    #########
    # PAGER #
    #########


    sys::Write --append <<'EOF' "$HOME/.bashrc.d/30_pager" 1000:1000
export VISUAL=e
export EDITOR=e

# DEV Workaround screen terminal type italic issue
export PAGER="less"

# lesspipe: LESSOPEN & LESSCLOSE
[[ -x /usr/bin/lesspipe ]] && eval "$( SHELL=/bin/sh lesspipe )"

# editor: LESSEDIT # TIP: press 'v'
export LESSEDIT='%E %f?lm:%lm.'

alias p="LESS_TERMCAP_so=$'\E[30;43m' LESS_TERMCAP_se=$'\E[39;49m' $PAGER -igFMRX"

# Colorful man FROM https://gist.github.com/nibalizer/1388557/be800aaf69dec2a4e4ba31c10e5314656de11e99
MANPAGER='less -igFMR'
alias man="PAGER=\$MANPAGER LESS_TERMCAP_mb=$'\E[01;31m' LESS_TERMCAP_md=$'\E[01;31m' LESS_TERMCAP_me=$'\E[0m' LESS_TERMCAP_se=$'\E[0m' LESS_TERMCAP_so=$'\E[01;44;33m' LESS_TERMCAP_ue=$'\E[0m' LESS_TERMCAP_us=$'\E[01;32m' man"
EOF

    # LESSOPEN custom .lessfilter
    apt::AddPackages python-pygments
    sys::Write <<'EOF' $HOME/.lessfilter 1000:1000 700
#!/bin/sh
# ALT pygmentize -g "$1"
# ALT rougify "$1"
bat --color always --theme=DarkNeon --plain "$1"
EOF
    cp $HOME/.lessfilter /root/.lessfilter


    sys::Write $HOME/.sudo_as_admin_successful <<<'' 1000:1000 600

    sys::Write --append $HOME/.inputrc <<'EOF' 1000:1000 600
set bell-style none
set completion-ignore-case on
set show-all-if-ambiguous on

# colored tab completion
set colored-stats on

# mappings for Ctrl-left-arrow and Ctrl-right-arrow for word moving
"\e[1;5C": forward-word
"\e[1;5D": backward-word
"\e[5C":   forward-word
"\e[5D":   backward-word
"\e\e[C":  forward-word
"\e\e[D":  backward-word

#
"\e[1;5A": history-search-backward
"\e[1;5B": history-search-forward
EOF
    cp $HOME/.inputrc /root/.inputrc
    cp $HOME/.inputrc /etc/skel/.inputrc



    ###########
    # ALIASES #
    ###########

    sys::Write <<'EOF' "$HOME/.bashrc.d/55_aliases" 1000:1000
# alias sudo='sudo ' # DEV: notice trailing space, enables alias interpretation
alias sudo='sudo --set-home ' # Debian-style default + trailing space
alias pkx='pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY'
alias root='sudo --set-home SSH_TTY=$SSH_TTY bash --rcfile $HOME/.bashrc #'
alias rfind="2>/dev/null find / -iname"
alias Nohup='&>/dev/null </dev/null nohup'
alias psa='ps --ppid 2 -p 2 --deselect --format pid,tname,user,cmd --forest' # DEV: hide kernel threads # TOCHECK $PS_FORMAT
alias ls='ls --color=auto'
alias l='ls -CF --group-directories-first'
alias ll='ls -ahlvF --group-directories-first --time-style=iso'
alias cp="cp -i"
alias df="df -h"
alias free="free -h"
alias strace-open='strace-lnav -e open,openat,connect'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias bat='bat --theme=DarkNeon' # --style=numbers,changes
alias where='pstree -alupsSu $$ | head -n -2 #'
EOF

    sys::Write <<'EOF' "$HOME/.bashrc.d/56_functions" 1000:1000
mkd ()
{
    [[ $# -eq 1 ]] && mkdir -p -- "$1" && cd -P -- "$1"
}

strace-lnav ()
{
    strace -r -T "$@" 2>&1 | lnav
}

EOF


    sys::Write --append <<'EOF' "$HOME/.bashrc.d/20_prompt_basic" 1000:1000

shopt -s checkwinsize
export PROMPT_COMMAND="history -a"
EOF


    sys::Write <<'EOF' "$HOME/.bashrc.d/75_colors" 1000:1000
if [[ -x /usr/bin/dircolors ]]; then
       [[ -r ~/.dircolors ]] \
    && eval "$(dircolors -b ~/.dircolors)" \
    || eval "$(dircolors -b)"
fi
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'
EOF


    sys::Write <<'EOF' "$HOME/.bashrc.d/70_history" 1000:1000
[[ $- =~ .*i.* ]] || return

shopt -s histappend
export HISTSIZE=-1
export HISTFILESIZE=-1
export HISTCONTROL=ignoreboth
export HISTIGNORE="ls:cd:cd -:pwd:exit:date"
export HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S  "

EOF
}


cli::Sugar ()
{
    which gnos-sugar && return

    # gnos-sugar
    net::CloneGitlabRepo gnos/gnos-sugar /opt
    ln -s /opt/gnos-sugar/gnos-sugar /usr/local/bin/
    sys::Chk

    # helpers
    pushd /usr/local/bin/
    ln -s gnos-sugar i
    ln -s gnos-sugar o
    ln -s gnos-sugar s
    popd

    # bash Completion
    local bashrc=$HOME/.bashrc
    [[ -d "$HOME/.bashrc.d" ]] && bashrc=$HOME/.bashrc.d/completion.gnos-sugar
    sys::Write --append <<'EOF' "$bashrc"
complete -F _filedir_xspec i
complete -F _filedir_xspec o
EOF

}


cli::Fish ()
{
    apt::AddPackages fish

    # CONF
    sys::Write --append <<'EOF' $HOME/.config/fish/config.fish 1000:1000
# keyboard bindings
if status --is-login
     bind \e\[1\;5C forward-word
     bind \e\[1\;5D backward-word
end

# greeting
set fish_greeting ""

# title
function fish_title
    echo $_:$USER@(hostname)
end

EOF

    # WORKAROUND init error
    # test: Missing argument at index 2
    sudo --set-home -u \#1000 fish --help &>/dev/null
}


cli::Zsh ()
{
    apt::AddPackages zsh

    sys::Write <<'EOF' $HOME/.zshrc 1000:1000
# DOC:  http://zsh.sourceforge.net/Doc/Release/Options.html
# FROM: https://gist.github.com/jcrobak/1105165

###########
# OPTIONS #
###########

unsetopt BG_NICE          # do NOT nice bg commands
setopt CORRECT            # command correction
setopt INTERACTIVE_COMMENTS # allow comments on line
setopt AUTO_MENU # menu completion after second tab press

# Set/unset  shell options
setopt   globdots pushdtohome cdablevars autolist
setopt   correctall autocd recexact longlistjobs
setopt   autoresume histignoredups pushdsilent clobber
setopt   autopushd pushdminus extendedglob rcquotes mailwarning
setopt   autoparamslash

# history stuff
setopt APPEND_HISTORY
setopt EXTENDED_HISTORY   # puts timestamps in the history
setopt HIST_ALLOW_CLOBBER
setopt HIST_REDUCE_BLANKS
setopt INC_APPEND_HISTORY SHARE_HISTORY # history commands are saved right-
                                        # away, interweaved across shells
export HISTFILE=$HOME/.zhistory
export HISTSIZE=-1
export SAVEHIST=$HISTSIZE

# Autoload zsh modules when they are referenced
# zmodload -a zsh/stat stat
# zmodload -a zsh/zpty zpty
# zmodload -a zsh/zprof zprof
# zmodload -ap zsh/mapfile mapfile


##########
# KEYMAP #
##########

bindkey -e
bindkey "^A" beginning-of-line
bindkey "^K" kill-line
bindkey "^Y" yank
bindkey "^U" backward-kill-line

bindkey '^r' history-incremental-search-backward
bindkey "^[[5~" up-line-or-history
bindkey "^[[6~" down-line-or-history
bindkey "^[[H" beginning-of-line
bindkey "^[[1~" beginning-of-line
bindkey "^[[F"  end-of-line
bindkey "^[[4~" end-of-line
bindkey ' ' magic-space    # also do history expansion on space
bindkey '^I' complete-word # complete on tab, leave expansion to _expand

bindkey "^[[3~" delete-char

bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word


##############
# COMPLETION #
##############

autoload -U compinit
compinit


# formatting and messages
zstyle ':completion:*' verbose yes
zstyle ':completion:*:descriptions' format '%B%d%b'
zstyle ':completion:*:messages' format '%d'
zstyle ':completion:*:warnings' format 'No matches for: %d'
zstyle ':completion:*:corrections' format '%B%d (errors: %e)%b'
zstyle ':completion:*' group-name ''

zstyle ':completion::complete:*' use-cache on
zstyle ':completion::complete:*' cache-path ~/.zsh/cache/$HOST

zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-prompt '%SAt %p: Hit TAB for more, or the character to insert%s'
zstyle ':completion:*' menu select=1 _complete _ignored _approximate
zstyle -e ':completion:*:approximate:*' max-errors \
    'reply=( $(( ($#PREFIX+$#SUFFIX)/2 )) numeric )'
zstyle ':completion:*' select-prompt '%SScrolling active: current selection at %p%s'
zstyle ':completion:*:processes' command 'ps -axw'
zstyle ':completion:*:processes-names' command 'ps -awxho command'

# Completion Styles
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
# list of completers to use
zstyle ':completion:*::::' completer _expand _complete _ignored _approximate

# allow one error for every three characters typed in approximate completer
zstyle -e ':completion:*:approximate:*' max-errors \
    'reply=( $(( ($#PREFIX+$#SUFFIX)/2 )) numeric )'

# insert all expansions for expand completer
zstyle ':completion:*:expand:*' tag-order all-expansions

# NEW completion:
# 1. All /etc/hosts hostnames are in autocomplete
# 2. If you have a comment in /etc/hosts like #%foobar.domain,
#    then foobar.domain will show up in autocomplete!
zstyle ':completion:*' hosts $(awk '/^[^#]/ {print $2 $3" "$4" "$5}' /etc/hosts | grep -v ip6- && grep "^#%" /etc/hosts | awk -F% '{print $2}')

# completion for ssh known_hosts
local knownhosts
knownhosts=( ${${${${(f)"$(<$HOME/.ssh/known_hosts)"}:#[0-9]*}%%\ *}%%,*} ) 2>/dev/null
zstyle ':completion:*:(ping|telnet|mtr|ssh|scp|sftp):*' hosts $knownhosts

# match uppercase from lowercase
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# offer indexes before parameters in subscripts
zstyle ':completion:*:*:-subscript-:*' tag-order indexes parameters

# command for process lists, the local web server details and host completion
#zstyle ':completion:*:processes' command 'ps -o pid,s,nice,stime,args'
#zstyle ':completion:*:urls' local 'www' '/var/www/htdocs' 'public_html'
zstyle '*' hosts $hosts

# Filename suffixes to ignore during completion (except after rm command)
zstyle ':completion:*:*:(^rm):*:*files' ignored-patterns '*?.o' '*?.c~' \
    '*?.old' '*?.pro'
# the same for old style completion
#fignore=(.o .c~ .old .pro)

# ignore completion functions (until the _ignored completer)
zstyle ':completion:*:functions' ignored-patterns '_*'
zstyle ':completion:*:scp:*' tag-order \
   files users 'hosts:-host hosts:-domain:domain hosts:-ipaddr"IP\ Address *'
zstyle ':completion:*:scp:*' group-order \
   files all-files users hosts-domain hosts-host hosts-ipaddr
zstyle ':completion:*:ssh:*' tag-order \
   users 'hosts:-host hosts:-domain:domain hosts:-ipaddr"IP\ Address *'
zstyle ':completion:*:ssh:*' group-order \
   hosts-domain hosts-host users hosts-ipaddr
zstyle '*' single-ignored show


##########
# XTITLE #
##########

# FROM .bashrc.d/89_prompt_xtitle

function parse_cmd () # $*:CMD
{
    local user=$USER host=$HOST ssh=0
    local ssh_opt=":1246AaCfGgKkMNnqsTtVvXxYyb:c:D:E:e:F:I:i:J:L:l:m:O:o:p:Q:R:S:W:w:"
    local sudo_opt=":AbEkHnPSa:C:c:g:h:p:r:t:u:"
    while [[ -n "$1" ]]; do
        case "$1" in
            ls|cd|z|echo|trap|\[\[)
                return ;;
            time)
                shift ;;
            *=*)
                shift ;;
            sudo)
                user=ROOT
                shift
                local first=1
                while [[ $first -eq 1 || $1 =~ ^-- ]] ; do
                    first=0
                    [[ $1 =~ ^-- ]] && shift
                    while getopts $sudo_opt opt "$@" ; do
                        [[ "$opt" == "u" ]] && user="$OPTARG"
                    done
                    shift $((OPTIND-1))
                done ;;
            ssh)
                ssh=1
                shift
                if [[ $1 =~ ^- ]] ; then
                    while getopts $ssh_opt opt "$@" ; do : ; done
                    shift $((OPTIND-1))
                fi
                if [[ $1 =~ @ ]] ; then
                    host="${1##*@}"
                    user="${1%%@*}"
                else
                    host="$1"
                fi
                shift
                if [[ $1 =~ ^- ]] ; then
                    while getopts $ssh_opt opt "$@" ; do : ; done
                    shift $((OPTIND-1))
                fi
                break ;;
            *)  break ;;
        esac
    done
    local cmd=$1
    local max=16
    [[ $cmd =~ / ]] && cmd="$( basename "$cmd" )"
    [[ "${#cmd}" -gt $max ]] && cmd="${cmd:0:$max}…"
    [[ -n "$cmd" || $ssh -eq 1 ]] && update_title "${cmd:-SSH}:$user@$host"
}

# FROM https://github.com/jreese/zsh-titles

function update_title() {
  # escape '%' in $1, make nonprintables visible
  local a=${(V)1//\%/\%\%}
  a=$(print -n "%20>...>$a")
  a=${a//$'\n'/}
  print -n "\e]0;${(%)a}\a"
}

# called just before the prompt is printed
function _zsh_title__precmd() {
  update_title "zsh:$USER@$HOST"
}

# called just before a command is executed
function _zsh_title__preexec() {
  1=${1//\\/\\\\\\\\}       # Escape '\'
  local -a cmd=(${(z)1})    # Re-parse the command line
  case $cmd[1] in           # Resolve jobs
    fg) cmd="${(z)jobtexts[${(Q)cmd[2]:-%+}]}" ;;
    %*) cmd="${(z)jobtexts[${(Q)cmd[1]:-%+}]}" ;;
  esac

  parse_cmd $cmd
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _zsh_title__precmd
add-zsh-hook preexec _zsh_title__preexec


##########
# CUSTOM #
##########

# https://github.com/rupa/z
[[ -f $HOME/.bashrc.d/81_z ]] && source "$HOME/.bashrc.d/81_z"

EOF
}



cli::Rclone ()
{
    [[ -e "/usr/local/bin/rclone" ]] && return
    local tempzip=$( mktemp )
    net::Download "http://downloads.rclone.org/rclone-current-linux-amd64.zip" $tempzip
    unzip -j $tempzip */rclone -d /usr/local/bin/
    sys::Chk
    unzip -j $tempzip */rclone.1 -d /usr/local/share/man/man1/
    sys::Chk
    chmod 755 /usr/local/bin/rclone
    rm -f $tempzip
}



cli::Firejail ()
{
    which firejail &>/dev/null && return

    apt::AddPpaPackages deki/firejail firejail firejail-profiles

    # WORKAROUND https://firejail.wordpress.com/support/known-problems/#pulseaudio
    sys::Write --append $HOME/.config/pulse/client.conf 1000:1000 <<<"enable-shm = no"
    mkdir -p /etc/skel/.config/pulse
    cp {$HOME,/etc/skel}/.config/pulse/client.conf
    # TOCHECK: firecfg --fix-sound

       [[ -n "$ZFS_DATA_DSET" ]] \
    && sys::Write /etc/firejail/disable-common.local <<<"blacklist /$( basename $ZFS_DATA_DSET )"

       [[ -d "$HOME/.bashrc.d" ]] \
    && sys::Write --append <<'EOF' /etc/firejail/default.local
whitelist ~/.bashrc.d
read-only ~/.bashrc.d
EOF

}


cli::Sanoid ()
{
    # DOC: https://github.com/jimsalterjrs/sanoid

    apt::AddPackages pv lzop mbuffer libconfig-inifiles-perl

    local tmpdir=$( mktemp -d )

    net::DownloadUnzip \
        "https://github.com/jimsalterjrs/sanoid/archive/master.zip" \
        "$tmpdir"

    mkdir -p /etc/sanoid/ /usr/local/sbin/
    cp $tmpdir/sanoid-master/sanoid.defaults.conf   /etc/sanoid/sanoid.defaults.conf
    cp $tmpdir/sanoid-master/sanoid.conf            /etc/sanoid/sanoid.example
    cp $tmpdir/sanoid-master/{sanoid,syncoid,findoid,sleepymutex}  /usr/local/sbin/
    # chmod +x /usr/local/sbin/{sanoid,syncoid,findoid,sleepymutex}
    rm -rf "$tmpdir"

    sys::Write <<'EOF' /lib/systemd/system/sanoid.service
[Unit]
Description=Sanoid
Requires=zfs.target
After=zfs.target
ConditionFileNotEmpty=/etc/sanoid/sanoid.conf

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/sanoid --cron
EOF

    sys::Write <<'EOF' /lib/systemd/system/sanoid.timer
[Unit]
Description=Run Sanoid Every 15 Minutes

[Timer]
OnCalendar=*:0/15
Persistent=true

[Install]
WantedBy=timers.target
EOF

    sys::Write <<EOF /etc/sanoid/sanoid.gnos
#################
# GNOS DEFAULTS #
#################

[$ZFS_POOL_NAME/$ZFS_ROOT_DSET]
    use_template = template_root

[$ZFS_POOL_NAME/$ZFS_ROOT_DSET/var]
    use_template = template_root
    # Only following datasets: cache, log, spool, tmp
    # directories such as /var/lib are stored on root
    process_children_only = yes

[$ZFS_POOL_NAME/$ZFS_ROOT_DSET/home]
    use_template = template_root,template_user

EOF
       [[ -n "$ZFS_DATA_DSET" ]] \
    && sys::Write --append <<EOF /etc/sanoid/sanoid.gnos
[$ZFS_POOL_NAME/$ZFS_DATA_DSET]
    use_template = template_root,template_user
    recursive = yes

EOF

    sys::Write --append <<EOF /etc/sanoid/sanoid.gnos
#############
# TEMPLATES #
#############

[template_user]
    hourly = 36
    daily = 30
    monthly = 3
    yearly = 0
    autosnap = yes
    autoprune = yes

[template_root]
    hourly = 36
    daily = 30
    monthly = 3
    yearly = 0
    autosnap = yes
    autoprune = yes

[template_ignore]
    autoprune = no
    autosnap = no
    monitor = no
EOF

}



cli::Vpngate ()
{
    which vpngate && return

    apt::AddPackages policykit-1
    cli::Softether
    cli::Node

    # gnos-vpngate
    net::CloneGitlabRepo gnos/gnos-vpngate /opt
    ln -s /opt/gnos-vpngate/vpngate /usr/local/bin/
    sys::Chk
    ln -s /opt/gnos-vpngate/vpnssl-connect /usr/local/bin/
    sys::Chk

    chown 1000 /opt/gnos-vpngate
    sudo --set-home -u \#1000 bash -c '. ~/.nvm/nvm.sh && /opt/gnos-vpngate/vpngate -i -v'
    chown -hR 0:0 /opt/gnos-vpngate
}



cli::Softether ()
{
    Meta --desc "Universal VPN"

    which vpncmd && return

    if [[ "$UBUNTU_RELEASE" == "xenial" ]] ; then
        apt::AddPpaPackages ondrej/php libssl1.1
    else # BIONIC
        apt::AddRemotePackages \
            https://launchpad.net/ubuntu/+archive/primary/+files/libreadline6_6.3-8ubuntu2_amd64.deb
        # ALT http://ppa.launchpad.net/kxstudio-debian/gcc5-deps/ubuntu xenial/main
    fi
    apt::AddPpaPackages paskal-07/softethervpn \
        softether-common \
        softether-vpnclient \
        softether-vpnserver \
        softether-vpncmd

    update-rc.d softether-vpnserver remove

    sys::Write <<'EOF' /lib/systemd/system/vpnserver.service
[Unit]
Description=SoftEther VPN Server daemon
After=network.target
# ConditionPathExists=!/usr/libexec/softether/vpnserver/do_not_run

[Service]
Type=forking
# EnvironmentFile=-/usr/libexec/softether/vpnserver
ExecStart=/usr/libexec/softether/vpnserver/vpnserver start
ExecStop=/usr/libexec/softether/vpnserver/vpnserver stop
KillMode=process
Restart=on-failure
# Hardening
PrivateTmp=yes
ProtectHome=yes
ProtectSystem=full
ReadOnlyDirectories=/
ReadWriteDirectories=-/usr/libexec/softether/vpnserver
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_BROADCAST CAP_NET_RAW CAP_SYS_NICE CAP_SYS_ADMIN CAP_SETUID


[Install]
WantedBy=multi-user.target
EOF

    sys::Write <<'EOF' /lib/systemd/system/vpnclient.service
[Unit]
Description=SoftEther VPN Client daemon
After=network.target
# ConditionPathExists=!/usr/libexec/softether/vpnclient/do_not_run

[Service]
Type=forking
# EnvironmentFile=-/usr/libexec/softether/vpnclient
ExecStart=/usr/libexec/softether/vpnclient/vpnclient start
ExecStop=/usr/libexec/softether/vpnclient/vpnclient stop
KillMode=process
Restart=on-failure

# Hardening
PrivateTmp=yes
ProtectHome=yes
ProtectSystem=full
ReadOnlyDirectories=/
ReadWriteDirectories=-/usr/libexec/softether/vpnclient
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_BROADCAST CAP_NET_RAW CAP_SYS_NICE CAP_SYS_ADMIN CAP_SETUID

[Install]
WantedBy=multi-user.target
EOF

    systemctl mask    vpnserver.service
    systemctl mask    vpnclient.service

    # TODO Server profile: Init
    # ServerPasswordSet secretServer # Allows remote config
    # DynamicDnsSetHostname NAME     # DDNS: NAME.softether.net
    # VpnAzureSetEnable yes          # NATT: NAME.vpnazure.net
    # ListenerDelete 992
    # ListenerDelete 1194
    # ListenerDelete 5555
    # Hub DEFAULT
    # AcAdd6 deny /PRIORITY:1 IP6_ALL # TODO Disable IPv6
    # SecureNatEnable
    # UserCreate USERNAME
    # UserPasswordSet USERNAME /PASSWORD:secretUser

    # TODO Stealth server profile: Stop ALL outgoing connections
    # DOC: http://www.vpnusers.com/viewtopic.php?f=7&t=2736&sid=df62617d81a342f25ce5c5b516f0df0c&view=print
    # - Disable dynamic DNS
    # declare DDnsClient
    # {
    #     bool Disabled true
    # }
    # - Disable NAT traversal
    # bool DisableNatTraversal true
    # - Disable UDP acceleration
    # bool DisableUdpAcceleration true
    # - Disable keep alive
    # bool UseKeepConnect true
    # bool AcceptOnlyTls true # SEC

}


