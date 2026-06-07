#!/bin/bash
# mirror.sh
#
# Downloads a complete Slackware release from mirrors.slackware.com into a
# local directory tree, ready to be processed by make-gotek-images.sh.
#
# -----------------------------------------------------------------------------
# What gets downloaded
# -----------------------------------------------------------------------------
# The full release tree is mirrored as-is from the remote server, with a few
# exclusions to keep the local copy lean:
#
#   Excluded files (--reject):
#     index.html*   — wget-generated index pages, not part of the release
#     *.mirrorlist  — mirror redirect files, not needed locally
#     *.meta4       — metalink files used for multi-source downloads
#     *.md5         — checksum sidecars, not needed for image building
#     *.sha1        — checksum sidecars
#     *.sha256      — checksum sidecars
#
#   Excluded directories (--reject-regex):
#     usr       — cruft present in some remote mirrors, not part of the
#                 original release tree
#     slackpro  — Slackware Pro variant directories, not needed
#     slakpro2  — Slackware Pro variant directories, not needed
#     slakpro3  — Slackware Pro variant directories, not needed
#
#     Note: --exclude-directories is not used here because it matches against
#     the full server-side URL path (e.g. /slackware/slackware-2.1/slackpro).
#     A bare name like "slackpro" never matches that full path, so the option
#     silently does nothing. --reject-regex is applied to every URL before
#     wget fetches it, including directory index pages, so it blocks recursion
#     into the directory entirely rather than just rejecting individual files.
#     A post-mirror cleanup pass removes any empty stubs wget may have created
#     before the regex check fires.
#
# -----------------------------------------------------------------------------
# Output
# -----------------------------------------------------------------------------
# Files land in ./slackware-<version>/ by default, relative to wherever the
# script is run from. Pass a second argument to override the destination.
#
# Once complete, pass the output directory to make-gotek-images.sh:
#   bash make-gotek-images.sh slackware-2.0.0
#
# Requires: wget
# WSL2/Ubuntu: sudo apt install wget
#
# Usage: bash mirror.sh [version] [destination_dir]
#   version          release to mirror; omit for interactive selection
#                    accepts bare (2.0.0) or prefixed (slackware-2.0.0)
#   destination_dir  where to write the files; defaults to ./slackware-<version>

set -e

# INDEX_URL — base URL of the Slackware mirror index. All available release
# directories are listed here as href links in the HTML index page.
INDEX_URL="https://mirrors.slackware.com/slackware/"

##############################################################################
# fetch_versions
#
# Fetches the HTML index from INDEX_URL and extracts the list of available
# Slackware distribution directory names.
#
# Filters applied to the raw href list:
#   slackware-iso   — ISO image directories, not release trees
#   slackware-pre   — pre-release directories
#   ^slackware/$    — the bare slackware/ parent directory itself
#   ^slackware"     — malformed or stray href matches
#
# Output: one distribution name per line, sorted by version number (sort -V
# handles the dotted version strings correctly, e.g. 2.9 before 10.0).
##############################################################################
fetch_versions() {
    wget -q -O - "$INDEX_URL" \
        | grep -o 'href="slackware[^"]*/"' \
        | sed 's|href="||; s|/$||; s|"||' \
        | grep -v -e 'slackware-iso' \
                  -e 'slackware-pre' \
                  -e '^slackware/$' \
                  -e '^slackware"' \
        | grep -E '^slackware' \
        | sort -V
}

##############################################################################
# Version selection
#
# DIST    — full distribution directory name as it appears on the mirror
#           (e.g. "slackware-2.0.0" or "slackware64-15.0")
# VERSION — the version portion stripped of the slackware/slackware64 prefix
#           (e.g. "2.0.0" or "15.0"); used for display only
#
# If $1 is provided, DIST is derived from it directly. Both bare version
# numbers (2.0.0) and fully prefixed names (slackware-2.0.0) are accepted.
# If $1 is omitted, the available versions are fetched and presented as a
# numbered list for interactive selection.
##############################################################################

