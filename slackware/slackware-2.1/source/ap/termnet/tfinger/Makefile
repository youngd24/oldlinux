CFLAGS = -O2 -fomit-frame-pointer -m486 -include /usr/include/bsd/bsd.h \
		-I/usr/include/bsd -include /usr/include/termnet.h
LDFLAGS = -s -v
LDLIBS = -lbsd -ltermnet

finger: finger.o lprint.o net.o sprint.o util.o

install: finger
	install finger /usr/bin
	install -m644 finger.1 /usr/man/man1

clean:
	rm -f *.o finger

