

#   ▌  ▗ ▌    ▗▀▖▗       ▗▀▖
#   ▌  ▄ ▛▀▖  ▐  ▄ ▙▀▖▞▀▖▐  ▞▀▖▚▗▘
#   ▌  ▐ ▌ ▌  ▜▀ ▐ ▌  ▛▀ ▜▀ ▌ ▌▗▚
#   ▀▀▘▀▘▀▀   ▐  ▀▘▘  ▝▀▘▐  ▝▀ ▘ ▘




firefox::AddStylishCss () # $1:SQLITE_FILE $2:FILE|USERSTYLES_URL $3:NAME
{
    # which sqlite3 &>/dev/null || apt::AddPackages sqlite3

    local dst=$1
    local src=$2
    local name=$3

    local css=$( mktemp )

    local isRemote=0
    if [[ -f "$src" ]] ; then
        cat "$src" >$css
    else
        isRemote=1
        net::Download "$src" $css
    fi

    # Escape quotes for sqlite
    sed -E -i "s/'/''/g" $css

    local sql=$( mktemp )
    sys::Write "$sql" <<<"BEGIN TRANSACTION;"

    # Create default stylish tables
    if ! [[ -f "$dst" ]] ; then
        sys::Write --append <<EOF "$sql"
CREATE TABLE IF NOT EXISTS styles (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    url TEXT,
    updateUrl TEXT,
    md5Url TEXT,
    name TEXT NOT NULL,
    code TEXT NOT NULL,
    enabled INTEGER NOT NULL,
    originalCode TEXT NULL,
    idUrl TEXT NULL,
    applyBackgroundUpdates INTEGER NOT NULL DEFAULT 1,
    originalMd5 TEXT NULL
    );
CREATE TABLE IF NOT EXISTS style_meta (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    style_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    value TEXT NOT NULL
    );
CREATE INDEX IF NOT EXISTS style_meta_style_id ON style_meta (style_id);
EOF
    fi

    # Create temporary table _vars
    sys::Write --append "$sql" \
        <<<"CREATE TEMP TABLE IF NOT EXISTS _vars (name TEXT PRIMARY KEY, value TEXT);"

    # Insert into styles
    if [[ $isRemote == "0" ]] ; then
        sys::Write --append <<EOF "$sql"
INSERT INTO styles (
    name,
    code,
    enabled,
    originalCode,
    applyBackgroundUpdates
    )
VALUES (
    '$name',
    '$( cat $css )',
    1,
    NULL,
    1
    );
EOF
    else
        sys::Write --append <<EOF "$sql"
INSERT INTO styles (
    url,
    updateUrl,
    md5Url,
    name,
    code,
    enabled,
    originalCode,
    idUrl,
    applyBackgroundUpdates,
    originalMd5
    )
VALUES (
    '${src%%\.css}',
    '$src?',
    'https://update.userstyles.org/$( basename $( dirname "$src" ) ).md5',
    '$name',
    '$( cat $css )',
    1,
    NULL,
    '$( sed 's/https/http/' <<< $( dirname "$src") )',
    1,
    '$( md5sum $css | awk '{printf $1}' )'
    );
EOF
    fi

    # Insert style id into _vars
    sys::Write --append "$sql" \
        <<<"INSERT INTO _vars VALUES ('id', last_insert_rowid());"

    # Insert into style_meta
    sys::Write --append <<EOF "$sql"
INSERT INTO style_meta (
    style_id,
    name,
    value
    )
VALUES
EOF

    # DEV: get meta from css
    local idSubQuery="(SELECT value FROM _vars WHERE name='id')"

      awk '
        # DEV: Extract selectors
        $1=="@-moz-document"{
            $1=""
            $0=$0
            $0=substr($0, 1, index($0, "{")-1 )
            gsub(/ +/, "", $0)
            gsub("\"", "", $0)
            gsub("'\''", "", $0)
            print
        }' \
        $css \
    | awk -F"," \
        -v p="    ( $idSubQuery, '" \
        -v s="')," \
        '# DEV: Format for sql insert
        {
            for (i=1;i<=NF;i++)
            {
                a=index($i, "(")
                b=index($i, ")")
                k=substr($i, 1, a-1)
                v=substr($i, a+1, b-a-1)
                print p k "'\'', '\''" v s
            }
        }' \
        >>"$sql"

    sys::Write --append "$sql" \
        <<<"    ( $idSubQuery, 'type', 'app');"


    # Clean
    sys::Write --append <<EOF "$sql"
DROP TABLE _vars;

COMMIT;

PRAGMA user_version = 7;

VACUUM;
EOF
# PRAGMA schema_version = 7;

#cat $sql # DEBUG

    mkdir -p "$( dirname "$dst" )"
    sqlite3 "$dst" <"$sql"

    rm -f $css "$sql"
}



