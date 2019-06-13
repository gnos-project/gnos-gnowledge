########
# FUNC #  NET
########


net::Check ()
{
    # while ! curl -sSL --fail --connect-timeout 10 --retry 5 "http://google.com" &>/dev/null ; do
    while ! wget -O- --timeout=10 --waitretry=0 --tries=5 --retry-connrefused "http://google.com" &>/dev/null ; do
        sys::Msg --color "1;31" "Missing internet connection, fix network and press [ENTER]"
        read
    done
}

net::CloneGitlabRepo () # $1:NAME/REPO $2:DEST
{
    which git || apt::AddPackages git
    sys::Mkdir "$2"
    pushd "$2"
    git clone --depth 1 "https://gitlab.com/$1.git"
    sys::Chk
    popd
}

net::InstallGithubLatestRelease () # $1:NAME/REPO $2:FILE_REGEX
{
    local tempdir="$( mktemp -d )"
    net::DownloadGithubLatestRelease $1 \
        "$2" \
        "$tempdir/0.deb"
    apt::AddLocalPackages "$tempdir/0.deb"
    rm -rf "$tempdir/"
}

# TIP: net::DownloadGithubLatestRelease docker/kitematic '-Ubuntu\\.zip$'
net::DownloadGithubLatestRelease () # $1:NAME/REPO $2:FILE_REGEX [$3:TARGET]
{
    local repo="$1" regex="$2"
    shift 2
    local url="$( net::GetGithubLatestRelease "$repo" "$regex" )"

    if [[ -n "$url" && "$url" != "null" ]] ; then
        net::Download "$url" "$@"
    else
        sys::Die "Failed to identify Github release for: $repo, regex=$regex"
    fi
}

net::GetGithubLatestRelease () # $1:USER/PROJECT $2:REGEX
{
    local r='.'
    [[ -n "$2" ]] && r="$2"
      # curl -s "https://api.github.com/repos/$1/releases" \
      net::Download "https://api.github.com/repos/$1/releases" \
    | sys::Jq '[ .[] | select(."prerelease" != true and (.assets[] | .browser_download_url | select(match("'"$r"'"))) ) | .assets[] | .browser_download_url | select(match("'"$r"'")) ][0]'
}

