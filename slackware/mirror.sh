#!/bin/bash
# mirror_slackware.sh
#
# Mirrors a Slackware distribution version from mirrors.slackware.com
#
# Usage: bash mirror_slackware.sh [version] [destination_dir]
#   version defaults to interactive selection from available versions
#   destination_dir defaults to ./slackware-<version>

set -e

INDEX_URL="https://mirrors.slackware.com/slackware/"

# ── helper: fetch available distro dirs from the index ───────────────────────
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

# ── version selection ─────────────────────────────────────────────────────────
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

DEST_DIR="${2:-./${DIST}}"
BASE_URL="${INDEX_URL}${DIST}"

echo
echo "=========================================="
echo " ${DIST} full mirror"
echo " Source : $BASE_URL"
echo " Dest   : $DEST_DIR"
echo "=========================================="
echo

mkdir -p "$DEST_DIR"

wget \
    --mirror \
    --no-host-directories \
    --cut-dirs=2 \
    --no-parent \
    --reject "index.html*,*.mirrorlist,*.meta4,*.md5,*.sha1,*.sha256" \
    --exclude-directories="*/usr,*/slackpro,*/slakpro2,*/slakpro3" \
    --directory-prefix="$DEST_DIR" \
    --progress=bar \
    --show-progress \
    "$BASE_URL/"

echo
echo "Done. Files in: $DEST_DIR"
echo
du -sh "$DEST_DIR"