firefox::InstallMozlz4a () # $1:DEST
{
    apt::AddPackages python-lz4

    # FROM https://gist.githubusercontent.com/Tblue/62ff47bef7f894e92ed5/raw/2483756c55ed34be565aea269f05bd5eeb6b0a33/mozlz4a.py
    sys::Write --append <<'EOF' $1 0:0 755
#!/usr/bin/env python
#
# Decompressor/compressor for files in Mozilla's "mozLz4" format. Firefox uses this file format to
# compress e. g. bookmark backups (*.jsonlz4).
#
# This file format is in fact just plain LZ4 data with a custom header (magic number [8 bytes] and
# uncompressed file size [4 bytes, little endian]).
#
# This Python 3 script requires the LZ4 bindings for Python, see: https://pypi.python.org/pypi/lz4
#
#
# Copyright (c) 2015, Tilman Blumenbach
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification, are permitted
# provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this list of conditions
#    and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice, this list of
#    conditions and the following disclaimer in the documentation and/or other materials provided
#    with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
# IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
# OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import lz4
import sys

from argparse import ArgumentParser


class MozLz4aError(Exception):
    pass


class InvalidHeader(MozLz4aError):
    def __init__(self, msg):
        self.msg = msg

    def __str__(self):
        return self.msg


def decompress(file_obj):
    if file_obj.read(8) != b"mozLz40\0":
        raise InvalidHeader("Invalid magic number")

    return lz4.decompress(file_obj.read())

def compress(file_obj):
    compressed = lz4.compress(file_obj.read())
    return b"mozLz40\0" + compressed


if __name__ == "__main__":
    argparser = ArgumentParser(description="MozLz4a compression/decompression utility")
    argparser.add_argument(
            "-d", "--decompress", "--uncompress",
            action="store_true",
            help="Decompress the input file instead of compressing it."
        )
    argparser.add_argument(
            "in_file",
            help="Path to input file."
        )
    argparser.add_argument(
            "out_file",
            help="Path to output file."
        )

    parsed_args = argparser.parse_args()


    try:
        in_file = open(parsed_args.in_file, "rb")
    except IOError as e:
        print("Could not open input file `%s' for reading" % (parsed_args.in_file, e))
        sys.exit(2)

    try:
        out_file = open(parsed_args.out_file, "wb")
    except IOError as e:
        print("Could not open output file `%s' for writing" % (parsed_args.out_file, e))
        sys.exit(3)

    try:
        if parsed_args.decompress:
            data = decompress(in_file)
        else:
            data = compress(in_file)
    except Exception as e:
        print("Could not compress/decompress file `%s'" % (parsed_args.in_file, e))
        sys.exit(4)

    try:
        out_file.write(data)
    except IOError as e:
        print("Could not write to output file `%s'" % (parsed_args.out_file, e))
        sys.exit(5)
    finally:
        out_file.close()

EOF
}


firefox::GetExtensionUrl () # $1:EXTENSION_NAME
{
    local prf="https://addons.mozilla.org"
    local url="$prf/en-us/firefox/addon/$1/"

      net::Download "$url" 2>/dev/null \
    | sed 's/\\u002F/\//g' \
    | awk -F"\"" 'BEGIN{RS="\""}
        /\/((firefox)|(seamonkey))\/downloads\// && ! /windows\.xpi/ && ! /mac\.xpi/ {
            i=index($0, "?")
            if (i) print substr($0, 1, i-1 );
            else   print $0
        }' \
    | sort -nr \
    | head -1
}

firefox::GetXpiId () # $1:XPI_FILE
{
    local str=$(
          unzip -p "$1" install.rdf 2>/dev/null \
        | xmlstarlet sel \
            -N "rdf=http://www.w3.org/1999/02/22-rdf-syntax-ns#" \
            -N "em=http://www.mozilla.org/2004/em-rdf#" \
            --template \
            --match '(//rdf:Description)[(@rdf:about="urn:mozilla:install-manifest") or (@about="urn:mozilla:install-manifest")][em:id|@em:id][1]' \
            "--if"   "./em:id" --value-of "./em:id" \
            "--else"           --value-of "./@em:id"
        )
# TODO tmp file instead of pipe

    if [[ -n "$str" ]] ; then
        echo "$str"
        return
    fi

    str=$(
          unzip -p "$1" manifest.json 2>/dev/null \
        | sys::Jq '.applications.gecko.id'
        )

    if [[ -n "$str" ]] && [[ "$str" != "null" ]]; then
        echo "$str"
        return
    fi

    echo random_$RANDOM
}



firefox::AddExtensionByName() # $1:DEST_DIR $2:NAME $3:XPI_ID
{
        local noupdates
        if [[ "$1" == "--no-updates" ]] ; then
            noupdates="--no-updates"
            shift
        fi

        local dst=$1 name=$2

        local url=$( firefox::GetExtensionUrl "$name" )
        url=${url%%\?*}

        if [[ -n "$url" ]] ; then

            local xpi=$( mktemp )
            net::Download "$url" "$xpi"

            [[ -s "$xpi" ]] && firefox::AddExtensionByXpi $noupdates "$dst" "$xpi" $3

            rm "$xpi"
        else
            sys::Die "Unknown extension: $2"
        fi
}


firefox::AddExtensionByUrl () # $1:DEST_DIR $2:URL $3:XPI_ID
{
    local dst=$1 url=$2

    local xpi=$( mktemp )
    net::Download "$url" "$xpi"

    firefox::AddExtensionByXpi --no-updates "$dst" "$xpi" $3
}


