


#   ▜ ▗ ▌       ▌
#   ▐ ▄ ▛▀▖  ▌ ▌▛▀▖▞▀▖▚▗▘
#   ▐ ▐ ▌ ▌  ▐▐ ▌ ▌▌ ▌▗▚
#    ▘▀▘▀▀    ▘ ▀▀ ▝▀ ▘ ▘



vbox::GetDownloadUrl ()
{
    echo "http://download.virtualbox.org/virtualbox/"
}


vbox::GetLastVersion ()
{
      curl -fsSL "$( vbox::GetDownloadUrl )" \
    | awk -F'<a ' '
        /href="[56]\.[\.0123456789_-]+\// {
            split($0,a,"\"")
            print substr(a[2],1,length(a[2])-1)
        }' \
    | sort --version-sort \
    | tail -1
}

vbox::GetGuestAdditionsUrl () # [ $1:VERSION ]
{
    local virtualboxVersion=$1
    [[ -z "$virtualboxVersion" ]] && virtualboxVersion=$( vbox::GetLastVersion )
    echo "$( vbox::GetDownloadUrl )$virtualboxVersion/VBoxGuestAdditions_$virtualboxVersion.iso"
}

vbox::GetExtensionPackUrl () # [ $1:VERSION ]
{
    local virtualboxVersion=$1
    [[ -z "$virtualboxVersion" ]] && virtualboxVersion=$( vbox::GetLastVersion )
    echo "$( vbox::GetDownloadUrl )$virtualboxVersion/Oracle_VM_VirtualBox_Extension_Pack-$virtualboxVersion.vbox-extpack"
}

vbox::InstallExtensionPack_NONFREE () # [ $1:VERSION ]
{
    local tmpPack=$( mktemp -d )
    net::Download "$( vbox::GetExtensionPackUrl $1 )" $tmpPack/
    echo "y" | VBoxManage extpack install $tmpPack/*
    sys::Chk

    rm -rf "$tmpPack"
}
