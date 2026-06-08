#
# Makefile for nn release 6.4
#
# Specify your favourite compiler, preprocessor, and compiler flags:
#
# Some alternatives for CPP might be /lib/cpp and $(CC) -P
# Common values for CFLAGS are '-O -s' or '-g'
#

CC =		gcc
CPP =		$(CC) -E
CFLAGS =	-O2 
LDFLAGS =	-s
MAKE =		make

#
# Before compiling, read the instructions in the file INSTALLATION!
# -----------------------------------------------------------------
#
#	make all	compile programs
#	make clean	remove all make'd files from source directory
#
# no changes are needed below this line
#

SHELL = /bin/sh

all: ymakefile
	$(MAKE) $(MFLAGS) -f ymakefile all

touch: ymakefile
	$(MAKE) -f ymakefile -t all

dbg: ymakefile
	$(MAKE) $(MFLAGS) -f ymakefile nn1

nn: ymakefile
	$(MAKE) $(MFLAGS) -f ymakefile nn

master: ymakefile
	$(MAKE) $(MFLAGS) -f ymakefile master

lint: ymakefile
	$(MAKE) -f ymakefile lint

client: ymakefile
	$(MAKE) $(MFLAGS) -f ymakefile client

ymakefile: Makefile xmakefile config.h
	cp xmakefile MF.c
	$(CPP) -DCOMPILER="$(CC)" -DPREPROC="$(CPP)" \
	       -DLDEBUG="$(LDFLAGS)" \
	       -DCDEBUG="$(CFLAGS)" -Iconf MF.c | \
	sed -e '1,/MAKE WILL CUT HERE/d' \
	    -e '/^#/d' \
	    -e '/^[ \f	]$$/d' \
	    -e '/^[ \/]*[*]/d' | \
	sed -n -e '/^..*$$/p' > ymakefile
	rm -f MF.c

#
# clean up
#	Will remove object and executeable files.
#

clean:	ymakefile
	make -f ymakefile clean
	rm -f *.o *~ ymakefile

#
# distribution
#

distrib: man/nn.1.D
	[ -d DIST ] || mkdir DIST
	rm DIST/Part.*
	makekit -m -k30 -s55000 -nDIST/Part.

tar: man/nn.1.D
	chmod +x FILES
	rm -f /tmp/nn64tar*
	tar cf /tmp/nn64tar `FILES`
	cd /tmp && compress nn64tar

split: tar
	rm -f /tmp/nn64z*
	cd /tmp && bsplit -b40000 -pnn64z -v < nn64tar.Z

man/nn.1.D: man/nn.1
	sh SPLITNN1
	
