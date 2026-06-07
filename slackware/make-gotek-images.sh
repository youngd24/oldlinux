#!/bin/bash
# make-gotek-images.sh
#
# Creates GoTek-compatible .img files from a local Slackware mirror tree.
# Supports 1.x and 2.x release layouts, auto-detected from directory structure.
#
# -----------------------------------------------------------------------------
# Background
# -----------------------------------------------------------------------------
# A GoTek drive is a USB-based floppy emulator. It reads .img files from a USB
# stick and presents them to the host machine as physical floppy disks. The
# BIOS and Slackware installer see a normal 1.44MB floppy; the GoTek just
# serves the image file instead of spinning a real disk.
#
# Each .img file must be exactly 1,474,560 bytes (2880 sectors x 512 bytes),
# matching the geometry of a standard 1.44MB DD floppy. Images that are too
# short are rejected by the BIOS; images that are too large don't exist in
# the real world and confuse emulators.
#
# -----------------------------------------------------------------------------
# Output structure (written to gotek/<version>/ alongside this script)
# -----------------------------------------------------------------------------
#   bootdisks/   raw kernel images — dd'd directly, no filesystem
#   rootdisks/   raw ramdisk images — same treatment (2.x only)
#   slakware/    FAT12 data disks — one per package series disk (a1, ap2, x3…)
#
# -----------------------------------------------------------------------------
# Layout detection
# -----------------------------------------------------------------------------
# The script inspects the target directory to decide which version style it is:
#
#   2.x layout (e.g. slackware-2.0.0):
#     <target>/bootdsks.144/    — gzipped raw kernel images
#     <target>/rootdsks.144/    — gzipped raw ramdisk images
#     <target>/slakware/<disk>/ — package series disk directories
#
#   1.x layout (e.g. slackware-1.1.2):
#     <target>/bootdisk/1_44meg/ — gzipped raw kernel images
#     <target>/<disk>/           — package series disk directories in tree root
#     (no separate rootdisk directory)
#
# Detection key: presence of bootdsks.144/ (2.x) vs bootdisk/1_44meg/ (1.x).
#
# Disk counts per series are discovered automatically by walking the tree, so
# no hardcoded counts are needed and future versions are handled without edits.
#
# -----------------------------------------------------------------------------
# Requirements
# -----------------------------------------------------------------------------
#   dosfstools  (mkfs.fat)   — sudo apt install dosfstools
#   coreutils   (dd, cp)     — present by default
#   sudo mount               — needed to loop-mount FAT images during build
#
# Usage: bash make-gotek-images.sh <slackware-dir> [--force]
#   <slackware-dir>  path to the Slackware version directory to process
#                    e.g. slackware-2.0.0  or  slackware-1.1.2
#   --force          delete and recreate the output directory if it exists;
#                    without this flag the script exits if output exists,
#                    protecting against accidental overwrites of a prior run

set -e

# SCRIPT_DIR — absolute path to the directory containing this script.
# Used to locate the gotek/ output directory regardless of where the script
# is invoked from. ${BASH_SOURCE[0]} is the script file itself; dirname gives
# its parent; cd + pwd resolves any symlinks to a canonical absolute path.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

##############################################################################
# Argument parsing
##############################################################################

# FORCE — when 1, the output directory is removed and rebuilt from scratch.
# Defaults to 0 (safe mode: exit if output already exists).
FORCE=0

# TARGET_DIR — the Slackware version directory supplied by the caller.
# Set to empty here; populated by the argument loop below.
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

# Resolve TARGET_DIR to an absolute path so all subsequent paths derived from
# it are unambiguous, then extract the directory name as the version label.
TARGET_DIR="$( cd "$TARGET_DIR" && pwd )"

# VERSION — the bare directory name (e.g. "slackware-2.0.0"). Used in the
# output path and the banner so it's clear which release was processed.
VERSION="$(basename "$TARGET_DIR")"