firefox::AddExtensionByXpi() # $1:DEST_DIR $2:XPI_FILE $3:XPI_ID
{
        local noupdates
        if [[ "$1" == "--no-updates" ]] ; then
            noupdates=1
            shift
        fi

        local dst=$1 xpi=$2

        local extId=$3
        [[ -n "$extId" ]] || extId=$( firefox::GetXpiId "$xpi" )
        [[ -n "$extId" ]] || sys::Die "Failed to get '$name' extension id"

        mkdir -p "$dst"
        cp -r "$xpi" "$dst/$extId.xpi"
        chmod 0755 "$dst/$extId.xpi"

        [[ "$noupdates" == "1" ]] && sys::Write --append "$defaultProfile/NO_UPDATES.txt" <<<"$extId"
}






firefox::ResetSearch ()
{
    local mozlz4a=$(mktemp)
    local tmpsearch=$(mktemp)
    firefox::InstallMozlz4a $mozlz4a
    $mozlz4a -d "$profilePath/search.json.mozlz4" "$tmpsearch"
    sys::Chk
    sys::JqInline '.engines |= map(if (."_loadPath" | startswith("jar:") ) then ."_metaData" |= { "hidden": true, "alias": null } else . end)' \
        $tmpsearch
    sys::Chk
    $mozlz4a "$tmpsearch" "$profilePath/search.json.mozlz4"
    sys::Chk
}

firefox::AddSearchEngine() # TODO $1:MYCROFT_ID|OSD_URL $2:NAME $3:ICON_URL
{
    # DEV: Name should not collide defaults in chrome://browser/locale/searchplugins/
    # DEV: Supports OpenSearchDescription files

    local url=$1 name=$2 icon=$3
    [[ $url =~ ^[[:digit:]]+$ ]] && url=http://mycroftproject.com/installos.php/$1/data.xml

    local id=$( awk -F. \
        '/^user_pref\("browser.search.order./ {n=substr($4,1,index($4, "\"") -1)+0; if (n>m) m=n} END {print m+1}' \
        "$defaultPrefs"
    )

    local xml="$profileParent/.preconfig/searchplugins/common/$id.xml"

    net::Download "$url" "$xml"

    if [[ -n "$name" ]] ; then
        sys::XmlstarletInline "$xml" \
            --update '_:OpenSearchDescription/_:ShortName' \
            --value "$name"
    fi

    if [[ -n "$icon" ]] ; then
        sys::XmlstarletInline "$xml" \
            --update '_:OpenSearchDescription/_:Image' \
            --value "$icon"
    fi

    sys::Write --append <<EOF "$defaultPrefs"
user_pref("browser.search.order.$id", "$( xmlstarlet sel --template -v '/_:OpenSearchDescription/_:ShortName' $xml )");
EOF
}


firefox::ProcessBookmarks() # $1:SQLITE_DB $2:FOLDER_NAME $*:"URL[|NAME]"
{
    local db="$1" dir="${2/\'/\'\'}"
    shift 2

    local faviconSupport=$( sqlite3 "$db" <<<"SELECT count(1) FROM sqlite_master WHERE type='table' AND name='moz_favicons';" )
    local dirBookmark dirToolbar
    if [[ "$faviconSupport" == "1" ]] ; then
        dirBookmark="Bookmarks Menu"
        dirToolbar="Bookmarks Toolbar"
    else
        dirBookmark="menu"
        dirToolbar="toolbar"
    fi

    [[ -z "$dir" || "$dir" == "_" ]] && dir="^$dirBookmark"
    [[ "$dir" == "-" ]] && dir="^$dirToolbar"

    local sql=$(mktemp)
    sys::Write $sql <<EOF
CREATE TEMP TABLE IF NOT EXISTS _vars (name TEXT PRIMARY KEY, value TEXT);
EOF

    # Parent Folder
    if [[ $dir =~ ^\^ ]] ; then
        dir="${dir#^}"
        sys::Write --append $sql <<EOF
INSERT INTO _vars VALUES ('folder',
    (   SELECT id FROM moz_bookmarks WHERE title='$dir' )
);
EOF
    else
        sys::Write --append $sql <<EOF
INSERT INTO moz_bookmarks (type, title, parent, position)
VALUES ( 2, '$dir',
    (   SELECT id FROM moz_bookmarks WHERE title='$dirBookmark' ),
    (
        SELECT MAX(a.position)+1
        FROM moz_bookmarks a, moz_bookmarks b
        WHERE a.parent=b.id
        AND b.title='$dir'
    )
);

INSERT INTO _vars VALUES ('folder', last_insert_rowid());
EOF
    fi

    # Bookmarks
    local cnt=0 tmpdir=$( mktemp -d )
    local title url favicon
    for i in "$@" ; do

        ## Separator
        if [[ "$i" == "---" ]] ; then
            sys::Write --append "$sql" <<EOF
INSERT INTO moz_bookmarks (type, parent, position)
VALUES ( 3,
    (   SELECT value FROM _vars WHERE name='folder' ),
    (
        SELECT CASE WHEN a.position IS NOT NULL THEN MAX(a.position)+1 ELSE 0 END
        FROM moz_bookmarks a, moz_bookmarks b
        WHERE a.parent=b.id
        AND b.id=( SELECT value FROM _vars WHERE name='folder' )
    )
);
EOF
            continue
        fi

        ## Entry
        url="${i%%|*}"
        title=
        [[ $i =~ \| ]] && title="${i##*|}"

        if [[ "$faviconSupport" == "1" ]] ; then
            favicon="$tmpdir/$cnt"
            net::GetFavicon "$url" >"$favicon"
        fi

        ## With favicon
        if [[ -s "$favicon" ]] ; then # TODO FF60: && "has" moz_favicons

# FF 60 missing:
# moz_places.favicon_id
# moz_favicons

            sys::Write --append "$sql" <<EOF
INSERT INTO moz_favicons (url, expiration, data, mime_type) VALUES (
    'http://www.mozilla.org/2005/made-up-favicon/$RANDOM',
    1500000000$( printf "%06d" $RANDOM ),
    readfile('$favicon'),
    'image/png'
);

INSERT INTO _vars VALUES ('favicon-$cnt', last_insert_rowid());

INSERT INTO moz_places (foreign_count, frecency, url, guid, favicon_id )
VALUES (1, 140, '$url',
    '$( cat /dev/urandom | tr -dc 'a-zA-Z0-9_-' | head -c12 )',
    (   SELECT value FROM _vars WHERE name='favicon-$cnt' )
);
EOF
        ## Without favicon
        else
            sys::Write --append "$sql" <<EOF
INSERT INTO moz_places (foreign_count, frecency, url, guid)
VALUES (1, 140, '$url',
    '$( cat /dev/urandom | tr -dc 'a-zA-Z0-9_-' | head -c12 )'
);
EOF
        fi

        ## Bookmark
        sys::Write --append "$sql" <<EOF
INSERT INTO moz_bookmarks (type, title, fk, parent, position)
VALUES ( 1, '$title', last_insert_rowid(),
    (   SELECT value FROM _vars WHERE name='folder' ),
    (
        SELECT CASE WHEN a.position IS NOT NULL THEN MAX(a.position)+1 ELSE 0 END
        FROM moz_bookmarks a, moz_bookmarks b
        WHERE a.parent=b.id
        AND b.id=( SELECT value FROM _vars WHERE name='folder' )
    )
);
EOF
        ((cnt++))
    done

    sqlite3 "$db" <"$sql"
    sys::Chk

cat "$sql" # DBG
    rm -rf "$tmpdir" "$sql"
}


