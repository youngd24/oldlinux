#!/bin/bash
# build-images.sh
#
# Creates GoTek-compatible .img files from the MCC-1.0 boot and root disk images.
#
# -----------------------------------------------------------------------------
# Background
# -----------------------------------------------------------------------------
# MCC Interim Linux 1.0 ships three compressed floppy images in MCC-1.0/images/:
#
#   cdrmboot.gz  — boot kernel with CD-ROM driver support compiled in
#   nocdboot.gz  — boot kernel without CD-ROM support (smaller, more generic)
#   root.gz      — root disk (installer environment)
#
# Each .gz decompresses to a raw floppy image at 1.2MB geometry (1,228,800
# bytes / 2400 sectors). The GoTek expects 1.44MB images (1,474,560 bytes /
# 2880 sectors), so each image is padded with zeros to the correct size after
# decompression.
#
# Output: images/bootroot/<basename>.img, e.g.
#   images/bootroot/cdrmboot.img
#   images/bootroot/nocdboot.img
#   images/bootroot/root.img
#
# -----------------------------------------------------------------------------
# Requirements
# -----------------------------------------------------------------------------
#   dd        — writes raw images and creates zero fills (coreutils, always present)
#   gunzip    — decompresses .gz files (gzip package, almost always present)
#
# Usage: bash build-images.sh [--force]
#   --force   overwrite existing .img files; without this flag existing images
#             are skipped with a warning
# -----------------------------------------------------------------------------

set -e

# SCRIPT_DIR — absolute path to the directory containing this script.
# Used to locate the images/ directory regardless of where the script is called from.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# IMAGES_DIR — directory containing the source .gz files.
IMAGES_DIR="$SCRIPT_DIR/MCC-1.0/images"

# OUT_DIR — directory where built .img files are written.
OUT_DIR="$SCRIPT_DIR/images/bootroot"

# Floppy geometry constants — these never change for a 1.44MB DD floppy.
# FLOPPY_SECTORS — total 512-byte sectors on a 1.44MB floppy (80 tracks *
#                  2 heads * 18 sectors/track = 2880).
# FLOPPY_BYTES   — exact byte size every output .img must be (2880 * 512).
#                  The source images are 1.2MB (2400 sectors); the difference
#                  is filled with zeros so the GoTek sees valid geometry.
FLOPPY_SECTORS=2880
FLOPPY_BYTES=1474560

# FORCE — when 1, overwrite existing .img files; when 0, skip them.
# Set by --force argument.
FORCE=0

##############################################################################
# Argument parsing
##############################################################################

for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        *)
            echo "Usage: $0 [--force]"
            echo "  --force   overwrite existing .img files"
            exit 1
            ;;
    esac
done

##############################################################################
# check_deps
#
# Verifies that all external tools the script needs are installed before any
# work begins, so a missing tool fails cleanly rather than midway through.
#
# Tools checked:
#   dd      — writes raw images and appends zero padding
#   gunzip  — decompresses the source .gz files
##############################################################################
check_deps() {
    local missing=0
    echo "checking for dependencies"
    for cmd in dd gunzip; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "ERROR: '$cmd' not found"
            missing=1
        fi
    done
    if [ "$missing" -eq 1 ]; then
        exit 1
    else
        echo " - none missing"
    fi
}

##############################################################################
# Main
##############################################################################

echo "=========================================="
echo " MCC Interim Linux GoTek image builder"
echo " Source: $IMAGES_DIR"
echo " Output: $OUT_DIR"
echo "=========================================="
echo

check_deps

# Verify source images directory exists before iterating
if [ ! -d "$IMAGES_DIR" ]; then
    echo "ERROR: images directory not found: $IMAGES_DIR"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUT_DIR"

echo "--- Boot and root disk images ---"

found=0
for f in "$IMAGES_DIR"/*.gz; do
    [ -f "$f" ] || continue
    found=1

    # base — filename without the .gz extension, used to name the output
    base=$(basename "$f" .gz)

    # imgfile — destination .img path in the output directory
    imgfile="$OUT_DIR/${base}.img"

    if [ -f "$imgfile" ] && [ "$FORCE" -eq 0 ]; then
        echo "  SKIP: $imgfile already exists (use --force to overwrite)"
        continue
    fi

    echo "  $f -> $imgfile"

    # Decompress and write to the output image. gunzip -c decompresses to
    # stdout without removing the source file. dd with bs=512 conv=sync
    # zero-pads the final block to a full sector boundary.
    gunzip -c "$f" | dd of="$imgfile" bs=512 conv=sync status=none

    # Pad to the full 1.44MB GoTek size if the decompressed image is smaller.
    # MCC images decompress to 1,228,800 bytes (1.2MB floppy geometry) and
    # need zeros appended to reach 1,474,560 bytes (1.44MB geometry).
    size=$(stat -c%s "$imgfile")
    if [ "$size" -lt "$FLOPPY_BYTES" ]; then
        dd if=/dev/zero bs=1 count=$((FLOPPY_BYTES - size)) >> "$imgfile" status=none
        echo "    padded from $size to $FLOPPY_BYTES bytes"
    fi

    echo "    done ($(stat -c%s "$imgfile") bytes)"
done

if [ "$found" -eq 0 ]; then
    echo "  no .gz files found in $IMAGES_DIR"
    exit 1
fi

echo
echo "Done."