##############################################################################
# Layout detection
#
# The following variables are set here and used throughout the rest of the
# script. They are NOT set at the top of the file because their values depend
# on which layout is detected.
#
#   LAYOUT       — human-readable label printed in the banner ("1.x" or "2.x")
#   BOOT_DIR     — directory containing gzipped raw kernel (.gz) images
#   ROOT_DIR     — directory containing gzipped raw ramdisk (.gz) images;
#                  empty string on 1.x where no separate rootdisk exists
#   SLAKWARE_DIR — parent directory of the per-disk package series dirs
#                  (e.g. a1/, ap2/); equals TARGET_DIR on 1.x since the series
#                  dirs live directly in the tree root
##############################################################################

if [ -d "$TARGET_DIR/bootdsks.144" ]; then
    LAYOUT="2.x"
    BOOT_DIR="$TARGET_DIR/bootdsks.144"
    ROOT_DIR="$TARGET_DIR/rootdsks.144"
    SLAKWARE_DIR="$TARGET_DIR/slakware"
elif [ -d "$TARGET_DIR/bootdisk/1_44meg" ]; then
    LAYOUT="1.x"
    BOOT_DIR="$TARGET_DIR/bootdisk/1_44meg"
    ROOT_DIR=""                  # no separate rootdisk directory in 1.x
    SLAKWARE_DIR="$TARGET_DIR"  # series dirs (a1/, ap1/…) live in the tree root
else
    echo "ERROR: Cannot detect Slackware layout in $TARGET_DIR."
    echo "  Expected bootdsks.144/ (2.x) or bootdisk/1_44meg/ (1.x)."
    exit 1
fi

# OUT_DIR — root of the output tree for this run. All generated .img files
# are placed under subdirectories of this path. Sits inside gotek/<version>/
# alongside this script so all GoTek images for all versions are co-located.
OUT_DIR="$SCRIPT_DIR/gotek/$VERSION"

# SERIES_ORDER — space-separated list of package series names in the order
# they should be processed. This covers all series known across 1.x and 2.x;
# any series whose numbered directories don't exist in the target tree are
# silently skipped, so the same list works for both layouts.
# Disk counts within each series are discovered dynamically (see data disk
# section below), so adding a new version with a different count needs no edits.
SERIES_ORDER="a ap d e f i iv n oi oop q t tcl u x xap xd xv y"

# Floppy geometry constants — these never change for a 1.44MB DD floppy.
# FLOPPY_SECTORS — total 512-byte sectors on a 1.44MB floppy (80 tracks *
#                  2 heads * 18 sectors/track = 2880).
# FLOPPY_BYTES   — exact byte size every output .img must be (2880 * 512).
#                  Images smaller than this are zero-padded; anything larger
#                  would mean the source data doesn't fit on a real floppy.
FLOPPY_SECTORS=2880
FLOPPY_BYTES=1474560

