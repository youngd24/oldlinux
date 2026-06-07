#!/bin/bash
# make-gotek-images.sh
#
# Creates GoTek-compatible .img files from a local mirror of a Slackware version.
#
# GoTek drives emulate floppy drives using .img files stored on a USB stick.
# Each .img must be exactly 1.44MB (2880 x 512-byte sectors) to be recognized
# as a standard 1.44MB floppy by the BIOS and installer.
#
# Three types of images are produced:
#   bootdisks/  — raw kernel images, written directly with dd (no filesystem)
#   rootdisks/  — raw root ramdisk images, same treatment as boot disks
#   slakware/   — FAT12 data disks containing package sets (a, ap, d, x, etc.)
#
# Output is written to gotek/<version>/ alongside this script.
#
# Requires: dosfstools (mkfs.fat), coreutils (dd, cp)
# WSL2: sudo apt install dosfstools
#
# Usage: bash make-gotek-images.sh <slackware-dir> [--force]
#   <slackware-dir>  path to the slackware version directory (e.g. slackware-2.0.0)
#   --force          remove output directory if it already exists

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Parse command line arguments
FORCE=0
TARGET_DIR=""
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        -*) echo "ERROR: Unknown option: $arg"; exit 1 ;;
        *)  TARGET_DIR="$arg" ;;
    esac
done

if [ -z "$TARGET_DIR" ]; then
    echo "Usage: $(basename "$0") <slackware-dir> [--force]"
    echo "  e.g. $(basename "$0") slackware-2.0.0"
    exit 1
fi

# Resolve to absolute path and derive the version name from the directory basename
TARGET_DIR="$( cd "$TARGET_DIR" && pwd )"
VERSION="$(basename "$TARGET_DIR")"

# Source directory layout — must exist inside the target tree
SLAKWARE_DIR="$TARGET_DIR/slakware"       # package set subdirs (a1, ap2, x3, etc.)
BOOT_DIR="$TARGET_DIR/bootdsks.144"       # gzipped raw kernel images
ROOT_DIR="$TARGET_DIR/rootdsks.144"       # gzipped raw root ramdisk images
OUT_DIR="$SCRIPT_DIR/gotek/$VERSION"      # all generated .img files go here

# Number of disks in each package series.
# These match the disk counts used by the original Slackware makeflop script.
declare -A SERIES_COUNT=(
    [a]=3
    [ap]=4
    [d]=6
    [e]=5
    [f]=1
    [i]=2
    [iv]=2
    [n]=3
    [oop]=1
    [q]=3
    [t]=5
    [tcl]=2
    [u]=1
    [x]=8
    [xap]=3
    [xd]=3
    [xv]=2
    [y]=1
)

# Process series in this order to match the original disk set numbering
SERIES_ORDER="a ap d e f i iv n oop q t tcl u x xap xd xv y"

# Standard 1.44MB floppy geometry — 80 tracks, 2 heads, 18 sectors/track
FLOPPY_SECTORS=2880
FLOPPY_BYTES=1474560   # 2880 * 512

