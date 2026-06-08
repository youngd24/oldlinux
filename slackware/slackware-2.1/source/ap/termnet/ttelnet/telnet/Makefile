CFLAGS = -O2 -fomit-frame-pointer '-DISSUE_FILE="/etc/issue.net"' \
	-include /usr/include/bsd/bsd.h -I /usr/include/bsd \
	-include /usr/include/termnet.h -DTERMCAP -DUSE_TERMIO \
        -DKLUDGELINEMODE -DDIAGNOSTICS -DAUTHENTICATE -I..
LDLIBS = -lbsd -ltermcap -ltelnet -L ../libtelnet -ltermnet
LDFLAGS = -s

telnet: authenc.o commands.o main.o network.o ring.o sys_bsd.o telnet.o \
		terminal.o tn3270.o utilities.o

install: telnet
	install telnet /usr/bin
	install -m644 telnet.1 /usr/man/man1

clean:
	rm -f *.o telnet