##############################################################################
# check_deps
#
# Verifies that all external tools the script needs are installed. Runs before
# any output directories are created so a missing tool fails early with a clear
# message rather than partway through the build.
#
# Tools checked:
#   mkfs.fat  — formats the blank .img files as FAT12 (from dosfstools package)
#   dd        — writes raw kernel/ramdisk images and creates zero-filled files
#   cp        — copies package files into mounted FAT images
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
# check_dirs
#
# Verifies that the source directories the script will read from actually exist
# before any .img files are created. Builds a check list from the layout
# variables set during detection:
#   - BOOT_DIR is always checked
#   - ROOT_DIR is checked only on 2.x (it is empty on 1.x)
#   - SLAKWARE_DIR is checked only on 2.x; on 1.x it equals TARGET_DIR which
#     was already validated when we cd'd into it above
##############################################################################
check_dirs() {
    local ok=1
    echo "checking for needed directories"

    # Build the list of directories to validate based on detected layout
    local check_list=("$BOOT_DIR")
    [ -n "$ROOT_DIR" ] && check_list+=("$ROOT_DIR")
    [ "$SLAKWARE_DIR" != "$TARGET_DIR" ] && check_list+=("$SLAKWARE_DIR")

    for d in "${check_list[@]}"; do
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
# Creates a single 1.44MB FAT12 floppy image and populates it with the files
# listed in srcdir/00index.txt.
#
# Arguments:
#   imgfile — path to the .img file to create (must not already exist)
#   srcdir  — source disk directory containing 00index.txt and the payload files
#
# Why FAT12:
#   A real 1.44MB floppy is always formatted FAT12. The Slackware installer
#   expects DOS-formatted data disks and will refuse to read them otherwise.
#   mkfs.fat automatically chooses FAT12 for this geometry.
#
# Why 00index.txt:
#   The mirror contains sidecar files (.md5, .sha256, .metalink, YMTRANS.TBL,
#   etc.) that are not part of the original disk set and would waste space on
#   a 1.44MB image. 00index.txt lists only the files that belong on the disk,
#   one per line with the format: <filename>  <size-in-bytes>
#   The awk extracts just the filename (field 1) and we copy only those files.
#
# Why sudo mount:
#   Writing files into a FAT image requires mounting it via loopback. Loop
#   mounts require root on Linux even when the image is owned by the user.
#   The mount and umount calls are the only privileged operations in this script.
##############################################################################
make_fat_image() {
    local imgfile="$1"
    local srcdir="$2"

    # Create a zero-filled file of exactly FLOPPY_BYTES. Using bs=512 and
    # count=FLOPPY_SECTORS rather than bs=FLOPPY_BYTES and count=1 matches
    # how dd handles floppy geometry and produces the same result.
    dd if=/dev/zero of="$imgfile" bs=512 count=$FLOPPY_SECTORS status=none

    # Format as FAT12. -F 12 forces FAT12 (mkfs.fat would choose it anyway
    # for this size, but being explicit avoids any ambiguity). -n "" sets an
    # empty volume label to match an unformatted original floppy.
    mkfs.fat -F 12 -n "" "$imgfile" &>/dev/null

    # Loop-mount the blank image into a temporary directory so we can write
    # files into it with normal cp. mktemp -d creates a unique temp dir that
    # is cleaned up with rmdir after umount.
    local mnt
    mnt=$(mktemp -d)
    sudo mount -o loop "$imgfile" "$mnt"

    # Copy only the files named in 00index.txt. awk prints field 1 (filename),
    # read -r passes each name to cp. Directories or subdirectory entries in
    # 00index.txt (marked with trailing /) are silently skipped by cp -f since
    # they would fail; the index on these disks only lists regular files.
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
echo " Layout: $LAYOUT"
echo "=========================================="
echo

# If OUT_DIR already exists, either abort (default) or wipe it (--force).
# This prevents silently mixing images from two different runs.
if [ -d "$OUT_DIR" ]; then
    if [ "$FORCE" -eq 1 ]; then
        echo "Output directory $OUT_DIR already exists, removing it."
        rm -rf "$OUT_DIR"
    else
        echo "ERROR: Output directory $OUT_DIR already exists. Use --force to remove it."
        exit 1
    fi
fi

# Create the output subdirectories up front so every section can write into
# them without checking. rootdisks/ is only created on 2.x since 1.x has no
# separate rootdisk directory and the output tree should reflect that.
if [ -n "$ROOT_DIR" ]; then
    mkdir -p "$OUT_DIR" "$OUT_DIR/bootdisks" "$OUT_DIR/rootdisks" "$OUT_DIR/slakware"
else
    mkdir -p "$OUT_DIR" "$OUT_DIR/bootdisks" "$OUT_DIR/slakware"
fi

check_deps
check_dirs

##############################################################################
# Boot disk images — raw dd, no filesystem
#
# The boot disk is the first floppy inserted during installation. It contains
# a raw kernel image that the BIOS loads directly into memory — there is no
# filesystem; the BIOS reads sectors off the disk as if it were a tape.
#
# Process: gunzip the .gz file and pipe it through dd with conv=sync, which
# zero-pads each block to a full sector. If the resulting image is still
# shorter than FLOPPY_BYTES (kernel images are usually much smaller than
# 1.44MB), append zeros to reach the required size. The GoTek rejects images
# that don't match the declared geometry.
#
# Variables:
#   BOOT_DIR  — source directory (set by layout detection above)
#   f         — full path to each .gz file found in BOOT_DIR
#   base      — filename without the .gz extension, used to name the output
#   imgfile   — destination .img path under OUT_DIR/bootdisks/
#   size      — byte count of the image after dd, checked against FLOPPY_BYTES
##############################################################################

echo "--- Boot disk images ---"
for f in "$BOOT_DIR"/*.gz; do
    [ -f "$f" ] || continue          # skip if glob matched nothing
    base=$(basename "$f" .gz)
    imgfile="$OUT_DIR/bootdisks/boot_${base}.img"
    echo "  $f -> $imgfile"
    gunzip -c "$f" | dd of="$imgfile" bs=512 conv=sync status=none
    # Pad to full 1.44MB if the kernel image is smaller than a full floppy
    size=$(stat -c%s "$imgfile")
    if [ "$size" -lt "$FLOPPY_BYTES" ]; then
        dd if=/dev/zero bs=1 count=$((FLOPPY_BYTES - size)) >> "$imgfile" status=none
    fi
done

##############################################################################
# Root disk images — 2.x only, raw dd, no filesystem
#
# After the kernel boots from the boot disk, the installer prompts for the
# root disk. It contains a compressed ramdisk image with the installer
# environment (shell, setup scripts, fdisk, etc.). Like the boot disk it is
# a raw image with no filesystem wrapper — dd reads it sector by sector.
#
# This section is skipped entirely on 1.x layouts where ROOT_DIR is empty,
# because 1.x shipped with a combined boot+root arrangement.
#
# Variables: same pattern as the boot disk section above; imgfile lands in
# OUT_DIR/rootdisks/ with a root_ prefix to distinguish from boot images.
##############################################################################

if [ -n "$ROOT_DIR" ]; then
    echo
    echo "--- Root disk images ---"
    for f in "$ROOT_DIR"/*.gz; do
        [ -f "$f" ] || continue
        base=$(basename "$f" .gz)
        imgfile="$OUT_DIR/rootdisks/root_${base}.img"
        echo "  $f -> $imgfile"
        gunzip -c "$f" | dd of="$imgfile" bs=512 conv=sync status=none
        # Pad to full 1.44MB if the ramdisk image is smaller than a full floppy
        size=$(stat -c%s "$imgfile")
        if [ "$size" -lt "$FLOPPY_BYTES" ]; then
            dd if=/dev/zero bs=1 count=$((FLOPPY_BYTES - size)) >> "$imgfile" status=none
        fi
    done
fi

##############################################################################
# Data disk set images — FAT12 image + file copy
#
# The package disks are normal DOS-formatted floppies. The installer mounts
# them, reads a tag file to know which packages the user selected, and installs
# .tgz packages from them. Each series (a, ap, d, x, etc.) spans one or more
# numbered disks (a1, a2, a3…); the installer swaps disks as needed.
#
# Disk discovery: rather than hardcoding disk counts, the inner while loop
# increments diskno and tests whether the next directory exists. The loop exits
# at the first gap, which is fine for complete mirrors. Any series from
# SERIES_ORDER that has no disk 1 in SLAKWARE_DIR is skipped silently.
#
# Size check: before building the image, we sum the byte sizes of the files
# that will actually be copied (those listed in 00index.txt) and compare
# against the usable FAT12 space. FAT12 on 1.44MB reserves ~8KB for its own
# tables and root directory, leaving avail = FLOPPY_BYTES - 8192 for data.
#
# Variables:
#   series    — current series name from SERIES_ORDER (e.g. "ap")
#   diskno    — current disk number within the series, starts at 1
#   disk      — series + diskno concatenated (e.g. "ap2")
#   srcdir    — full path to the source disk directory in SLAKWARE_DIR
#   imgfile   — destination .img path under OUT_DIR/slakware/
#   used      — total bytes of files listed in 00index.txt for this disk
#   avail     — usable capacity of a FAT12 1.44MB image in bytes
##############################################################################

echo
echo "--- Data disk set images ---"

for series in $SERIES_ORDER; do
    diskno=1
    while [ -d "$SLAKWARE_DIR/${series}${diskno}" ]; do
        disk="${series}${diskno}"
        srcdir="$SLAKWARE_DIR/$disk"
        imgfile="$OUT_DIR/slakware/${disk}.img"

        echo "  $srcdir -> $imgfile"

        # Sum bytes of only the files that will be copied, then warn if they
        # exceed the usable FAT12 capacity of a 1.44MB image
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
