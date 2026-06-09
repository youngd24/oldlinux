#!/bin/bash
# copy-to-usb.sh
#
# Copies built GoTek image directories from images/ into the USB key tree
# at ../usbkeys/oldlinux/mcc-1.0/.
#
# Source:      <script-dir>/images/{bootroot,packages,extra_packages}/
# Destination: <script-dir>/../usbkeys/oldlinux/mcc-1.0/{bootroot,packages,extra_packages}/
#
# Usage: bash copy-to-usb.sh [--force]
#   --force   overwrite an existing destination directory; without this flag
#             subdirectories that already exist at the destination are skipped

set -e

# SCRIPT_DIR — absolute path to this script's directory, used to locate
# the images/ source and usbkeys/ destination regardless of where the script
# is invoked from.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# IMG_DIR — root of the built image tree, containing the subdirectories
# produced by build-images.sh.
IMG_DIR="$SCRIPT_DIR/images"

# USB_DEST — destination directory under the USB key tree.
USB_DEST="$SCRIPT_DIR/../usbkeys/oldlinux/mcc-1.0"
USB_DEST="$( cd "$USB_DEST" && pwd )"   # resolve to absolute path

# SUBDIRS — the three image subdirectories to copy. These match what
# build-images.sh produces and what lands under mcc-1.0/ on the USB key.
SUBDIRS="bootroot packages extra_packages"

##############################################################################
# Argument parsing
#
#   FORCE — when 1, an existing destination subdirectory is removed before
#           copying so the copy is always a clean, complete replacement.
#           Defaults to 0: existing subdirectories are skipped with a warning.
##############################################################################

FORCE=0

for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        *) echo "ERROR: Unknown option: $arg"; exit 1 ;;
    esac
done

##############################################################################
# Validate source and destination roots before doing any work
##############################################################################

if [ ! -d "$IMG_DIR" ]; then
    echo "ERROR: images/ directory not found at $IMG_DIR"
    echo "  Run build-images.sh first to generate images."
    exit 1
fi

if [ ! -d "$USB_DEST" ]; then
    echo "ERROR: USB destination not found at $USB_DEST"
    exit 1
fi

##############################################################################
# copy_subdir <name>
#
# Copies one subdirectory from images/ to the USB destination.
#
# Arguments:
#   name — subdirectory name (bootroot, packages, or extra_packages)
#
# Variables used:
#   src   — full path to the source subdirectory under IMG_DIR
#   dest  — full destination path under USB_DEST
#   FORCE — controls whether an existing dest is overwritten or skipped
##############################################################################
copy_subdir() {
    local name="$1"
    local src="$IMG_DIR/$name"
    local dest="$USB_DEST/$name"

    if [ ! -d "$src" ]; then
        echo "  $name: source not found at $src, skipping"
        return
    fi

    if [ -d "$dest" ]; then
        if [ "$FORCE" -eq 1 ]; then
            echo "  $name: destination exists, removing and replacing"
            rm -rf "$dest"
        else
            echo "  $name: already exists at $dest (use --force to overwrite)"
            return
        fi
    fi

    echo "  $name: $src -> $dest"
    cp -r "$src" "$dest"
    echo "  $name: done ($(find "$dest" -name '*.img' | wc -l) images)"
}

##############################################################################
# Main
##############################################################################

echo "========================================"
echo " MCC-1.0 GoTek USB copy"
echo " Source:      $IMG_DIR"
echo " Destination: $USB_DEST"
echo "========================================"
echo

for subdir in $SUBDIRS; do
    copy_subdir "$subdir"
done

echo
echo "Done."
