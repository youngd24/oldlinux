# OLDLINUX

After recently completing the build of a 486DX2/66 machine I was reminded that this was nearly the identical build to one of my first "real" Linux machines, somewhere around 1993/1994. As I am prepping for VCFMW 2026 I thought, you know, why not get an install of some Linux types of that era on the machine and bring it along. This repo is the result of doing that.

A couple modern amenities I do enjoy using on old machines, a GoTek drive and a IDE CF or SD card. Floppy drives always seem to be in a state of barely working or on the way to breaking, a GoTek is all but an essential addition. I also like the ability to swap between OS's on the machines so I use an IDE to CF card adapter, an IDE to SATA or some form of that with an SD card.

I remembered using a few different eras of Linux then, the first was when it was REALLY raw, the 0.12 days. It's all but an alpha release, essentially unusable for anything real, but it shows what hit the public in January 1992.

The other one I used, a lot, was Slackware, probably like many of you that remember this period. I did use SLS and MCC for a bit but for now I'm going to get early Slackware as an option.

## Requirements

I'm currently working on this on a Windows 11 machine under WSL2, everything I've tested with runs there. I have an Ubuntu box sitting here to try these out on at some point, I suspect most things will work the same but YMMV if you're native Linux. Have not tried it on any of my Macs, might work but I sort of doubt it and have no real desire to test or mod for that one.

Yea, Windows 11, I know, it came on this NUC and what can I say, I hate reloading OS's.

## Slackware

### 1.01

This does not appear to exist in a complete form in any mirror I've been able to find.

### 1.1.2

This one is a work in progress still, more to come as I get around to it.

### 2.0.0

This is the first one I started with and is the most functional in here. Step 1 was finding a copy of the original installation diskettes, fortunately they're available still. I put together a script to mirror the files down to work on.

If you remember Slackware, you'll likely remember the hell that was all of the floppy disks you had to make in order to install it. The full distribution is something like 50+ of them, a decent usable system with X is around 30. Step one: convert them to image files that can be used with a GoTek. The script, make-gotek-images.sh, creates an empty floppy and uses a DOS copy utility to copy the files into it. It's doing what the MAKEFLOP sciprt included in Slackware did at the time.

At the end you're left with a bunch of img files in the img_output directory that you can copy to a USB key and feed into your GoTek. Most of it's being built into a USB image I'm working towards, at some point you can just grab that and go.