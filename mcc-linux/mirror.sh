#!/bin/bash

set -e

# INDEX_URL — base URL of the Slackware mirror index. All available release
# directories are listed here as href links in the HTML index page.
INDEX_URL="https://www.ibiblio.org/pub/historic-linux/distributions/MCC-1.0/1.0"

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
    --reject-regex "/(usr|slackpro|slakpro2|slakpro3|link2cd|slaktest)(/|$)" \
    --directory-prefix="mcc/" \
    --progress=bar \
    --show-progress \
    "https://www.ibiblio.org/pub/historic-linux/distributions/MCC-1.0/1.0/"
