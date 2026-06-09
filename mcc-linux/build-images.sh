#!/bin/bash
# build-images.sh
#
# Creates GoTek-compatible .img files from the MCC-1.0 boot, root, and package files.
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
# MCC-1.0/packages/ contains .tgz and .tar.gz package archives. Each package
# is written as a raw tar stream directly to its own floppy image — no
# filesystem, no extraction. On the target machine:
#   tar xvf /dev/fd0    (or wherever the GoTek presents the floppy)
# reads the tar stream off the device and extracts the package archive into
# the current directory.
#
# Output:
#   images/bootroot/<basename>.img   — boot and root disk images
#   images/packages/<basename>.img   — one floppy per package, raw tar stream
#
# -----------------------------------------------------------------------------
# Requirements
# -----------------------------------------------------------------------------
#   dd        — writes raw images and creates zero fills (coreutils, always present)
#   gunzip    — decompresses .gz files (gzip package, almost always present)
#   tar       — creates raw tar streams for package floppies
#
# Usage: bash build-images.sh [--force]
#   --force   overwrite existing .img files; without this flag existing images
#             are skipped with a warning
# -----------------------------------------------------------------------------

set -e

# SCRIPT_DIR — absolute path to the directory containing this script.
# Used to locate the images/ directory regardless of where the script is called from.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# IMAGES_DIR — directory containing the source boot/root .gz files.
IMAGES_DIR="$SCRIPT_DIR/MCC-1.0/images"

# PKG_DIR — directory containing the package .tgz / .tar.gz archives.
PKG_DIR="$SCRIPT_DIR/MCC-1.0/packages"

# EXTRA_PKG_DIR — directory containing extra package archives.
EXTRA_PKG_DIR="$SCRIPT_DIR/MCC-1.0/extra_packages"

# BOOTROOT_OUT — output directory for boot and root disk images.
BOOTROOT_OUT="$SCRIPT_DIR/images/bootroot"

# PKG_OUT — output directory for package floppy images (raw tar streams).
PKG_OUT="$SCRIPT_DIR/images/packages"

