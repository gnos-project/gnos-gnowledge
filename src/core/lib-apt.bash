########
# FUNC #  APT
########


apt::Upgrade ()
{
    RUNLEVEL=1 DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade \
        --yes -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
    sys::Chk
}

apt::AutoRemovePackages ()
{
    RUNLEVEL=1 DEBIAN_FRONTEND=noninteractive apt-get autoremove \
        --purge \
        --yes -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
    sys::Chk
}

apt::RemovePackages () # $*:PACKAGE_NAME
{
    RUNLEVEL=1 DEBIAN_FRONTEND=noninteractive apt-get remove \
        --purge \
        --yes -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
        "$@"
    sys::Chk
    apt::AutoRemovePackages
}

apt::AddPackages () # $*:PACKAGE_NAME
{
    RUNLEVEL=1 DEBIAN_FRONTEND=noninteractive apt-get install \
        --no-install-recommends \
        --yes -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
        "$@"
    sys::Chk
}

apt::Update () #
{
    {
        local temperr=$( mktemp )

        apt-get update 2>"$temperr" >/dev/null

        local missingKeys=$( awk '(NF>2)&&($(NF-1)=="NO_PUBKEY"){print $NF}' "$temperr" )
        rm -f "$tmperr"

        [[ -z "$missingKeys" ]] && return

    } 2>/dev/null

    # fix missing keys
    apt::FixKeys $missingKeys
    apt-get update
    sys::Chk
}

apt::AddSource () # $1:NAME $2:URL $3:"REPOS" [$4:KEY_URL|KEY_HASH]
{

    local filename
    while [[ $1 =~ ^-- ]] ; do case $1 in
        --force-name) shift ; filename=$1 ;;
        *) break ;;
    esac ; done

    [[ -z "$filename" ]] && filename=$( str::SanitizeString "$1" ).src

    if [[ ${#@} -eq 4 ]] ; then
        case "$4" in
            *:/*)
                local key=$( mktemp )
                net::Download "$4" "$key"
                apt-key add "$key"
                sys::Chk
                rm -f "$key"
                ;;
            *)
                apt::FixKeys "$4"
                ;;
        esac
    fi

    echo "deb $2 $3" > /etc/apt/sources.list.d/$filename.list

    apt::Update
}

apt::FixKeys () # $*:FINGERPRINT
{
    local keyServer=pool.sks-keyservers.net # keyserver.ubuntu.com

    # DEV: apt-key can fail
    # WORKAOUND: 10 retries with increasing timer
    local found=0
    for i in $( seq 0 10 ) ; do

        sleep $i

           apt-key adv --keyserver $keyServer --recv-keys $* \
        || continue

        found=1
        break

    done

    [[ $found -ne 1 ]] && sys::Die "Failed to recieve apt pubkeys for: $*"

    # DEV: DO NOT CALL apt::Update !!! or loop to death
}

apt::AddPpa () # [--noupgrade] $1:USER/REPO
{
    {
        local noupgrade noupdate
        local release=$( lsb_release -cs )

        while [[ $1 =~ ^-- ]] ; do case $1 in
            --release)   release=$2  ; shift 2 ;;
            --noupgrade) noupgrade=1 ; shift ;;
            --noupdate)  noupgrade=1 ; noupdate=1 ; shift ;;
            *) break ;;
        esac ; done

        local id="$( str::SanitizeString "$1" )"
        local fn="/etc/apt/sources.list.d/$id.ppa.list"
        local url="http://ppa.launchpad.net/$1/ubuntu/dists/$release"

        # Check already added
        [[ -f "$fn" ]] && return 2

    } 2>/dev/null

    # Check release exists
    if curl -fsSLI "$url/" ; then

        # Check has >0 packages
          net::Download $url/main/binary-amd64/Packages.gz \
        | gzip -dc \
        | awk '$1=="Package:" {c=c+1; print $2 > "/dev/stderr"} END{if (c<1) exit 1; exit 0}' \
            2>/dev/null # hide package list

        if [[ $? -eq 0 ]] ; then

            # Manually set the source to set the filename
            sys::Write <<EOF "$fn"
deb http://ppa.launchpad.net/$1/ubuntu $release main
# deb-src http://ppa.launchpad.net/$1/ubuntu $release main
EOF
            [[ -z "$noupdate" ]] && apt::Update

            [[ -z "$noupgrade" ]] && apt::Upgrade

            return 0
        else
            sys::Die "Empty PPA $1 for release $release"
        fi
    else
        sys::Die "Unsupported release $release for PPA $1"
    fi
}


apt::AddPpaPackages () # [ --priority PIN_PRIORITY ] $1:USER/REPO $*:PACKAGE_NAME
{
    # DOC: https://gist.github.com/JPvRiel/8ae81e21ce6397a0502fedddca068507

    {
        local priority=500 default_priority=400 release
        # [[ "$1" == "--priority" ]] && { priority="$2"; shift 2; }

        while [[ $1 =~ ^-- ]] ; do case $1 in
            --default-priority) default_priority=$2 ; shift 2 ;;
            --priority)         priority=$2         ; shift 2 ;;
            --release)          release=$2          ; shift 2 ;;
            *) break ;;
        esac ; done

        local ppa=$1
        shift

        local ppaName=$( tr '/' '-' <<<"$ppa" )
        [[ $ppa =~ /ppa$ ]] && ppaName=$( tr '/' '-' <<<"${ppa%*/ppa}" )

        local pref="/etc/apt/preferences.d/$( str::SanitizeString "$ppaName" ).ppa.pref"

    } 2>/dev/null

    apt::AddPpa ${release+--release $release} --noupdate --noupgrade $ppa
    local ret=$?

    if [[ $ret -ne 1 ]] ; then

        if [[ $ret -ne 2 ]] ; then

            # DOC: pinning lower priority all ppa's packages
            sys::Write <<EOF $pref
Package: *
Pin: release o=LP-PPA-$ppaName
Pin-Priority: $default_priority
EOF
        fi

        # DOC: pinning to raise priority of selected ppa packages
        for pkg in $* ; do
            sys::Write --append <<EOF $pref

Package: $pkg
Pin: release o=LP-PPA-$ppaName
Pin-Priority: $priority
EOF

        done

        apt::Update

        apt::AddPackages --default-release o=LP-PPA-$ppaName $*
    fi

}


