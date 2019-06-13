#!/bin/bash


# CONST
SELF="$( readlink -f "$BASH_SOURCE" )"
CWD="$( dirname "$SELF" )"
SRC="$CWD/src"
TARGET="$CWD/build"

# FUNC

Die ()
{
    echo "ERROR: $*" >&2
    exit 1
}

Usage ()
{
    echo "$SELF [ all | core | full ]"
    exit 1
}

TestBash ()
{
    bash -n "$1" # || return 1
}

CoreBuild ()
{
    local target="$TARGET/gnowledge-core"

    for i in "${BUILD_CORE[@]}" ; do
       TestBash "$i" || Die "Test failed in $i"
    done

    rm -f "$target"
       cat "${BUILD_CORE[@]}" \
        >"$target"            \
    || Die ""

       chmod +x,-w "$target" \
    || Die ""

       TestBash "$target" \
    && echo "Successfully built $target" \
    || Die "ERROR: $target is invalid"
}

FullBuild ()
{
    local target="$TARGET/gnowledge"

    for i in "${BUILD_FULL[@]}" ; do
       TestBash "$i" || Die "Test failed in $i"
    done

    rm -f "$target"
       cat "${BUILD_FULL[@]}" \
        >"$target"            \
    || Die ""

       chmod +x,-w "$target" \
    || Die ""

       TestBash "$target" \
    && echo "Successfully built $target" \
    || Die "ERROR: $target is invalid"
}

# FUNC Components

declare -a CORE=(
    "$SRC/core/core-init.bash"

    "$SRC/core/lib-sys.bash"
    "$SRC/core/lib-str.bash"
    "$SRC/core/lib-fs.bash"

    "$SRC/core/lib-zfs.bash"
    "$SRC/core/lib-net.bash"
    "$SRC/core/lib-apt.bash"

    "$SRC/core/lib-xorg.bash"
    "$SRC/core/lib-ui.bash"

    "$SRC/core/core-ui.bash"
    "$SRC/core/core-menu.bash"
    "$SRC/core/core.bash"
    "$SRC/core/core-main.bash"
)

declare -a CLI=(
    "$SRC/cli/lib-cli.bash"
    "$SRC/cli/cli.bash"
)

declare -a GUI=(
    "$SRC/gui/lib-gui.bash"
    "$SRC/gui/lib-vbox.bash"

    "$SRC/gui/gui-drivers.bash"
    "$SRC/gui/gui.bash"
)

declare -a APPS=(
    "$SRC/apps/lib-firefox.bash"
    "$SRC/apps/lib-firefox_60.bash"

    "$SRC/apps/settings.bash"
    "$SRC/apps/software.bash"
    "$SRC/apps/accessories.bash"
    "$SRC/apps/storage.bash"
    "$SRC/apps/engines.bash"

    "$SRC/apps/browse.bash"
    "$SRC/apps/net.bash"
    "$SRC/apps/transfer.bash"
    "$SRC/apps/speak.bash"
    "$SRC/apps/personal.bash"
    "$SRC/apps/entertain.bash"

    "$SRC/apps/audio.bash"
    "$SRC/apps/graphics.bash"
    "$SRC/apps/video.bash"

    "$SRC/apps/office.bash"
    "$SRC/apps/code.bash"
    "$SRC/apps/learn.bash"
)


declare -a BUILD_CORE=(
    "$SRC/core/core-head.bash"
    "${CORE[@]}"
    "$SRC/core/core-run.bash"
)

declare -a BUILD_FULL=(

    "$SRC/core/full-head.bash"

    "${CORE[@]}"

    "$SRC/core/full.bash"

    "${CLI[@]}"

    "${GUI[@]}"

    "${APPS[@]}"

    "$SRC/core/core-run.bash"
)
    # "$SRC/full/full-hooks.bash"
    # "$SRC/full/theme.bash"

# MAIN
mkdir -p "$TARGET" || Die ""

case $1 in
    core) CoreBuild ;;
    full) FullBuild ;;
    all)  CoreBuild && FullBuild ;;
    *)    Usage ;;
esac