firefox::AddBookmarks() # $1:FOLDER_NAME $*:"URL[|NAME]"
{
    local dir="$1"
    shift
    for i in "$@"; do
        echo "$i" >>"$profileParent/.preconfig/custom-bookmarks.$dir"
    done
}


firefox::CreateProfile () # $1:BROWSER $2:USER $3:NAME $4:RRGGBB [ 'ALL' | FEATURE ... ]
{
# TODO check ARGS $#

    local browser=$1
    local user=$2
    local oname="$3"
    local color=$4

    shift 4
    local hname=$( str::SanitizeString "$oname" )
    local name=${hname,,}

    local userHome="$( sys::GetUserHome $user )"


    # colors
    local color2="625F5C" # Default icon background: numix
    if [[ -z "$color" ]] ; then  # pick random color
        color=$(  tr -dc 'a-fA-F0-9' </dev/urandom \
                | head -c6 \
                | tr '[:upper:]' '[:lower:]' )
    else
           grep -E '^[0-9a-fA-F]{6,6}(:[0-9a-fA-F]{6,6})?$' <<<"$color" \
        || sys::Die "Invalid color: $color"

        if grep -E '^[0-9a-fA-F]{6,6}:[0-9a-fA-F]{6,6}$' <<<"$color" ; then
            color2=${color##*:}
            color=${color%%:*}
        else
            color=${color%%:*}
        fi
    fi

    # check browser
    case $browser in
        basilisk|firefox|firefox-trunk|firefox-esr|waterfox|palemoon) ;;
        *) sys::Die "Unsupported browser: $browser" ; return 1 ;;
    esac

    # check deps
    which sqlite3 &>/dev/null || apt::AddPackages sqlite3


    # INIT
    local icon="/usr/share/icons/$THEME_ICON/48/apps"
    local desktopLauncher="$userHome/.local/share/applications/$name.desktop"
    local shellLauncher="/usr/local/bin/$browser-$user-$name"
    local wmClass
    case $browser in
        # ${browser^}-$user-$name
        firefox)        wmClass="Firefox-$user-$name" ;;
        firefox-trunk)  wmClass="Firefox-trunk-$user-$name" ;;
        firefox-esr)    wmClass="Firefox-esr-$user-$name" ;;
        waterfox)       wmClass="Waterfox-$user-$name" ;;
        *)              wmClass="$oname" ;;
    esac
    local profileParent
    case $browser in
        firefox-trunk)  profileParent="$userHome/.mozilla/$browser-$name" ;;
        firefox-esr)    profileParent="$userHome/.mozilla/$name" ;;
        firefox)        profileParent="$userHome/.mozilla/$name" ;;
        basilisk)       profileParent="$userHome/.moonchild productions/$name" ;;
        palemoon)       profileParent="$userHome/.moonchild productions/$name" ;;
        waterfox)       profileParent="$userHome/.waterfox/$name" ;;
    esac
    local libParent
    case $browser in
        firefox-trunk)  libParent="/usr/lib/$browser" ;;
        firefox-esr)    libParent="/usr/lib/$browser" ;;
        firefox)        libParent="/usr/lib/$browser" ;;
        palemoon)       libParent="/usr/lib/$browser" ;;
        basilisk)       libParent="/opt/basilisk" ;;
        waterfox)       libParent="/opt/waterfox" ;;
    esac
    local applicationIni="$libParent/browser/application-$user-$name.ini"
    local overrideIni="$profileParent/application.ini"

    local ff_vers
    case $browser in
        firefox)        ff_vers=60 ;;
        firefox-trunk)  ff_vers=60 ;;
        firefox-esr)    ff_vers=60 ;;
        # firefox-esr)    ff_vers=52 ;;
        basilisk)       ff_vers=52 ;;
        palemoon)       ff_vers=52 ;;
        waterfox)       ff_vers=52 ;;
    esac


    # Install browser
    firefox::Install $browser


    # prevent overwrite
    for file in \
        "$icon/$browser-$user-$name.svg" \
        "$applicationIni" \
        "$overrideIni" \
        "$profileParent" \
        "$desktopLauncher" \
        "$shellLauncher" \
        "$libParent/$browser-$user-$name" ;
    do [[ -e "$file" ]] && sys::Die "File already exists, remove it first: $file"
    done

    # Profile directory
    sys::Mkdir "$profileParent/.preconfig/extensions" # $user:$user
    sys::Mkdir "$profileParent/.preconfig/searchplugins" # $user:$user


    # hardlink to binary # DEV: usefull for identifying process
    pushd "$libParent"
    ln "$browser" "$browser-$user-$name"
    sys::Chk
    popd


    # application.ini
    sys::Copy "$libParent/application.ini" \
        "$overrideIni"

    sys::Crudini "$overrideIni" \
        "App" "Name" "$oname"

    sed -i -E '/RemotingName=/d' "$overrideIni"
    sys::Chk
    sys::Crudini "$overrideIni" \
        "App" "RemotingName" "$browser-$user-$name"

    sys::Crudini "$overrideIni" \
        "App" "Profile" "${profileParent#$userHome/}"

    sys::Crudini "$overrideIni" \
        "Gecko" "MaxVersion" '99'
        # "Gecko" "MaxVersion" "$ff_vers"'.*'

    sys::Crudini "$overrideIni" \
        "XRE" "EnableProfileMigrator" "0"

    sys::Crudini "$overrideIni" \
        "Crash Reporter" "Enabled" "0"

    # shell launcher
    if [[ "$ff_vers" == "60" ]] ; then

        sys::Write <<EOF "$shellLauncher"