net::DownloadUntar () # [--opts TAR_OPTS] $1:URL $2:DEST_DIR [$*:TAR_ARGS]
{
    local taropt
    [[ "$1" == "--opts" ]] && { taropt="$2"; shift 2; }
    [[ $# -lt 2 || -z "$1" || -z "$2" ]] && sys::Die "Invalid ARGS: ($#) $*"
    local url="$1" dir="$2" tmptar=$( mktemp )
    shift 2
    net::Download "$url" "$tmptar"
    tar x${taropt}vf "$tmptar" --directory "$dir" "$@"
    sys::Chk
    rm "$tmptar"
}

net::DownloadUntarGzip () # $1:URL $2:DEST_DIR [$*:TAR_ARGS]
{
    net::DownloadUntar --opts z "$@"
}
net::DownloadUntarBzip () # $1:URL $2:DEST_DIR [$*:TAR_ARGS]
{
    net::DownloadUntar --opts j "$@"
}
net::DownloadUntarXzip () # $1:URL $2:DEST_DIR [$*:TAR_ARGS]
{
    net::DownloadUntar --opts J "$@"
}

net::DownloadUnzip () # $1:URL $2:DEST_DIR
{
    local tmpzip=$( mktemp )
    net::Download "$1" "$tmpzip"
    unzip "$tmpzip" -d "$2"
    sys::Chk
    rm "$tmpzip"
}

# DEV: DEST & TARGET directories must end with /
net::DownloadGithubFiles () # [ --branch NAME ] $1:NAME/REPO $2:DEST $*:TARGETS
{
    local branch=master
    [[ "$1" == "--branch" ]] && { branch="$2"; shift 2; }

    local repo=$1 dst=$2
    shift 2
    if [[ ! $dst =~ /$ ]] ; then
        if [[ $# -ne 1 ]] \
        || { [[ $# -eq 1 ]] && [[ $1 =~ /$ ]] ; } ; then
            sys::Die "Invalid call: use / suffix for destination dir"
        fi
        sys::Touch "$dst"
    else
        sys::Mkdir "$dst"
    fi

    local tempdir=$( mktemp -d )
    net::Download \
        "https://github.com/$repo/archive/$branch.zip" \
        "$tempdir/$branch.zip"
    if [[ $# -eq 0 ]] ; then
        unzip $tempdir/$branch.zip -d "$tempdir"
        sys::Chk
        cp -R "$tempdir/${repo#*/}-$branch/." "$dst"
        sys::Chk
    else
        for i in "$@"; do
            if [[ $i =~ /$ ]] ; then
                unzip $tempdir/$branch.zip "${repo#*/}-$branch/${i}*" -d "$tempdir"
                sys::Chk
                cp -R "$tempdir/${repo#*/}-$branch/$i" "$dst"
                sys::Chk
                chown --preserve-root --changes --no-dereference --reference="$dst/" "$dst/$( basename "$i" )"
                sys::Chk
            else
                unzip $tempdir/$branch.zip "${repo#*/}-$branch/${i}" -d "$tempdir"
                sys::Chk
                cp "$tempdir/${repo#*/}-$branch/$i" "$dst"
                sys::Chk
                chown --preserve-root --changes --no-dereference --reference="$( dirname "$dst" )" "$dst"
                sys::Chk
            fi
        done
    fi
    rm -rf "$tempdir"
}



# TIP: KEEP_HTTP_DOWNLOADS=/tmp/http_backups
net::Download () # [--opts "OPTS"] $1:URL [$2:TARGET] # DOC: TARGET should be slash terminated
{
    # xtrace hide
    {
        local opts
        [[ "$1" == "--opts" ]] && { opts="$2"; shift 2; }

        local backupFile
        if [[ -n "$KEEP_HTTP_DOWNLOADS" ]] ; then
            [[ -d "$KEEP_HTTP_DOWNLOADS" ]] || mkdir -p "$KEEP_HTTP_DOWNLOADS"
            backupFile="$KEEP_HTTP_DOWNLOADS/$( str::SanitizeString "$1" )"
        fi

        local targetDir targetFile
        if [[ -n "$2" ]] ; then
            case "$2" in
                */) targetDir="$2"            ; targetFile=$(basename "$1") ;;
                *)  targetDir=$(dirname "$2") ; targetFile=$(basename "$2") ;;
            esac
        fi
    } 2>/dev/null

    [[ -n "$2" ]] && sys::Mkdir "$targetDir"

    if [[ -f "$backupFile" ]] ; then
        [[ ${#@} -eq 2 ]] \
        && cp "$backupFile" "$targetDir/$targetFile" \
        || cat "$backupFile"
    elif [[ ${#@} -eq 2 ]] ; then
        net::DownloadRetry --opts "$opts" "$1" "$targetDir/$targetFile"
        [[ -n "$backupFile" ]] && cp "$targetDir/$targetFile" "$backupFile"
    elif [[ -n "$backupFile" ]] ; then
        net::DownloadRetry --opts "$opts" "$1" "$backupFile"
        cat "$backupFile"
    else
        local tmpfile=$( mktemp )
        net::DownloadRetry --opts "$opts" "$1" "$tmpfile"
        cat "$tmpfile"
        rm "$tmpfile"
    fi

}

net::DownloadRetry () # [--opts "OPTS"] $1:URL $2:TARGET
{
    local opts
    [[ "$1" == "--opts" ]] && { opts="$2"; shift 2; }

    # local cmd="curl -sSL --fail --connect-timeout 10 --retry 5"
    local curlcmd="curl --location --fail --connect-timeout 10 --retry 3 --progress-bar $opts"

    local retry=0 ret=1
    while [[ $retry -lt 3 ]] && [[ "$ret" -ne 0 ]] ; do
        $curlcmd "$1" > "$2"
        ret=$?
        retry=$(( $retry + 1 ))
        case $ret in
            7|18|22|28|35|56|92)
                sleep $(( $retry * 10 )) ;;
            0)  return 0 ;;
            *)  sys::Die "Download failed with code $ret" ; break ;;
        esac
        sys::Msg --color "1;31" "Download failed with code $ret, retrying ($retry)"
    done
    [[ $retry -ge 3 ]] && sys::Die "Download REPEATEDLY failed"
}

# UNUSED FROM https://gist.github.com/cdown/1163649#gistcomment-2157284
# net::UrlEncode() # $1:URL
# {
#     local LANG=C i c e=''
#     for ((i=0;i<${#1};i++)); do
#         c=${1:$i:1}
#         [[ "$c" =~ [a-zA-Z0-9\.\~\_\-] ]] || printf -v c '%%%02X' "'$c"
#         e+="$c"
#     done
#     echo "$e"
# }
net::UrlDecode() # $1:URL
{
    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}

net::GetFavicon() # $1:URL
{
    [[ $1 =~ https?:// ]] || return

    local domain="$1"
    domain=${domain#http://}
    domain=${domain#https://}
    domain=${domain%%/*}
    domain=${domain%%:*}

    net::Download "https://www.google.com/s2/favicons?domain=$domain"
    # ALT net::Download "https://www.google.com/s2/favicons?domain=$( net::UrlEncode "$domain" )"
}
