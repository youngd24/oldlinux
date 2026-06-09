# MCC Interim Linux

MCC Interim Linux 1.0+ was assembled by Owen LeBlanc at the Manchester
Computing Centre (University of Manchester) around 1993. It's one of the early
Linux distributions from that window before Slackware became the thing everyone
used — same era as SLS, predates the Slackware dominance of 1994/1995.

The installation approach will be familiar if you've dealt with early Slackware:
boot disk, root disk, then swap floppies to install packages. No package manager.
Packages go on with `tar xvf /dev/fd0`, one floppy at a time.

---

## Directory Layout

```
mcc-linux/
├── README.md                  this file
├── build-images.sh            builds .img files from the MCC-1.0 tree
├── copy-to-usb.sh             copies built images into the USB key tree
├── mirror.sh                  mirror script (if re-downloading is needed)
│
├── MCC-1.0/                   the distribution tree as-archived
│   ├── MCC.README             original release notes from Owen LeBlanc
│   ├── Bugs+Warnings          known issues and change log from the release
│   ├── images/                compressed boot and root disk images (.gz)
│   ├── packages/              recommended packages (.tgz)
│   ├── extra_packages/        optional packages (.tgz)
│   ├── extra_kernels/         alternate kernel builds for specific hardware
│   ├── sources/               source archives for everything in packages/
│   ├── documentation/         release documentation in tex, dvi, and ps
│   └── contributions/         third-party packages accompanying the release
│
└── images/                    generated .img files, ready for GoTek
    ├── bootroot/              boot and root disk images
    └── packages/              one floppy image per package (raw tar stream)
    └── extra_packages/        one floppy image per extra package
```

The `images/` output tree is then copied to `../usbkeys/oldlinux/mcc-1.0/`
by `copy-to-usb.sh`.

---

## Boot and Root Disks

The `MCC-1.0/images/` directory has three compressed disk images:

| File | Description |
|---|---|
| `cdrmboot.gz` | Boot kernel with CD-ROM driver support compiled in |
| `nocdboot.gz` | Boot kernel without CD-ROM — works on most hardware, start here |
| `root.gz` | Root disk — installer environment (shell, fdisk, mkfs, setup) |

These are 1.2MB floppy images (2400 sectors) compressed with gzip.
`build-images.sh` decompresses them and pads them to the full 1.44MB GoTek
size (1,474,560 bytes).

**Boot process:**

1. Load `nocdboot.img` (or `cdrmboot.img` if you have a CD-ROM drive)
2. When prompted, swap to `root.img`
3. The installer runs from the root disk — partition, format, and set up the
   base system from there
4. Once the base system is set up, install packages from the floppy images
   one at a time

---

## Packages

### packages/

The recommended set. Install these as part of a standard setup.

| Package | Contents |
|---|---|
| `baseman` | Base manual pages |
| `bison` | GNU bison parser generator |
| `e2fsp05a` | ext2 filesystem utilities |
| `flex` | GNU flex lexical analyzer |
| `gawk` | GNU awk |
| `gcca` | GCC compiler (part 1) |
| `gccb` | GCC compiler (part 2) |
| `gdb` | GNU debugger |
| `gpp` | G++ C++ compiler |
| `groff` | GNU groff document formatting |
| `info` | GNU info pages |
| `linux` | Linux kernel source |
| `progman` | Programmer's manual |

GCC is split across `gcca` and `gccb` — both are needed for a working compiler.

### extra_packages/

Optional add-ons. Install what you need.

| Package | Contents |
|---|---|
| `elisp` | GNU Emacs Lisp reference manual |
| `emacs` | GNU Emacs editor |
| `emacsxtr` | Emacs extras — **too large for a floppy (2.3MB), skipped** |
| `extrainf` | Additional info pages |
| `extralib` | Extra libraries |
| `gprof` | GNU profiler |
| `lp` | Line printer utilities |
| `mail` | Mail handling utilities |
| `manpages` | Additional man pages |
| `patches` | Miscellaneous patches |
| `timezone` | Timezone data |
| `words` | Word lists |

`emacsxtr.tgz` is 2.3MB and won't fit on a single 1.44MB floppy. The image
builder skips it with a warning. If you need it on the target machine, another
transfer method will be required (CD-ROM, network, etc.).

---

## What's Not Built Into Images

The `sources/`, `documentation/`, `contributions/`, and `extra_kernels/`
directories are in the tree but no floppy images are built from them. Sources
are there for reference and rebuilding if needed; contributions are third-party
packages that weren't part of the core distribution. The extra kernels
(`ipide`, `wd`) are alternate builds for specific hardware configurations —
if the standard kernels don't work on your hardware, those are worth looking at.

---

## Scripts

### `build-images.sh` — Build GoTek images

Reads the MCC-1.0 tree and produces `.img` files in `images/`.

```bash
# Build all images
bash build-images.sh

# Rebuild from scratch (removes existing output first)
bash build-images.sh --force
```

**What it produces:**

- `images/bootroot/` — three images: `cdrmboot.img`, `nocdboot.img`, `root.img`.
  Raw decompressed floppy images, zero-padded to 1.44MB.

- `images/packages/` — one image per package. Each is a raw tar stream written
  directly to a 1.44MB floppy image. No filesystem — the GoTek presents it as
  a raw device and the target machine reads it with `tar xvf /dev/fd0`.

- `images/extra_packages/` — same treatment as packages/. `emacsxtr` is skipped
  because it's too large to fit.

No `sudo` required — unlike the Slackware image builder, nothing here needs
loop-mounting.

---

### `copy-to-usb.sh` — Copy images into the USB key tree

Copies the three `images/` subdirectories to `../usbkeys/oldlinux/mcc-1.0/`.

```bash
# Copy everything
bash copy-to-usb.sh

# Overwrite an existing destination
bash copy-to-usb.sh --force
```

---

## End-to-End Workflow

```
1.  Build the GoTek images
    bash build-images.sh

2.  Copy to USB key tree
    bash copy-to-usb.sh

3.  Sync ../usbkeys/ to a physical USB stick (rsync, cp, or your tool of choice)
```

After step 2, the image files are at:

```
../usbkeys/oldlinux/mcc-1.0/
    bootroot/       cdrmboot.img  nocdboot.img  root.img
    packages/       baseman.img   gcca.img  gccb.img  ...
    extra_packages/ emacs.img  mail.img  ...
```

Load the USB stick into the GoTek, navigate to the appropriate image, and boot.
