# This is a Slackware Installation Tagfile.
#
# This one comes from disk: X1 (XFree-86 2.1 series)
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
x_8514: SKP
x_mach32: SKP
x_mach8: SKP
x_mono: SKP
x_s3: SKP
x_svga: ADD
x_vga16: SKP
xf_bin: ADD
xf_cfg: ADD
xfnt: ADD
xfnt75: ADD
fnt100_1: SKP
fnt100_2: SKP
speedo: SKP
fntbig1: SKP
fntbig2: SKP
xf_lib: ADD
xman1: ADD
xpm: ADD
xf_doc: SKP
xlock: ADD
xconfig: SKP
fvwmicns: SKP
xinclude: ADD
config86: SKP
