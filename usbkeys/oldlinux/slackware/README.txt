Slackware GoTek Images

GoTek-compatible 1.44MB floppy disk images for installing early Slackware
Linux releases on period hardware. Each subdirectory contains the complete
disk set for one release.

----------------------------------------

Versions

Directory    Release
slackware-1.1.2/    Slackware 1.1.2 (1994)
slackware-2.0.0/    Slackware 2.0.0 (1994)

----------------------------------------

Directory Structure

Each version directory contains:

bootdisks/      kernel images — start here, boot from one of these
rootdisks/      ramdisk images — loaded by the installer after the kernel boots (2.x only)
slakware/       package disks — fed to the installer during package selection

----------------------------------------

Installation Order

1. Boot disk — select a kernel image from bootdisks/ and boot from it.
   Common choices are boot_bare.img (IDE/standard) or boot_scsiboot.img (SCSI).
2. Root disk — when prompted, switch to a rootdisks/ image to load the
   installer environment. *(2.x only — 1.x boots directly into the installer.)*
3. Package disks — the installer will prompt for each disk in turn. The
   disk name shown on screen (e.g. A1, AP2) corresponds directly to the
   image filename (a1.img, ap2.img) in slakware/.

----------------------------------------

Package Series

Series    Contents
a    Base system
ap    Application programs
d    Development tools (GCC, make, etc.)
e    GNU Emacs
f    FAQs and documentation
i    Info pages
iv    InterViews UI toolkit
n    Networking (TCP/IP, mail, FTP)
oi    Object Interfaces (1.x only)
oop    Object-oriented programming tools
q    Kernel source (2.x only)
t    TeX / LaTeX
tcl    Tcl/Tk
u    System utilities
x    X Window System
xap    X applications
xd    X development libraries
xv    XV image viewer and X utilities
y    BSD games