#!/bin/bash
[[ "\$USER" != "$user" ]] && { echo "ERR: Invalid user \$USER" ; exit 1 ; }
export MOZ_USE_XINPUT2=1 # FIX XInput2 support for smooth scrolling & touch events
FF_BRANDING=$browser-$user-$name exec $libParent/$browser-$user-$name --class=$wmClass -override "$overrideIni" -profile "%PROFILE_PATH%" "\$@"
EOF

    else # 52

        sys::Write <<EOF "$shellLauncher"
#!/bin/bash
[[ "\$USER" != "$user" ]] && { echo "ERR: Invalid user \$USER" ; exit 1 ; }
exec $libParent/$browser-$user-$name -app "$applicationIni" -profile "%PROFILE_PATH%" "\$@"
EOF

        # Hardlink or copy application.ini
        if ! ln       "$overrideIni" "$applicationIni" ; then
            sys::Copy "$overrideIni" "$applicationIni"
            chown -hR $user:$user "$overrideIni"
        fi

    fi

    chmod +x "$shellLauncher"

    # .desktop launcher
    mkdir -p "$( dirname "$desktopLauncher" )"
    chown -hR $user:$user "$( dirname "$desktopLauncher" )"
    sed -E \
        -e 's/^(StartupWMClass=).*/\1'"$wmClass"'/' \
        -e '0,/^Name=/s/^Name=.*/Name='"$oname"'\nStartupWMClass='"$wmClass"'/' \
        -e '0,/^Icon=/s/^Icon=.*/Icon='"$browser-$user-$name"'/' \
        -e 's#^(Exec=)(\S*'"$browser"')#\1'"$shellLauncher"'#' \
        -e 's#^(Exec=.*%)u#\1U#' \
        "/usr/share/applications/$browser.desktop" \
        > "$desktopLauncher"
    sys::Chk
    chown -hR $user:$user "$desktopLauncher"

    if [[ -d "$userHome/.config/browser/" ]] ; then
        ln -s "$desktopLauncher" $userHome/.config/browser/
        sys::Chk
        chown -h $user:$user "$userHome/.config/browser/$( basename "$desktopLauncher" )"
    fi

    # DEV: unbranded icon
    sed -E \
        -e 's/#fb9c3d/#'"$color"'/g' \
        -e 's/#(ffd75d|ffdd72)/#'"$color2"'/g' \
        "$icon/firefox-icon-unbranded.svg" \
        > "$icon/$browser-$user-$name.svg"

    # PRECONFIGURE profile at $profileParent/.preconfig
    firefox::ConfigureProfile \
        "$profileParent/.preconfig" \
        "$@" # DEV: Features list

    # Rebrand profile
    if [[ "$ff_vers" == "60" ]] ; then

        sys::Write <<'EOF' "$libParent/defaults/pref/autoconfig.js"
