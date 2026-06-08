# Linux Kernel 0.12

This directory contains everything needed to boot Linux 0.12 on a 486 using a
GoTek floppy emulator. It's an assembled collection of sources, binaries, and
pre-built floppy images pulled together from multiple places.

## What is Linux 0.12?

Linux 0.12 was released by Linus Torvalds on January 5, 1992. It's the last
kernel in the 0.1x series before things started moving toward 0.95 and
eventually 1.0. At this point Linux was still essentially a one-person hobby
project — POSIX-compatible enough to run GNU tools, technically impressive for
what it was, but not particularly useful for anything real. No networking in
the kernel, no sound, just a process scheduler, filesystem (Minix format),
and enough system calls to keep bash and gcc happy.

It runs on 386 and 486 hardware only. This is about as raw as a usable Linux
gets.

## Sources

Files here came from a few places:

- **Princeton oldlinux mirror** — `https://mirror.math.princeton.edu/pub/oldlinux/Linux.old/`
  The most complete archive of early Linux artifacts I've found. Kernel sources,
  binaries, and utilities from the 0.1x era.

- **Personal mirror** — `https://github.com/youngd24/mirror-oldlinux`
  A partial mirror of the Princeton archive for the specific files used in
  this build.

---

## Directory Layout

```
kernel-0.12/
├── boot-0.12-144.img      GoTek boot disk — Linux 0.12 kernel, padded to 1.44MB
├── boot-0.11-144.img      GoTek boot disk — Linux 0.11 kernel, padded to 1.44MB
├── bootimage-0.12-fd      raw 0.12 kernel image, unpadded (source artifact)
├── bootimage-0.11-fd      raw 0.11 kernel image, unpadded (source artifact)
├── hdboot-0.11-144.img    GoTek HD boot disk — boots 0.11 off hard disk via Shoelace
├── root-011-144.img       GoTek root disk — 0.11 root filesystem
├── rootimage-0.11         FAT12 root filesystem image (0.11 variant)
├── blank144.img           blank 1.44MB floppy image for making new disks
│
├── gccbin.img             GCC compiler and toolchain binaries
├── libs.img               C library (libc-0.12) and include headers
├── devtools.img           development tools — as86, bison, flex, etc.
├── srcs.img               source archives
├── kernsrc012.img         Linux 0.12 kernel source
├── shoelace.img           Shoelace bootloader
├── as86.img               as86 assembler (needed to compile the kernel boot sector)
├── kill.img               kill utility
├── ps012.img              ps utility (0.12-compatible)
├── usr_bin_01.img         /usr/bin utilities
├── util-linux-1.6-src.img util-linux 1.6 source
│
├── mkdsk                  utility script — builds a floppy image from a directory
│
├── bins/                  binary archives (.tar.Z) from the Princeton mirror
├── libs/                  library archives — libc, curses, headers
└── srcs/                  source archives — kernel, system utils, tools
```

---

## Floppy Images

All `.img` files are 1,474,560 bytes (standard 1.44MB floppy geometry) and
can be loaded directly into a GoTek. See `../usbkeys/` for where they land on
the USB key.

### Boot process

Linux 0.12 uses a two-floppy boot just like early Slackware — a boot disk and
a root disk. The boot disk contains the kernel image; after loading it the
kernel looks for a root filesystem on a second floppy (or hard disk).

**For a floppy-only setup:**

1. Load `boot-0.12-144.img` — this is the kernel. The BIOS loads the boot
   sector, which decompresses and runs the kernel.
2. When prompted, swap to `root-011-144.img` — the root filesystem. The kernel
   mounts this as `/` and hands off to init.

**For booting off hard disk:**

Once you have the system installed to a hard disk partition, Shoelace takes
over from the floppies. `hdboot-0.11-144.img` is used to install Shoelace and
set up the HD boot configuration.

### 0.11 vs 0.12

Both kernel versions are here. 0.11 is useful as a build environment — the
0.12 kernel was commonly compiled by booting 0.11 (which had a more complete
userland) and compiling 0.12 on top of it. The 0.11 images are the ones I
used to get the initial environment working.

---

## Application Disks

These are FAT12 floppy images containing the binaries and sources needed to
actually use the system once it's booted.

| Image | Contents |
|---|---|
| `gccbin.img` | GCC compiler, linker, and toolchain |
| `libs.img` | libc-0.12 and include headers |
| `devtools.img` | as86, bison, flex, and other dev tools |
| `srcs.img` | source archives for utilities |
| `kernsrc012.img` | Linux 0.12 kernel source (krn012.tar) |
| `shoelace.img` | Shoelace — the hard disk bootloader for this era |
| `as86.img` | as86 assembler — required to build the kernel boot sector |
| `ps012.img` | ps command compiled for 0.12 |
| `kill.img` | kill command |
| `usr_bin_01.img` | basic /usr/bin utilities |
| `util-linux-1.6-src.img` | util-linux 1.6 source (mount, fdisk, etc.) |

---

## Source and Binary Archives

The `bins/`, `libs/`, and `srcs/` directories hold the raw archives that the
disk images above were built from. They're here so the images can be rebuilt
or modified if needed. All are in the original `.tar.Z` (compress) format
from the early Linux era.

**bins/** — pre-compiled binaries:
- `gccbin.tar.Z` — GCC toolchain
- `bash-1.12.tar.Z` — bash shell
- `as86.tar.Z` — as86 assembler
- `utils.tar.Z` — general system utilities
- `diffbin.tar.Z`, `fileutil.tar.Z` — diff and file utilities
- `pfdisk.tar.Z` — partition-aware fdisk
- `shoelace.tar.Z` — Shoelace bootloader
- `mkswap` — mkswap binary (not archived, used directly)

**libs/** — libraries and headers:
- `libc-0.12.a.Z` — the C library for Linux 0.12
- `include-0.11.tar.Z` — kernel include headers (0.11)
- `curses.tar.Z` — curses library
- `libsdbm.a` — SDBM database library

**srcs/** — source code:
- `krn012.tar` — Linux 0.12 kernel source
- `system-0.12.tar.Z` — system utilities (init, login, etc.)
- `ps012.tar.Z` — ps source
- `kill.c`, `hostname.c`, `uname.c` — individual utility sources
- `shoelace.tar.Z` — Shoelace bootloader source
- `util-linux-1.6.tar.Z` — util-linux 1.6 source
- `swapon.tar.Z` — swapon/swapoff source

---

## Utilities

**`mkdsk`** — a small shell script that packs a directory into a 1.44MB floppy
image using tar + dd. Used to build the application disk images from the
`bins/`, `libs/`, and `srcs/` directories:

```bash
./mkdsk bins/gccbin.tar.Z gccbin.img
```

**`bins/mkswap`** — the mkswap binary, needed to set up swap space on the
hard disk during installation.
