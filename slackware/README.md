# Slackware GoTek Image Builder

This directory contains local mirrors of early Slackware Linux releases and
the tooling to convert them into GoTek-compatible 1.44MB floppy disk images
for bare-metal installation on period hardware.

---

## What is a GoTek?

A GoTek is a USB-based floppy drive emulator. It mounts in a standard 3.5"
drive bay and reads `.img` files from a USB stick, presenting each one to the
host machine as a physical floppy disk. The BIOS and installer see a normal
1.44MB floppy — the GoTek just serves the image file rather than spinning a
real disk.

Each `.img` file must be exactly **1,474,560 bytes** (2880 sectors × 512
bytes) to match standard 1.44MB DD floppy geometry. Images that are the wrong
size are rejected by the BIOS or silently misread.

---

## Prerequisites

All scripts run on Linux (tested on WSL2 / Ubuntu). Required tools:

| Tool | Package | Purpose |
|---|---|---|
| `wget` | `wget` | Mirroring from mirrors.slackware.com |
| `mkfs.fat` | `dosfstools` | Formatting FAT12 floppy images |
| `dd` | `coreutils` | Writing raw kernel/ramdisk images |
| `cp` | `coreutils` | Populating FAT12 images |
| `sudo mount` | — | Loop-mounting images during build |
| `gunzip` | `gzip` | Decompressing kernel/ramdisk images |

Install missing tools on Debian/Ubuntu/WSL2:

```bash
sudo apt install wget dosfstools
```

---

## Directory Layout

```
slackware/
├── README.md                  this file
├── mirror.sh                  mirrors a Slackware release from the internet
├── make-gotek-images.sh       builds .img files from a mirrored tree
├── copy-to-usb.sh             copies built images into the USB key tree
│
├── slackware-1.1.2/           mirrored release tree (1.x flat layout)
├── slackware-2.0.0/           mirrored release tree (2.0.x subdirectory layout)
├── slackware-2.1/             mirrored release tree (2.1.x subdirectory layout)
│
└── gotek/                     generated .img files, one subdir per version
    ├── slackware-1.1.2/
    │   ├── bootdisks/         raw kernel images
    │   └── slakware/          FAT12 package disk images
    ├── slackware-2.0.0/
    │   ├── bootdisks/         raw kernel images
    │   ├── rootdisks/         raw ramdisk images
    │   └── slakware/          FAT12 package disk images
    └── slackware-2.1/
        ├── bootdisks/         raw kernel images
        ├── rootdisks/         raw ramdisk images (uncompressed source)
        └── slakware/          FAT12 package disk images
```

The `gotek/` output tree is then copied to `../usbkeys/oldlinux/slackware/`
by `copy-to-usb.sh`.

---

## Mirrored Versions

| Version | Year | Layout | Status |
|---|---|---|---|
| 1.1.2 | 1994 | 1.x | complete |
| 2.0.0 | 1994 | 2.0.x | complete |
| 2.1 | 1995 | 2.1.x | complete |

### Tree layout differences

**1.x layout** (`slackware-1.1.2`):
- Boot images in `bootdisk/1_44meg/*.gz`
- No separate rootdisk directory
- Package series directories (`a1/`, `ap1/`, etc.) live directly in the tree root

**2.0.x layout** (`slackware-2.0.0`):
- Boot images in `bootdsks.144/*.gz`
- Root ramdisk images in `rootdsks.144/*.gz` (gzipped)
- Package series directories under `slakware/`, each with `00index.txt`

**2.1.x layout** (`slackware-2.1`):
- Boot images in `bootdsks.144/*.gz` (same as 2.0.x)
- Root images in `rootdsks.144/` as raw uncompressed files — already exactly 1,474,560 bytes, no gunzip needed
- Package series directories under `slakware/`, no `00index.txt` — all files in each directory are copied

`make-gotek-images.sh` detects the layout automatically. The primary key is
presence of `bootdsks.144/` (2.x) vs `bootdisk/1_44meg/` (1.x). Within 2.x,
it sub-detects by checking whether `rootdsks.144/` holds `.gz` files (2.0.x)
or raw uncompressed images (2.1.x).

### Version notes

**slackware-2.1**: The `q2` disk has a file list referencing CD-ROM driver
files (`cdu31a.tgz`, `sbpcd.tgz`, `sony535.tgz`, etc.) that are not present
in the mirror. The image builder skips them with warnings and continues — this
is expected behavior and the resulting images are otherwise complete. The
distribution is significantly larger than 2.0.0; see the Package Series
Reference table for per-series disk counts.

---

## Package Series Reference

Each Slackware release is divided into named series, each spanning one or more
floppy disks. The disk name is the series letter(s) followed by a number
(e.g. `a1`, `ap2`, `x3`).