//
pref("general.config.filename", "branding.cfg");
pref("general.config.obscure_value", 0);
EOF

        sys::Write <<EOF "$libParent/branding.cfg"
//
const {classes: Cc, interfaces: Ci, utils: Cu} = Components;
Cu.import("resource://gre/modules/Services.jsm");

let configName = getenv("FF_BRANDING") + ".mod";

let resource = Services.io.getProtocolHandler("resource").QueryInterface(Ci.nsIResProtocolHandler);
let configModuleDir = Services.dirsvc.get("GreD", Ci.nsIFile);
configModuleDir.append(configName);
let configAlias = Services.io.newFileURI(configModuleDir);
resource.setSubstitution(configName, configAlias);

try {
  let chromeManifest = Services.dirsvc.get("GreD", Ci.nsIFile);
  chromeManifest.append(configName);
  chromeManifest.append("chrome.manifest");
  Components.manager.QueryInterface(Ci.nsIComponentRegistrar).autoRegister(chromeManifest);
} catch (e) {
  Cu.reportError(e);
}

EOF

        sys::Write <<EOF "$libParent/$browser-$user-$name.mod/chrome.manifest"
override chrome://branding/locale/brand.dtd resource://$browser-$user-$name.mod/brand.dtd
EOF

        sys::Write <<EOF "$libParent/$browser-$user-$name.mod/brand.dtd"
<!ENTITY  brandShortName        "$oname">
<!ENTITY  brandShorterName      "$oname">
<!ENTITY  brandFullName         "$oname">
<!ENTITY  vendorShortName       "$PRODUCT_NAME">
<!ENTITY  trademarkInfo.part1   "Firefox and the Firefox logos are trademarks of the Mozilla Foundation.">
EOF

    fi


    # distribution files
    local distPath="$libParent/distribution"

    # mount distribution extensions
    local extPath="$( readlink -f "$distPath/extensions" )"
    mkdir -p "$extPath"
    mount --bind \
        "$profileParent/.preconfig/extensions" \
        "$extPath"
    sys::Chk

    # mount distribution searchplugins
    local searchPath="$distPath/searchplugins"
    mkdir -p "$searchPath"
    mount --bind \
        "$profileParent/.preconfig/searchplugins" \
        "$searchPath"
    sys::Chk

    # mount user prefs
    touch "$profileParent/.preconfig/prefs.js" "$libParent/defaults/pref/user.js"
    mount --bind \
        "$profileParent/.preconfig/prefs.js" \
        "$libParent/defaults/pref/user.js"
    sys::Chk

    # Create Profile
    mkdir -p "$profileParent"
    pushd "$profileParent"
    if [[ "$ff_vers" == "60" ]] ; then
        gui::XvfbRun -u $user "$libParent/$browser-$user-$name" -headless -override "$overrideIni" --CreateProfile "$name"
    else
        gui::XvfbRun -u $user  "$libParent/$browser-$user-$name" -app "$applicationIni" --CreateProfile "$name"
    fi
    sys::Chk
    popd

    # Identify profile
    local profilePath=$( find "$profileParent" -maxdepth 1 -iname "*.$name" )
    if [[ ! -d "$profilePath" ]] ; then
        sys::Die "Missing created profile"
        return 1
    fi
    ls -la "$profilePath" # DBG

    # update shell launcher: profilePath
    sys::SedInline "s#%PROFILE_PATH%#$profilePath#" "$shellLauncher"

    # Copy custom files
    apt::AddPackages rsync
    rsync -av \
        --exclude='rebranding' \
        --exclude='extensions' \
        --exclude='searchplugins' \
        --exclude='prefs.js' \
        --exclude='handlers.json.*' \
        --exclude='mimeTypes.rdf.*' \
        --exclude='custom-bookmarks.*' \
        --exclude='shadowfox.mark' \
        --exclude='shadowfox_exclude_uuids' \
        "$profileParent/.preconfig/" \
        "$profilePath"
    sys::Chk

    # Theme Ui: color line
    sys::Write --append <<EOF "$profilePath/chrome/userChrome.css"
/* Rebranding */
#TabsToolbar { background-color: #$THEME_COLOR_BACKGD_HEX !important; }
#nav-bar { border-top: 1px solid #$color !important; margin: 0 !important; }
#main-window[privatebrowsingmode] #nav-bar { border-top-style: dashed !important; }
EOF

    # Overwrite prefs AGAIN
    cat "$profileParent/.preconfig/prefs.js" \
        >>"$profilePath/prefs.js"

# cp "$profileParent/.preconfig/prefs.js" "/tmp/user.js" # DBG

    # DEV: First start required to activate extensions
    if [[ "$ff_vers" == "60" ]] ; then
        # DEV: 60 requires a real WM to gracefully complete autoconfig
        # sys::Write --append <<'EOF' "$profileParent/.preconfig/prefs.js"
        sys::Write --append <<'EOF' "$profilePath/prefs.js"