apt::AddLocalPackages () # $*:PACKAGE_DEB
{
    dpkg -i "$@"
    local ret=$?
    if [[ $ret -ne 0 ]] ; then
        apt-get install --yes --no-install-recommends -f
        sys::Chk
    fi
}

apt::AddRemotePackages () # $*:PACKAGE_URL
{
    local cnt=0 tempdeb=$( mktemp -d )

    for url in "$@" ; do
        net::Download "$url" "$tempdeb/$cnt.deb"
        ((cnt++))
    done

    pushd "$tempdeb/"
    apt::AddLocalPackages *.deb
    popd

    rm -rf "$tempdeb/"
}


apt::AddSelection () # $*:DEBCONF_SELECTION
{
    # SAMPLE: apt::AddSelection "sun-java6-jre shared/accepted-sun-dlj-v1-1 boolean true"

    debconf-set-selections <<<"$@"
    sys::Chk
}

apt::GetBestMirror ()
{
      curl -s http://mirrors.ubuntu.com/mirrors.txt \
    | xargs -n1 -I {} sh -c "echo \
        \$(curl -s \
                -r 0-102400 \
                -w %{speed_download} \
                -o /dev/null \
                {}/ls-lR.gz
        ) {}" \
    | sort -g -r \
    | awk 'NR==1 {print $2}'
}

