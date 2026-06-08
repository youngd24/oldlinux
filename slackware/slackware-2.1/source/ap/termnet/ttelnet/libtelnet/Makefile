CFLAGS = -O2 -fomit-frame-pointer -m486 '-DISSUE_FILE="/etc/issue.net"' \
	-include /usr/include/bsd/bsd.h -I /usr/include/bsd \
	-include /usr/include/termnet.h -DTERMCAP -DUSE_TERMIO \
        -DKLUDGELINEMODE -DDIAGNOSTICS -DAUTHENTICATE

OBJS =	auth.o enc_des.o encrypt.o genget.o getent.o \
	kerberos.o kerberos5.o misc.o

libtelnet.a: $(OBJS)
	ar rcv libtelnet.a $(OBJS)
	ranlib libtelnet.a

install: libtelnet.a
	echo "Nothing to install for libtelnet, just a libary."

clean:
	rm -f *.o libtelnet.a