user_pref("browser.tabs.warnOnClose", false);
EOF
        gui::XvfbXfwmRunClose -u $user 60 "$shellLauncher"

        sys::Write --append <<'EOF' "$profilePath/prefs.js"
user_pref("browser.tabs.warnOnClose", true);
EOF

    else
        # DEV: 52 DOES NOT require a real WM
        gui::XvfbRunKill -u $user 60 "$libParent/$browser-$user-$name" \
            --class=${browser^}-$user-$name \
            -app "$applicationIni" \
            -profile "$profilePath"
    fi

    # Register custom mime types
    firefox_${ff_vers}::ProcessMime
# BUG waterfox missing "$profilePath/mimeTypes.rdf"


    # Hide default searchplugins
    firefox::ResetSearch

    # Remove history
    rm -rd "$profilePath/session"*

    # Reset history & default bookmarks
    firefox_${ff_vers}::ResetPlaces "$profilePath/places.sqlite"

    # Add Custom bookmarks
    for customBookmarks in "$profileParent/.preconfig/custom-bookmarks."* ; do
        local -a urls
        [[ -f "$customBookmarks" ]] || continue
        readarray -t urls <"$customBookmarks"
        firefox::ProcessBookmarks "$profilePath/places.sqlite" \
            "${customBookmarks#*custom-bookmarks.}" \
            "${urls[@]}"
    done

    # NO_UPDATES
    while IFS= read -r extId || [[ -n "$extId" ]] ; do
        sys::JqInline '(.addons[] | select(.id == "'"$extId"'") | .applyBackgroundUpdates) |= 0' \
            "$profilePath/extensions.json"
    done < "$profilePath/NO_UPDATES.txt"
    rm "$profilePath/NO_UPDATES.txt"

    # UNUSED DEV: Second start required to activate theme extension

#     # WORKAROUND stylish BUG https://github.com/stylish-userstyles/stylish/issues/214
#     sys::Write --append <<EOF "$profilePath/prefs.js"
# user_pref("extensions.stylish.editor", 0);
# EOF

    # ShadowFox
    if [[ "$ff_vers" == "60" && -f "$profileParent/.preconfig/shadowfox.mark" ]] ; then
        firefox_60::InstallShadowfox
    fi

    # Eyecare: Darkreader config storage
    if [[ "$ff_vers" == "60" ]] && str::InList Eyecare "$@"; then
        sqlite3 <<'EOF' "$profilePath/storage-sync.sqlite"
INSERT OR REPLACE INTO collection_data (collection_name, record_id, record)
VALUES ('default/addon@darkreader.org', 'key-theme', '{"id":"key-theme","key":"theme","data":{"mode":1,"brightness":90,"contrast":100,"grayscale":0,"sepia":50,"useFont":false,"fontFamily":"system-ui","textStroke":0,"engine":"dynamicTheme","stylesheet":""},"_status":"created"}' );
EOF
    fi

    # DEBUG
    # tar czvf \
    #     "$( dirname "$profilePath")/$( basename "$profilePath").ORIG.tgz" \
    #     "$profilePath/"


    # unmount
    umount -f \
       "$extPath" \
       "$searchPath" \
        "$libParent/defaults/pref/user.js"
    sys::Chk


    case $browser in
        basilisk)       chown -hR $user:$user \
                            $userHome/.moonchild\ productions \
                            $userHome/.cache/moonchild\ productions
                        ;;
        palemoon)       chown -hR $user:$user \
                            $userHome/.moonchild\ productions \
                            $userHome/.cache/.moonchild\ productions
                        ;;
        waterfox)       chown -hR $user:$user \
                            $userHome/.waterfox \
                            $userHome/.cache/waterfox
                        ;;
        firefox)        chown -hR $user:$user \
                            $userHome/.mozilla \
                            $userHome/.cache/mozilla
                        ;;
        *)              chown -hR $user:$user \
                            $userHome/.mozilla \
                            $userHome/.cache/.mozilla # DEV: note the DOT !
                        ;;
    esac

    rm -rf "$profileParent/.preconfig"
}






firefox::GetFeaturesList () # $1:PREFIX
{
    declare -a featz lblz defz
    for feat in $( sys::GetFuncsNamesByRegex '^'"$1"'::' 2>/dev/null ) ; do

        featz+=($feat)

        lblz+=( "$( GetFuncMetaByKey $feat "desc" 2>/dev/null )" )

        def=TRUE
            [[ "$( GetFuncMetaByKey $feat "no-default" 2>/dev/null )" == "true" ]] \
        && def=FALSE
        defz+=($def)

    done

    local idx=0
    for feat in "${featz[@]}" ; do
        [[ $idx -ne 0 ]] && echo -n "|"
        echo -n "$feat|${lblz[$idx]}|${defz[$idx]}"
        ((idx++))
    done

}


