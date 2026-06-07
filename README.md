# OLDLINUX

After recently completing the build of a 486DX2/66 machine I was reminded that this was nearly the identical build to one of my first "real" Linux machines, somewhere around 1993/1994. As I am prepping for VCFMW 2026 I thought, you know, why not get an install of some Linux types of that era on the machine and bring it along. This repo is the result of doing that.

A couple modern amenities I do enjoy using on old machines, a GoTek drive and a IDE CF or SD card. Floppy drives always seem to be in a state of barely working or on the way to breaking, a GoTek is all but an essential addition. I also like the ability to swap between OS's on the machines so I use an IDE to CF card adapter, an IDE to SATA or some form of that with an SD card.

I remembered using a few different eras of Linux then, the first was when it was REALLY raw, the 0.12 days. It's all but an alpha release, essentially unusable for anything real, but it shows what hit the public in January 1992.

The other one I used, a lot, was Slackware, probably like many of you that remember this period. I did use SLS and MCC for a bit but for now I'm going to get early Slackware as an option.

## Requirements

I'm currently working on this on a Windows 11 machine under WSL2, everything I've tested with runs there. I have an Ubuntu box sitting here to try these out on at some point, I suspect most things will work the same but YMMV if you're native Linux. Have not tried it on any of my Macs, might work but I sort of doubt it and have no real desire to test or mod for that one.

Yea, Windows 11, I know, it came on this NUC and what can I say, I hate reloading OS's.

## Slackware

See `slackware/README.md` for the full details on the scripts and how everything works. What follows is a summary of each version and where things stand.

### 1.01

This does not appear to exist in a complete form in any mirror I've been able to find.

### 1.1.2

Released in 1994, this is one of the earliest Slackware releases still available in a reasonably complete form. The tree structure is noticeably different from later releases — there's no `slakware/` subdirectory, all the package series directories (`a1/`, `ap1/`, etc.) sit right in the root of the distribution tree.

The bigger difference for installation purposes: there's no separate root disk. Later Slackware had you boot from a boot disk, then swap to a root disk to load the installer environment. In 1.1.2 it's all one disk — boot it and you're straight into the installer. One less thing to juggle.

The distribution has a few series that didn't survive to 2.x — notably `oi` (Object Interfaces, the InterViews widget library) across 3 disks. No `q` series either, kernel source wasn't distributed separately in this one.

Full install with X is around 30 disks. Base system without X is considerably less.

Boot disk options worth knowing about:

- **bareboot** — standard IDE, no SCSI. Start here for most hardware.
- **scsiboot** — mixed IDE and SCSI system.
- **onlyscsi** — SCSI only, no IDE.
- **color144** — like bareboot but with color terminal support.
- **tty144** — plain TTY, no color, for simpler terminals.

### 2.0.0

This is the first one I started with and is the most complete in here. Step 1 was finding a copy of the original installation diskettes, fortunately they're available still. I put together a script to mirror the files down to work on.

If you remember Slackware, you'll likely remember the hell that was all of the floppy disks you had to make in order to install it. The full distribution is something like 50+ of them, a decent usable system with X is around 30. The script `make-gotek-images.sh` creates the image files from the mirror — it's doing what the `MAKEFLOP` script included with Slackware did at the time, just automated.

Unlike 1.1.2, this version splits the boot process across two disks. You boot from a boot disk first, then swap to a root disk when prompted to load the installer. The boot disk is just the kernel; the root disk is the installer environment (shell, setup scripts, fdisk, etc.).

Boot disk options worth knowing about:

- **bare** — standard IDE, no SCSI. Start here for most hardware.
- **scsi** — generic SCSI support.
- **modern** — for newer IDE controllers that bare doesn't handle.
- **net** — network-enabled kernel.
- **scsinet** — SCSI plus networking.

Root disk options:

- **color144** — color terminal installer. Use this one.
- **tty144** — plain TTY, no color.

At the end you're left with a bunch of img files that you copy to a USB key and feed into your GoTek. The `copy-to-usb.sh` script handles that part.

### 2.1

Mirroring is in progress. The tree structure looks similar to 2.0.0 but there are likely differences that need to be sorted out once the mirror is complete before the image builder will handle it cleanly.
