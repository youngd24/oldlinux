CC     = gcc
CFLAGS = -O -include /usr/include/termnet.h
PROG   = fwhois
SOURCE = fwhois.c
STRIP  = strip
LDLIBS = -ltermnet

bsd:
	$(CC) $(CFLAGS) -o $(PROG) $(SOURCE) $(LDLIBS)
	$(STRIP) $(PROG)

clean:
	rm -f core *~ $(PROG)