firefox::ConfigureProfile () # $1:PATH
{
    local defaultProfile=$1
    local defaultPrefs="$defaultProfile/prefs.js"
    local defaultExts="$defaultProfile/extensions"
    shift

    local ff_feat=firefox_${ff_vers}_feat


    # All features by default
    local features
    if [[ $# -eq 1 ]] && [[ "$1" == "ALL" ]] ; then
        #  DEV "Theme Eyecare Privacy Ui Content Misc Dev"
        features=
        for feat in $( sys::GetFuncsNamesByRegex '^'"$ff_feat"'::' | cut -d':' -f3- ) ; do
              [[ "$( GetFuncMetaByKey "$ff_feat::$feat" "no-default" )" == "true" ]] \
           || features="$features $feat"
        done
    else
        features=$*
    fi
    features=$( str::SortWords $features )


    # Check features
    local func
    for feat in $features ; do
        func="$ff_feat::$feat"

           [[ "$( type -t $func 2>/dev/null )" == "function" ]] \
        || sys::Die "Unknown function: $func"
    done

    # Run features
    mkdir -p "$defaultExts"
    for feat in $features ; do
        func="$ff_feat::$feat"
        $func # "$defaultProfile" "$browser" "$@"
    done


    chown -hR $user:$user "$defaultProfile"

}



firefox::Install () # $1:browser
{
    local browser="$1"

    [[ -z "$browser" ]] && browser="firefox-esr"

    # Check in PATH and not a dpkg-divert asset
       which "$browser" &>/dev/null \
    && [[ -z "$( dpkg-divert --listpackage "$( which "$browser" 2>/dev/null )" 2>/dev/null )" ]] \
    && return

    case $browser in

        firefox)        apt::AddPpaPackages ubuntu-mozilla-security/ppa $browser ;;
        firefox-trunk)  apt::AddPpaPackages ubuntu-mozilla-daily/ppa    $browser ;;
        firefox-esr)    apt::AddPpaPackages jonathonf/firefox-esr       $browser ;
                        # apt-mark hold firefox-esr
                        ;;

        basilisk)
              net::DownloadUntarBzip \
                "http://eu.basilisk-browser.org/release/basilisk-latest.linux64.tar.bz2" \
                /opt

            sys::Write <<EOF /usr/share/applications/basilisk.desktop
[Desktop Entry]
Type=Application
Terminal=false
Name=Basilisk
Exec=/opt/basilisk/basilisk
Icon=web-browser
EOF
            ;;

        palemoon)
            apt::AddSource palemoon \
                "http://download.opensuse.org/repositories/home:/stevenpusser/xUbuntu_$(lsb_release -rs)/" \
                "/" \
                "http://download.opensuse.org/repositories/home:/stevenpusser/xUbuntu_$(lsb_release -rs)/Release.key"
            apt::AddPackages $browser
            ;;

        waterfox)
            apt::AddSource waterfox \
                "https://dl.bintray.com/hawkeye116477/waterfox-deb" \
                "release main" \
                "https://bintray.com/user/downloadSubjectPublicKey?username=hawkeye116477"
            apt::AddPackages $browser
            ;;

        *)
            apt::AddPackages $browser
    esac

    # Disable launcher
    gui::HideApps $browser

    # PLUGIN: adobe flash
    InstallFlash

    # PLUGIN: gnome shell extensions web connector backend
    # UNUSED apt::AddPpaPackages ne0sight/chrome-gnome-shell chrome-gnome-shell

#     # FIX XInput2 support for smooth scrolling & touch events
#     local bashrc=${userHome:-$HOME}/.bashrc
#     [[ -d "${userHome:-$HOME}/.bashrc.d" ]] && bashrc=${userHome:-$HOME}/.bashrc.d/env_firefox
#         sys::Write <<'EOF' "$bashrc" $user:$user 700
# export MOZ_USE_XINPUT2=1
# EOF


# UNUSED CONF
#     sys::Write --append <<'EOF' /etc/$browser/syspref.js
# /* */
# EOF

    local libParent
    case $browser in
        basilisk) libParent="/opt/basilisk" ;;
        waterfox) libParent="/opt/waterfox" ;;
        *)        libParent="/usr/lib/$browser" ;;
    esac
    sys::Write --append <<'EOF' $libParent/browser/defaults/pref/channel-prefs.js
/* Scopes */
defaultPref("extensions.autoDisableScopes", 0);
defaultPref("extensions.enabledScopes", 15);
EOF
    sys::Write --append <<'EOF' $libParent/browser/defaults/pref/user.js
/* Scopes */
defaultPref("extensions.autoDisableScopes", 0);
defaultPref("extensions.enabledScopes", 15);
defaultPref("extensions.shownSelectionUI", true);
EOF

    apt::AddPackages libwayland-egl1

}


InstallFlash ()
{

    # NPAPI PLUGIN: Adobe Flash from Canonical partner channel
    dpkg-query -s adobe-flashplugin &>/dev/null && return
    add-apt-repository --yes "deb http://archive.canonical.com/ $(lsb_release -sc) partner"
    apt::Update

    # Install player + settings ui
    apt::AddPackages adobe-flashplugin adobe-flash-properties-gtk
    gui::AddAppFolder Settings flash-player-properties
    gui::SetAppName flash-player-properties Flash


    # Flash Hardware accel
# TODO CHECK INTEL i915 Check Package libvdpau-va-gl1 is installed
    # DOC: http://www.ghacks.net/2010/09/07/enforce-global-flash-player-security-and-privacy-settings/
    sys::Write <<'EOF' /etc/adobe/mms.cfg
EnableLinuxHWVideoDecode=1
OverrideGPUValidation=1
EOF

}