apt::GenerateSources () # $1:TARGET_ROOT $2:CODENAME $3:MIRROR
{
    local dest="$1"
    [[ $dest =~ /$ ]] || dest="$dest/"

    local ubuntuComps="
        main
        restricted
        universe
        multiverse
        "

    local ubuntuCodename="$2"
       [[ -z "$ubuntuCodename" ]] \
    && ubuntuCodename=$( lsb_release -cs )

    # STUB local
    local ubuntuMirror="$3"
       [[ -z "$ubuntuMirror" ]] \
    && ubuntuMirror="$( apt::GetBestMirror )"

    local ubuntuDists="
        ${ubuntuCodename}
        ${ubuntuCodename}-security
        ${ubuntuCodename}-updates
        ${ubuntuCodename}-backports
        ${ubuntuCodename}-proposed
        "

    echo >"${dest}etc/apt/sources.list"

    for dist in $ubuntuDists ; do
        echo "deb $ubuntuMirror $dist $( echo $ubuntuComps )"
        echo "# deb-src $ubuntuMirror $dist $( echo $ubuntuComps )"
    done >>"${dest}etc/apt/sources.list"

    echo "# deb http://archive.canonical.com/ubuntu/ ${ubuntuCodename} partner" \
        >>"${dest}etc/apt/sources.list"

    # Pin -backports
    sys::Write <<EOF "${dest}etc/apt/preferences.d/$ubuntuCodename-backports.dist.pref"
Package: *
Pin: release a=$ubuntuCodename-backports
Pin-Priority: 500
EOF

    # Pin -proposed
    sys::Write <<EOF "${dest}etc/apt/preferences.d/$ubuntuCodename-proposed.dist.pref"
Package: *
Pin: release a=$ubuntuCodename-proposed
Pin-Priority: -1
EOF

}
























# DEV UNUSED functions

apt::ShowUpgradesBySource ()
{
      apt upgrade --simulate 2>/dev/null \
    | gawk '
/Inst / {
    p=$2; v=$3;
    $1=$2=$3=$4=""; $0=$0;
    i=index($0,"["); r=substr($0,5,i-6);
    a[r][p]=0;
}
BEGIN {PROCINFO["sorted_in"]="@ind_str_asc"}
END {for (i in a) {print "# "i;for (j in a[i]) print "  "j}}
'
}

apt::GetFilePackages () # $1:FILE
{
    dpkg -S $1 | cut -f1 -d: | sort -u
}

apt::GetPackageFiles () # $1:FILE
{
    # Archived package
    [[ -f "$1" ]] && { dpkg-deb -c "$1" ; return ; }

    dpkg -l "$1" &>/dev/null
    if [[ $? -eq 0 ]] ; then    # Installed package
        dpkg-query -L "$1"
    else                        # Unknown package
        apt-file update
        apt-file -F list "$1" | cut -f2- -d' '
    fi
}

apt::GetPackageReverseRelated () # $1:PACKAGE_NAME
{
    apt-cache rdepends $1 | grep -vE '^\S' | sed 's/\s*//' | sort -u
}

apt::GetPackageDepends () # $1:PACKAGE_NAME
{
      apt-cache depends $1  \
    | awk '
        $1=="|Depends:"{pkg=pkg" | "$2}
        $1=="Depends:"{print pkg" | "$2 ; pkg=""}' \
    | sed 's/\s*//' \
    | sort -u
}

apt::GetPackageRecommends () # $1:PACKAGE_NAME
{
      apt-cache depends $1  \
    | awk '
        $1=="|Recommends:"{pkg=pkg" | "$2}
        $1=="Recommends:"{print pkg" | "$2 ; pkg=""}' \
    | sed 's/\s*//' \
    | sort -u
}

apt::GetPackageSuggests () # $1:PACKAGE_NAME
{
      apt-cache depends $1  \
    | awk '
        $1=="|Suggests:"{pkg=pkg" | "$2}
        $1=="Suggests:"{print pkg" | "$2 ; pkg=""}' \
    | sed 's/\s*//' \
    | sort -u
}

apt::GetPackageReverseGraph () # $1:PACKAGE_NAME
{
    # Requires package apt-rdepends
    # Requires package graphviz

    local tempdir=$( mktemp -d ) # TODO name apt_rdepends_$1
    local filename="apt_rdepends_$1"
    local graphvizDefaults='graph [bgcolor="#2e2e2e"];edge [color="#ffa726"];\nnode [style=filled color="#484848" fillcolor="#484848" fontname="helvetica" fontcolor="#c0c0c0"]'

       apt-rdepends -drp $1 &>/dev/null \
    |  sed -E 's/^(digraph.*)/\1\n'"$graphvizDefaults"'/' \
    |  circo -Tsvg > $tempdir/$filename  \
    && gloobus-preview $tempdir/$filename &>/dev/null &>/dev/null \
    && rm -rf $tempdir
}
