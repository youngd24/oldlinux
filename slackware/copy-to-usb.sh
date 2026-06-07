#!/bin/bash
# copy-to-usb.sh
#
# Copies GoTek image directories from gotek/<version>/ into the USB key tree
# at ../usbkeys/oldlinux/slackware/<version>/.
#
# Also converts gotek/README.md to plain text and writes it to
# ../usbkeys/oldlinux/slackware/README.txt for end-user reference.
# Uses pandoc if available, otherwise falls back to a sed pipeline.
#
# Source:      <script-dir>/gotek/<version>/
# Destination: <script-dir>/../usbkeys/oldlinux/slackware/<version>/
#
# With no version argument, every subdirectory found in gotek/ is copied.
# With a version argument, only that version is copied.
#
# Usage: bash copy-to-usb.sh [<version>] [--force]
#   <version>   name of the version directory to copy (e.g. slackware-2.0.0)
#               omit to copy all versions found in gotek/
#   --force     overwrite the destination if it already exists;
#               without this flag the script skips versions that are already
#               present in the destination tree

set -e

# SCRIPT_DIR — absolute path to this script's directory, used to locate
# the gotek/ source and usbkeys/ destination regardless of where the script
# is invoked from.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# GOTEK_DIR — root of the generated image tree; contains one subdirectory per
# processed Slackware version (e.g. gotek/slackware-2.0.0/).
GOTEK_DIR="$SCRIPT_DIR/gotek"

# USB_DEST — destination directory on the USB key where version directories
# are written. Mirrors the oldlinux/slackware/ path so the USB tree stays
# organised consistently alongside other oldlinux content.
USB_DEST="$SCRIPT_DIR/../usbkeys/oldlinux/slackware"
USB_DEST="$( cd "$USB_DEST" && pwd )"   # resolve to absolute path

##############################################################################
# Argument parsing
#
#   FORCE    — when 1, an existing destination directory is removed before
#              copying so the copy is always a clean, complete replacement.
#              Defaults to 0: existing versions are skipped with a warning.
#   VERSION  — if set, copy only this named version; if empty, copy all
#              subdirectories found in GOTEK_DIR.
##############################################################################

FORCE=0
VERSION=""

for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        -*) echo "ERROR: Unknown option: $arg"; exit 1 ;;
        *)  VERSION="$arg" ;;
    esac
done

##############################################################################
# Validate source and destination roots exist before doing any work
##############################################################################

if [ ! -d "$GOTEK_DIR" ]; then
    echo "ERROR: gotek/ directory not found at $GOTEK_DIR"
    echo "  Run make-gotek-images.sh first to generate images."
    exit 1
fi

if [ ! -d "$USB_DEST" ]; then
    echo "ERROR: USB destination not found at $USB_DEST"
    exit 1
fi

##############################################################################
# copy_version <version-dir-path>
#
# Copies a single gotek version directory to the USB destination.
#
# Arguments:
#   src  — full path to the gotek version directory (e.g. gotek/slackware-2.0.0)
#
# Variables used:
#   name  — bare directory name extracted from src (e.g. slackware-2.0.0)
#   dest  — full destination path under USB_DEST
#   FORCE — controls whether an existing dest is overwritten or skipped
##############################################################################
copy_version() {
    local src="$1"
    local name
    name="$(basename "$src")"
    local dest="$USB_DEST/$name"

    if [ -d "$dest" ]; then
        if [ "$FORCE" -eq 1 ]; then
            echo "  $name: destination exists, removing and replacing"
            rm -rf "$dest"
        else
            echo "  $name: already exists at $dest, skipping (use --force to overwrite)"
            return
        fi
    fi

    echo "  $name: $src -> $dest"
    cp -r "$src" "$dest"
    echo "  $name: done"
}

##############################################################################
# copy_readme
#
# Converts gotek/README.md to plain text and writes it to USB_DEST/README.txt
# so an end user browsing the USB stick has a readable reference without
# needing a Markdown renderer.
#
# Conversion order:
#   1. pandoc -t plain  — clean, accurate output if pandoc is installed
#   2. sed pipeline     — fallback that handles the markdown used in this file:
#                         heading markers (#, ##), bold (**text**), inline code
#                         (`text`), code fences (```), horizontal rules (---),
#                         and table formatting (| col | col |)
##############################################################################
copy_readme() {
    local src="$GOTEK_DIR/README.md"
    local dest="$USB_DEST/README.txt"

    if [ ! -f "$src" ]; then
        echo "  README: $src not found, skipping"
        return
    fi

    echo "  README: $src -> $dest"

    if command -v pandoc &>/dev/null; then
        pandoc -t plain --wrap=none "$src" > "$dest"
        echo "  README: converted via pandoc"
    else
        sed \
            -e '/^```/d' \
            -e 's/`\([^`]*\)`/\1/g' \
            -e 's/\*\*\([^*]*\)\*\*/\1/g' \
            -e 's/^### /   /' \
            -e 's/^## //' \
            -e 's/^# //' \
            -e 's/^---$/----------------------------------------/' \
            -e '/^|[-: |]*|$/d' \
            -e 's/^| //' \
            -e 's/ |$//' \
            -e 's/ | /    /g' \
            "$src" > "$dest"
        echo "  README: converted via sed (install pandoc for better output)"
    fi
}

##############################################################################
# Main
##############################################################################

echo "========================================"
echo " GoTek USB copy"
echo " Source:      $GOTEK_DIR"
echo " Destination: $USB_DEST"
echo "========================================"
echo

if [ -n "$VERSION" ]; then
    # Single version requested — validate it exists in gotek/ then copy
    src="$GOTEK_DIR/$VERSION"
    if [ ! -d "$src" ]; then
        echo "ERROR: $VERSION not found in $GOTEK_DIR"
        echo "  Available versions:"
        for d in "$GOTEK_DIR"/*/; do
            [ -d "$d" ] && echo "    $(basename "$d")"
        done
        exit 1
    fi
    copy_version "$src"
else
    # No version specified — copy every subdirectory in gotek/
    found=0
    for src in "$GOTEK_DIR"/*/; do
        [ -d "$src" ] || continue
        copy_version "$src"
        found=1
    done
    if [ "$found" -eq 0 ]; then
        echo "No version directories found in $GOTEK_DIR"
        echo "  Run make-gotek-images.sh first to generate images."
        exit 1
    fi
fi

echo
echo "--- README ---"
copy_readme

echo
echo "Done."
echo