##############################################################################
# check_deps — verify required tools are installed before doing any work
##############################################################################
check_deps() {
    local missing=0
    echo "checking for dependencies"
    for cmd in mkfs.fat dd cp; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "ERROR: '$cmd' not found. Install dosfstools: sudo apt install dosfstools"
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
# check_dirs — verify the expected source directories exist
##############################################################################
check_dirs() {
    local ok=1
    echo "checking for needed directories"
    for d in "$SLAKWARE_DIR" "$BOOT_DIR" "$ROOT_DIR"; do
        if [ ! -d "$d" ]; then
            echo "ERROR: Directory '$d' not found in $TARGET_DIR."
            ok=0
        fi
    done
    if [ "$ok" -eq 0 ]; then
	exit 1
    else
	echo " - all ok"
    fi
}

##############################################################################
# make_fat_image <imgfile> <srcdir>
#
# Creates a 1.44MB FAT12 floppy image and populates it with only the files
# listed in srcdir/00index.txt. The 00index.txt file itself is also copied
# since it appears in its own listing.
#
# FAT12 is used because it is what a real 1.44MB floppy would use, and the
# Slackware installer expects a standard DOS-formatted disk.
##############################################################################
make_fat_image() {
    local imgfile="$1"
    local srcdir="$2"

    # Allocate a zero-filled file of exactly the right floppy size
    dd if=/dev/zero of="$imgfile" bs=512 count=$FLOPPY_SECTORS status=none

    # Format as FAT12 with an empty volume label to match a freshly formatted
    # DOS floppy. mkfs.fat selects FAT12 automatically for this geometry.
    mkfs.fat -F 12 -n "" "$imgfile" &>/dev/null

    # Mount the image via loopback so we can write files into it
    local mnt
    mnt=$(mktemp -d)
    sudo mount -o loop "$imgfile" "$mnt"

    # Copy only the files listed in 00index.txt rather than everything in the
    # directory. The mirror includes .md5, .sha256, .metalink, and other
    # sidecar files that don't belong on the install disk and would waste space.
    # 00index.txt format: <filename>  <size-in-bytes>  (one entry per line)
    awk '{print $1}' "$srcdir/00index.txt" | while read -r f; do
        sudo cp "$srcdir/$f" "$mnt/"
    done

    sudo umount "$mnt"
    rmdir "$mnt"
}

##############################################################################
# Main
##############################################################################

echo "=========================================="
echo " Slackware GoTek image builder: $VERSION"
echo "=========================================="
echo

# Guard against accidentally overwriting a previous run. Require --force to
# proceed if the output directory already exists.
if [ -d "$OUT_DIR" ]; then
    if [ "$FORCE" -eq 1 ]; then
        echo "Output directory $OUT_DIR already exists, removing it."
        rm -rf "$OUT_DIR"
    else
        echo "ERROR: Output directory $OUT_DIR already exists. Use --force to remove it."
        exit 1
    fi
fi

# Create the output directory tree up front
mkdir -p "$OUT_DIR" "$OUT_DIR/bootdisks" "$OUT_DIR/rootdisks" "$OUT_DIR/slakware"

check_deps
check_dirs

##############################################################################
# Boot disk images — raw dd, no filesystem
#
# bootdsks.144/ contains gzipped raw kernel images. Each is decompressed and
# written sector-by-sector directly into the image file. If the kernel image
# is smaller than 1.44MB it is zero-padded to the full floppy size so the
# GoTek drive sees a complete disk.
##############################################################################

echo "--- Boot disk images ---"
for f in "$BOOT_DIR"/*.gz; do
    [ -f "$f" ] || continue
    base=$(basename "$f" .gz)
    imgfile="$OUT_DIR/bootdisks/boot_${base}.img"
    echo "  $f -> $imgfile"
    gunzip -c "$f" | dd of="$imgfile" bs=512 conv=sync status=none
    # Pad to full 1.44MB if the kernel image is smaller
    size=$(stat -c%s "$imgfile")
    if [ "$size" -lt "$FLOPPY_BYTES" ]; then
        dd if=/dev/zero bs=1 count=$((FLOPPY_BYTES - size)) >> "$imgfile" status=none
    fi
done

##############################################################################
# Root disk images — same treatment as boot disks
#
# rootdsks.144/ contains gzipped raw ramdisk images loaded by the installer
# after the kernel boots. Written and padded identically to boot disks.
##############################################################################

echo
echo "--- Root disk images ---"
for f in "$ROOT_DIR"/*.gz; do
    [ -f "$f" ] || continue
    base=$(basename "$f" .gz)
    imgfile="$OUT_DIR/rootdisks/root_${base}.img"
    echo "  $f -> $imgfile"
    gunzip -c "$f" | dd of="$imgfile" bs=512 conv=sync status=none
    # Pad to full 1.44MB if the ramdisk image is smaller
    size=$(stat -c%s "$imgfile")
    if [ "$size" -lt "$FLOPPY_BYTES" ]; then
        dd if=/dev/zero bs=1 count=$((FLOPPY_BYTES - size)) >> "$imgfile" status=none
    fi
done

##############################################################################
# Data disk set images — FAT12 image + file copy
#
# Each package series (a, ap, d, x, etc.) spans one or more disks. For each
# disk we create a FAT12 image and populate it from 00index.txt. The size of
# the files to be copied is checked against the usable FAT12 capacity before
# building the image so any overflows are caught early.
##############################################################################

echo
echo "--- Data disk set images ---"

for series in $SERIES_ORDER; do
    count="${SERIES_COUNT[$series]}"
    diskno=1
    while [ "$diskno" -le "$count" ]; do
        disk="${series}${diskno}"
        srcdir="$SLAKWARE_DIR/$disk"
        imgfile="$OUT_DIR/slakware/${disk}.img"

        # Some series disks may not exist in all mirror snapshots — skip them
        if [ ! -d "$srcdir" ]; then
            echo "  WARNING: $srcdir not found, skipping"
            diskno=$((diskno + 1))
            continue
        fi

        echo "  $srcdir -> $imgfile"

        # Sanity check: sum only the files that will actually be copied
        # (those listed in 00index.txt) and compare against usable FAT12 space.
        # FAT12 on 1.44MB uses ~8KB for FAT tables and the root directory.
        used=$(awk '{print $1}' "$srcdir/00index.txt" | xargs -I{} du -sb "$srcdir/{}" 2>/dev/null | awk '{sum+=$1} END{print sum+0}')
        avail=$((FLOPPY_BYTES - 8192))
        if [ "$used" -gt "$avail" ]; then
            echo "  WARNING: $srcdir is ${used} bytes, may not fit on 1.44MB image!"
        fi

        make_fat_image "$imgfile" "$srcdir"

        diskno=$((diskno + 1))
    done
done

##############################################################################

echo
echo "Done. Images written to: $OUT_DIR"
echo