# EXTRA_PKG_OUT — output directory for extra package floppy images.
EXTRA_PKG_OUT="$SCRIPT_DIR/images/extra_packages"

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
#   gunzip  — decompresses the boot/root source .gz files
#   tar     — creates raw tar streams for package floppy images
##############################################################################
check_deps() {
    local missing=0
    echo "checking for dependencies"
    for cmd in dd gunzip tar; do
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
echo "=========================================="
echo

check_deps

# Create output directories if they don't exist
mkdir -p "$BOOTROOT_OUT" "$PKG_OUT" "$EXTRA_PKG_OUT"

##############################################################################
# Boot and root disk images
#
# Decompress each .gz in MCC-1.0/images/ and write it as a raw sector image.
# The source images are 1.2MB floppy geometry (1,228,800 bytes); they are
# padded with zeros to reach the full 1.44MB GoTek size (1,474,560 bytes).
##############################################################################

echo "--- Boot and root disk images ---"
echo " Source: $IMAGES_DIR"
echo " Output: $BOOTROOT_OUT"
echo

# Verify source images directory exists before iterating
if [ ! -d "$IMAGES_DIR" ]; then
    echo "ERROR: images directory not found: $IMAGES_DIR"
    exit 1
fi

found=0
for f in "$IMAGES_DIR"/*.gz; do
    [ -f "$f" ] || continue
    found=1

    # base — filename without the .gz extension, used to name the output
    base=$(basename "$f" .gz)

    # imgfile — destination .img path in the bootroot output directory
    imgfile="$BOOTROOT_OUT/${base}.img"

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
fi

##############################################################################
# Package floppy images — raw tar stream, no filesystem
#
# Each .tgz / .tar.gz in MCC-1.0/packages/ gets its own floppy image. The
# package file is written into the image as a raw tar archive — no FAT12
# filesystem, just tar blocks starting at sector 0. On the target machine:
#
#   tar xvf /dev/fd0
#
# reads the tar stream directly off the GoTek floppy and extracts the package
# archive (.tgz file) into the current directory. The package can then be
# installed with a second tar xvzf pass.
#
# Each image is padded with zeros to the full 1.44MB GoTek size after the tar
# stream ends. The tar end-of-archive blocks (two 512-byte zero blocks) are
# written by tar itself; the remaining floppy space is zeros from padding.
#
# Variables:
#   f        — full path to each source package file
#   pkgname  — package name with all extensions stripped (bison, gcca, etc.)
#   imgfile  — destination .img path under PKG_OUT
#   size     — byte count of image after tar write, checked against FLOPPY_BYTES
##############################################################################

echo
echo "--- Package floppy images ---"
echo " Source: $PKG_DIR"
echo " Output: $PKG_OUT"
echo

if [ ! -d "$PKG_DIR" ]; then
    echo "ERROR: packages directory not found: $PKG_DIR"
    exit 1
fi

found=0
for f in "$PKG_DIR"/*.tgz "$PKG_DIR"/*.tar.gz; do
    [ -f "$f" ] || continue
    found=1

    # pkgname — strip all extensions (.tgz or .tar.gz) to get a clean name.
    pkgname=$(basename "$f")
    pkgname="${pkgname%.tgz}"
    pkgname="${pkgname%.tar.gz}"

    # imgfile — one .img per package in the packages output directory
    imgfile="$PKG_OUT/${pkgname}.img"

    if [ -f "$imgfile" ] && [ "$FORCE" -eq 0 ]; then
        echo "  SKIP: $imgfile already exists (use --force to overwrite)"
        continue
    fi

    echo "  $f -> $imgfile"

    # Write the package as a raw tar stream starting at sector 0 of the image.
    # tar cf - writes to stdout; dd writes that stream into the image file with
    # 512-byte blocks matching floppy sector size. conv=sync zero-pads the
    # final block so the image ends on a sector boundary.
    # -C changes to the package directory so the archive member is just the
    # filename with no leading path components — on extraction the .tgz lands
    # in whatever directory the user runs tar from.
    tar cf - -C "$PKG_DIR" "$(basename "$f")" | dd of="$imgfile" bs=512 conv=sync status=none

    # Pad to the full 1.44MB GoTek size. The tar stream is much smaller than
    # a floppy; the remaining space is filled with zeros so the GoTek sees a
    # complete 1.44MB image and doesn't reject it.
    size=$(stat -c%s "$imgfile")
    if [ "$size" -lt "$FLOPPY_BYTES" ]; then
        dd if=/dev/zero bs=1 count=$((FLOPPY_BYTES - size)) >> "$imgfile" status=none
        echo "    padded from $size to $FLOPPY_BYTES bytes"
    fi

    echo "    done ($(stat -c%s "$imgfile") bytes)"
done

if [ "$found" -eq 0 ]; then
    echo "  no package files found in $PKG_DIR"
fi

##############################################################################
# Extra package floppy images — raw tar stream, no filesystem
#
# Same approach as the packages section above. Each .tgz in extra_packages/
# gets its own floppy image written as a raw tar stream for use with:
#
#   tar xvf /dev/fd0
#
# Files larger than FLOPPY_BYTES cannot fit on a single floppy and are
# skipped with a warning. emacsxtr.tgz (2.3MB) is the known case here.
##############################################################################

echo
echo "--- Extra package floppy images ---"
echo " Source: $EXTRA_PKG_DIR"
echo " Output: $EXTRA_PKG_OUT"
echo

if [ ! -d "$EXTRA_PKG_DIR" ]; then
    echo "ERROR: extra_packages directory not found: $EXTRA_PKG_DIR"
    exit 1
fi

found=0
for f in "$EXTRA_PKG_DIR"/*.tgz "$EXTRA_PKG_DIR"/*.tar.gz; do
    [ -f "$f" ] || continue
    found=1

    pkgname=$(basename "$f")
    pkgname="${pkgname%.tgz}"
    pkgname="${pkgname%.tar.gz}"

    imgfile="$EXTRA_PKG_OUT/${pkgname}.img"

    # Skip files that are too large to fit on a single floppy. tar overhead
    # adds 512 bytes of header plus 1024 bytes of end-of-archive blocks; if
    # the file itself already exceeds FLOPPY_BYTES there is no chance it fits.
    filesize=$(stat -c%s "$f")
    if [ "$filesize" -ge "$FLOPPY_BYTES" ]; then
        echo "  SKIP: $(basename "$f") ($filesize bytes) exceeds floppy capacity ($FLOPPY_BYTES bytes)"
        continue
    fi

    if [ -f "$imgfile" ] && [ "$FORCE" -eq 0 ]; then
        echo "  SKIP: $imgfile already exists (use --force to overwrite)"
        continue
    fi

    echo "  $f -> $imgfile"

    tar cf - -C "$EXTRA_PKG_DIR" "$(basename "$f")" | dd of="$imgfile" bs=512 conv=sync status=none

    size=$(stat -c%s "$imgfile")
    if [ "$size" -lt "$FLOPPY_BYTES" ]; then
        dd if=/dev/zero bs=1 count=$((FLOPPY_BYTES - size)) >> "$imgfile" status=none
        echo "    padded from $size to $FLOPPY_BYTES bytes"
    fi

    echo "    done ($(stat -c%s "$imgfile") bytes)"
done

if [ "$found" -eq 0 ]; then
    echo "  no package files found in $EXTRA_PKG_DIR"
fi

echo
echo "Done."
