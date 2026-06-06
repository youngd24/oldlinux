CC=cc
CFLAGS=-s -O -N -Wall -Wno-parentheses

all:		smount unwo

smount:		smount.c
		$(CC) $(CFLAGS) -o smount smount.c

unwo:		unwo.c
		$(CC) $(CFLAGS) -o unwo unwo.c

spotless:
		rm -f smount unwo