if [[ -n "$1" ]]; then
    # Accept bare (2.0.1) or prefixed (slackware-2.0.1) or (slackware64-15.0)
    case "$1" in
        slackware*) DIST="$1" ;;
        *)          DIST="slackware-$1" ;;
    esac
    VERSION="${DIST#slackware-}"
    VERSION="${VERSION#slackware64-}"
else
    echo "Fetching available versions from mirrors.slackware.com..."
    mapfile -t VERSIONS < <(fetch_versions)

    if [[ ${#VERSIONS[@]} -eq 0 ]]; then
        echo "ERROR: Could not retrieve version list. Check your network connection." >&2
        exit 1
    fi

    echo
    echo "Available Slackware distributions:"
    for i in "${!VERSIONS[@]}"; do
        printf "  [%2d] %s\n" "$((i+1))" "${VERSIONS[$i]}"
    done
    echo

    # Loop until the user enters a valid number in range
    while true; do
        read -rp "Select a version (1-${#VERSIONS[@]}): " CHOICE
        if [[ "$CHOICE" =~ ^[0-9]+$ ]] && (( CHOICE >= 1 && CHOICE <= ${#VERSIONS[@]} )); then
            DIST="${VERSIONS[$((CHOICE-1))]}"
            VERSION="${DIST}"
            break
        fi
        echo "  Invalid selection, try again."
    done
fi

# DEST_DIR — local directory where the mirrored files will be written.
# Defaults to ./<DIST> (e.g. ./slackware-2.0.0) relative to the current
# working directory. Override by passing a second argument to the script.
DEST_DIR="${2:-./${DIST}}"

# BASE_URL — full URL to the specific release directory on the mirror.
# wget mirrors everything under this path, honoring --no-parent so it won't
# walk back up to the mirror index.
BASE_URL="${INDEX_URL}${DIST}"

echo
echo "=========================================="
echo " ${DIST} full mirror"
echo " Source : $BASE_URL"
echo " Dest   : $DEST_DIR"
echo "=========================================="
echo

mkdir -p "$DEST_DIR"

# Mirror the release tree with the following wget flags:
#
#   --mirror              enables recursive download, timestamping, and
#                         infinite recursion depth (equivalent to -r -N -l inf)
#   --no-host-directories don't create a subdirectory named after the host
#   --cut-dirs=2          strip 2 path components from the URL before writing
#                         locally (/slackware/<dist>/ becomes ./)
#   --no-parent           don't follow links above BASE_URL; prevents wget
#                         from crawling back up to the mirror index
#   --reject              skip files matching these patterns before downloading
#   --reject-regex        skip any URL matching this regex before fetching it;
#                         applied to directory index pages too, which prevents
#                         wget from recursing into the matched directories at all
#   --progress=bar        show a progress bar per file rather than dot output
#   --show-progress       ensure the bar is shown even in non-interactive mode
wget \
    --mirror \
    --no-host-directories \
    --cut-dirs=2 \
    --no-parent \
    --reject "index.html*,*.mirrorlist,*.meta4,*.md5,*.sha1,*.sha256" \
    --reject-regex "/(usr|slackpro|slakpro2|slakpro3)(/|$)" \
    --directory-prefix="$DEST_DIR" \
    --progress=bar \
    --show-progress \
    "$BASE_URL/"

# Remove any excluded directories that wget created as empty stubs. wget
# allocates the local directory entry as soon as it sees the link in the
# parent index page, before the exclusion check prevents recursion into it.
# This cleans up those stubs so the local tree is completely free of them.
EXCLUDE_DIRS=(usr slackpro slakpro2 slakpro3)
for d in "${EXCLUDE_DIRS[@]}"; do
    if [ -d "$DEST_DIR/$d" ]; then
        echo "Removing excluded directory: $DEST_DIR/$d"
        rm -rf "$DEST_DIR/$d"
    fi
done

echo
echo "Done. Files in: $DEST_DIR"
echo
du -sh "$DEST_DIR"
