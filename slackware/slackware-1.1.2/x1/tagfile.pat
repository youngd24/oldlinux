# This is a Slackware Installation Tagfile.
#           
# This one comes from disk: X1 (XFree-86 2.0 series)
# and a backup copy called "tagfile.org" can be found on the same disk. You
# should never edit the "tagfile.org" copy, only the one called "tagfile". Use
# the "tagfile.org" only if you want to restore original installation defaults
# by copying it over the top of "tagfile".
# 
# It is used to automate software installation. 
# There are two labels that you can use: ADD and SKP.
#
# If the PROMPT option is used during installation, this file will be checked
# to determine the installation default. First, all the lines beginning with
# <package_name>: 
# will be extracted. Then, the last line in the extracted segment will be 
# checked for the flags ADD, REC, OPT and SKP.
#
# If ADD is found, then a priority of [required] will be displayed, and the
# package will be automatically installed. 
#
# If SKP is found, then a priority of [skip] will be displayed, and
# the package will be automatically skipped.
#
# All other packages will be prompted for. There are two optional flags you
# can use to change the package priority level shown when the user is 
# prompted: REC and OPT. If REC is found, the priority shown will be
# [recommended], while if OPT is found, the user sees priority [optional].
#
# If no flags are found for a given package, the user is shown priority
# [unknown], and is prompted for whether the package should be installed.
#
# If you mess this file up beyond recognition, just restore from "tagfile.org"
# 
#
x_8514: An accelerated server for cards using IBM8514 chips.
x_8514: SKP
x_mach32: An accelerated server for cards using Mach32 chips.
x_mach32: SKP
x_mach8: An accelerated server for cards using Mach8 chips.
x_mach8: SKP
x_mono:	A Monochrome server.
x_mono: SKP
x_s3: An accelerated server for cards using S3 chips.
x_s3: SKP
x_svga: A SuperVGA server.
x_svga: ADD
x_vga16: A server for 16 colour graphics modes. (Last one!)
x_vga16: SKP
xf_bin: Basic client binaries required for XFree86 2.0.
xf_bin: ADD
xf_cfg: XDM configuration, chooser, and FVWM.
xf_cfg: ADD
xfonts1: More fonts for X windows. (part one)
xfonts1: ADD
xfonts2: More fonts for X windows. (part two)
xfonts2: ADD
xf_lib: Dynamic libraries, bitmaps and minimal fonts for XFree86 2.0.
xf_lib: ADD
xman1: Man pages for programs that come with XFree86 2.0.
xman1: ADD
xpm: The Xpm shared and static libraries, v. 3.3
xpm: ADD
xf_doc: Documentation and release notes for XFree86 2.0.
xf_doc: ADD
xlock: Screensaver for X.
xlock: ADD
xconfig: A collection of sample Xconfig files
xconfig: SKP
fvwmicns: Color icons for FVWM.
fvwmicns: ADD
