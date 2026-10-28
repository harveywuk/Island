#!/bin/sh
# Screenshots for the Island (services/Capture.qml), after
# crates/shoji-island/src/island/capture.rs. Every value arrives as a
# positional argument; nothing here is built by string interpolation in QML.
# Each subcommand prints one line for Capture.qml to read:
#
#   capture.sh select portion
#   capture.sh select window "<x,y wxh title>\n..."   (slurp -r boxes)
#       -> "region<TAB>x,y wxh" | "cancelled" | "failed<TAB>why"
#   capture.sh grab <copy 0|1> <region or ""> <output or "">
#       -> "saved<TAB>/path/Screenshot ….png" | "copied" | "failed<TAB>why"
#   capture.sh show <file:// uri, percent-encoded> <folder>
#   capture.sh copyfile <path>
#   capture.sh trash <path>
#
# Overrides (as the Rust Island's tests): SHOJI_ISLAND_SLURP, SHOJI_ISLAND_GRIM,
# SHOJI_ISLAND_TRASH, SHOJI_ISLAND_SCREENSHOTS_DIR (capture.rs:409-416).

fail() {
    printf 'failed\t%s\n' "$1"
    exit 0
}

have() {
    command -v "$1" >/dev/null 2>&1
}

select_region() {
    slurp=${SHOJI_ISLAND_SLURP:-slurp}
    have "$slurp" || fail "$slurp is not installed"
    # capture.rs:527-534 — a window is tinted in the shell's blue under the
    # pointer; a portion is outlined in white with its size shown.
    if [ "$1" = window ]; then
        region=$(printf '%s' "$2" | "$slurp" -r -b '#00000000' -B '#00000000' -c '#7a8eff' -s '#4a5fd738' -w 2 2>/dev/null) || region=
    else
        region=$("$slurp" -d -b '#00000038' -c '#ffffff' -s '#ffffff12' -w 1 </dev/null 2>/dev/null) || region=
    fi
    # Only the first line ("x,y wxh"); slurp prints nothing when cancelled.
    region=$(printf '%s\n' "$region" | head -n 1)
    if [ -n "$region" ]; then
        printf 'region\t%s\n' "$region"
    else
        printf 'cancelled\n'
    fi
}

grab() {
    copy=$1
    region=$2
    output=$3
    grim=${SHOJI_ISLAND_GRIM:-grim}
    have "$grim" || fail "$grim is not installed"
    if [ -n "$region" ]; then
        set -- -g "$region"
    elif [ -n "$output" ]; then
        set -- -o "$output"
    else
        set --
    fi

    if [ "$copy" = 1 ]; then
        have wl-copy || fail "wl-copy is not installed"
        tmp=$(mktemp "${TMPDIR:-/tmp}/shoji-shot.XXXXXX") || fail "no temporary file"
        # Into a file first: a pipe would hide grim's failure.
        if ! "$grim" "$@" - >"$tmp" 2>/dev/null || [ ! -s "$tmp" ]; then
            rm -f "$tmp"
            fail "$grim failed"
        fi
        if ! wl-copy --type image/png <"$tmp" >/dev/null 2>&1; then
            rm -f "$tmp"
            fail "wl-copy failed"
        fi
        rm -f "$tmp"
        printf 'copied\n'
        return
    fi

    dir=${SHOJI_ISLAND_SCREENSHOTS_DIR:-${HOME:-.}/Pictures/Screenshots}
    case $dir in
    /*) ;;
    *) dir=./$dir ;;
    esac
    mkdir -p "$dir" 2>/dev/null || fail "$dir could not be made"
    # capture.rs:418-429 — macOS's name; :431-442 — " (2)" when taken.
    name="Screenshot $(date '+%Y-%m-%d at %H.%M.%S')"
    path=$dir/$name.png
    n=2
    while [ -e "$path" ]; do
        path="$dir/$name ($n).png"
        n=$((n + 1))
    done
    # Written beside it, then renamed, so a half-written PNG never shows.
    part="$dir/.$name.$$.part"
    if ! "$grim" "$@" - >"$part" 2>/dev/null || [ ! -s "$part" ]; then
        rm -f "$part"
        fail "$grim failed"
    fi
    mv -f "$part" "$path" 2>/dev/null || {
        rm -f "$part"
        fail "$path could not be written"
    }
    printf 'saved\t%s\n' "$path"
}

# file_actions.rs:31-53 — the file manager's ShowItems, else the folder.
show() {
    if [ -n "${SHOJI_ISLAND_OPEN:-}" ]; then
        exec "$SHOJI_ISLAND_OPEN" "$2"
    fi
    if have dbus-send && dbus-send --session --print-reply --dest=org.freedesktop.FileManager1 \
        /org/freedesktop/FileManager1 org.freedesktop.FileManager1.ShowItems \
        "array:string:$1" "string:" >/dev/null 2>&1; then
        exit 0
    fi
    exec xdg-open "$2"
}

case $1 in
select) select_region "$2" "${3:-}" ;;
grab) grab "$2" "$3" "$4" ;;
show) show "$2" "$3" ;;
copyfile) exec wl-copy --type image/png <"$2" ;;
trash)
    if [ -n "${SHOJI_ISLAND_TRASH:-}" ]; then
        exec "$SHOJI_ISLAND_TRASH" "$2"
    fi
    exec gio trash -- "$2"
    ;;
*) fail "unknown command: $1" ;;
esac