| Series | Description | 1.1.2 | 2.0.0 | 2.1 |
|---|---|---|---|---|
| `a` | Base system — core binaries, libraries, filesystem utilities | 3 | 3 | 4 |
| `ap` | Application programs — text editors, man pages, misc tools | 4 | 4 | 5 |
| `d` | Development — GCC, make, debuggers, headers | 6 | 6 | 7 |
| `e` | GNU Emacs | 5 | 5 | 5 |
| `f` | FAQs, HOWTOs, documentation | 1 | 1 | 1 |
| `i` | Info pages | 3 | 2 | 2 |
| `iv` | InterViews — object-oriented C++ UI toolkit | 2 | 2 | 1 |
| `n` | Networking — TCP/IP stack, mail, FTP, NFS | 3 | 3 | 4 |
| `oi` | Object Interfaces — InterViews-based widget library | 3 | — | — |
| `oop` | Object-oriented programming tools | 1 | 1 | 1 |
| `q` | Kernel source and patches | — | 3 | 5 |
| `t` | TeX / LaTeX typesetting system | 5 | 5 | 10 |
| `tcl` | Tcl/Tk scripting and GUI toolkit | 2 | 2 | 2 |
| `u` | System utilities (includes kernel image in 1.x) | 2 | 1 | — |
| `x` | X Window System (XFree86) | 5 | 8 | 13 |
| `xap` | X applications — common GUI programs | 2 | 3 | 3 |
| `xd` | X development — headers and libraries for building X apps | 3 | 3 | 3 |
| `xv` | XV image viewer and related X utilities | 2 | 2 | 3 |
| `y` | BSD games | 1 | 1 | 1 |

---

## Scripts

### `mirror.sh` — Mirror a release from the internet

Downloads a complete Slackware release from `mirrors.slackware.com` into a
local directory. Skips checksum sidecar files (`.md5`, `.sha256`, etc.) that
are not needed for the disk images.

```bash
# Interactive version selection
bash mirror.sh

# Specific version — bare number or full name both work
bash mirror.sh 2.0.0
bash mirror.sh slackware-2.0.0

# Specific version to a custom destination
bash mirror.sh 1.1.2 ./my-slackware-1.1.2
```

Output lands in `./slackware-<version>/` by default (relative to wherever
the script is run from).

---

### `make-gotek-images.sh` — Build GoTek images from a mirrored tree

Reads a mirrored Slackware tree and produces `.img` files in `gotek/<version>/`.
Auto-detects the tree layout (1.x vs 2.x) from the directory structure.

```bash
# Build images for a specific version
bash make-gotek-images.sh slackware-2.0.0
bash make-gotek-images.sh slackware-1.1.2

# Rebuild from scratch (removes existing output first)
bash make-gotek-images.sh slackware-2.0.0 --force
```

**What it produces:**

- `gotek/<version>/bootdisks/boot_<name>.img` — one image per kernel variant
  (e.g. `boot_bare.img`, `boot_scsiboot.img`). Raw kernel images, no filesystem.
- `gotek/<version>/rootdisks/root_<name>.img` — one image per ramdisk variant
  (2.x only). Raw ramdisk images, no filesystem.
- `gotek/<version>/slakware/<disk>.img` — one FAT12 image per package disk
  (e.g. `a1.img`, `ap2.img`, `x3.img`). Populated from `00index.txt` so only
  the original disk contents are included, not mirror sidecar files.

**How it works:**

Boot and root disk images are decompressed with `gunzip` and written directly
with `dd` (no filesystem — the BIOS reads them as raw sectors). They are then
zero-padded to the full 1.44MB size if necessary.

Package disk images are created as blank FAT12 images using `mkfs.fat`, then
loop-mounted so `cp` can write the package files into them. Only files listed
in the disk's `00index.txt` are copied; `.md5`, `.sha256`, `YMTRANS.TBL`, and
other mirror artefacts are excluded.

Disk counts per series are discovered automatically from the tree — no
hardcoded counts means the script handles any version without modification.

**Requires `sudo`** for the `mount`/`umount` calls used when populating FAT12
images. Only those two operations run as root.

---

### `copy-to-usb.sh` — Copy images into the USB key tree

Copies built image directories from `gotek/<version>/` into the USB key tree
at `../usbkeys/oldlinux/slackware/<version>/`.

```bash
# Copy all versions found in gotek/
bash copy-to-usb.sh

# Copy a specific version only
bash copy-to-usb.sh slackware-2.0.0

# Overwrite an existing destination
bash copy-to-usb.sh slackware-2.0.0 --force
```

By default, versions that already exist at the destination are skipped with a
warning. Use `--force` to replace them. Lists available versions if a requested
version is not found in `gotek/`.

---

## End-to-End Workflow

```
1.  Mirror a release
    bash mirror.sh 2.0.0

2.  Build GoTek images
    bash make-gotek-images.sh slackware-2.0.0

3.  Copy to USB key tree
    bash copy-to-usb.sh slackware-2.0.0

4.  Sync ../usbkeys/ to a physical USB stick (rsync, cp, or your tool of choice)
```

After step 3, the image files are at:

```
../usbkeys/oldlinux/slackware/slackware-2.0.0/
    bootdisks/
    rootdisks/
    slakware/
```

Load the USB stick into the GoTek, navigate to the appropriate image, and
boot the target machine.
