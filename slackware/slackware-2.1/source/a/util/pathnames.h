/*
 * Copyright (c) 1989 The Regents of the University of California.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms are permitted
 * provided that the above copyright notice and this paragraph are
 * duplicated in all such forms and that any documentation,
 * advertising materials, and other materials related to such
 * distribution and use acknowledge that the software was developed
 * by the University of California, Berkeley.  The name of the
 * University may not be used to endorse or promote products derived
 * from this software without specific prior written permission.
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
 *
 *	@(#)pathnames.h	5.3 (Berkeley) 5/9/89
 *
 * Changed: Sun Nov 21 12:30:54 1993 by faith@cs.unc.edu
 * Changed: Wed Jun 22 20:47:27 1994 by faith@cs.unc.edu, based on changes
 *                                   from poe@daimi.aau.dk
 * Revised: Wed Jun 22 22:50:13 1994 by faith@cs.unc.edu
 */

#ifndef __STDC__
# error "we need an ANSI compiler"
#endif

/* The paths for some of these are wrong in /usr/include/paths.h, but we
   re-define them here. */

#ifdef _PATH_UTMP
#undef _PATH_UTMP
#endif
#ifdef _PATH_WTMP
#undef _PATH_WTMP
#endif
#ifdef _PATH_DEFPATH
#undef _PATH_DEFPATH
#endif
#ifdef _PATH_DEFPATH_ROOT
#undef _PATH_DEFPATH_ROOT
#endif
#ifdef _PATH_LASTLOG
#undef _PATH_LASTLOG
#endif
#ifdef _PATH_MAILDIR
#undef _PATH_MAILDIR
#endif

#ifndef SBINDIR
#define SBINDIR			"/sbin"
#endif

#ifndef USRSBINDIR
#define USRSBINDIR              "/usr/sbin"
#endif

#ifndef LOGDIR
#define LOGDIR                  "/var/adm"
#endif

#ifndef VARPATH
#define VARPATH			"/var"
#endif

#define _PATH_BSHELL    	"/bin/sh"
#define _PATH_CSHELL    	"/bin/csh"
#define UT_NAMESIZE     	8
#define _PATH_TTY       	"/dev/tty"
#define TTYTYPES        	"/etc/ttytype"
#define SECURETTY       	"/etc/securetty"
#define _PATH_UTMP      	"/var/adm/utmp"
#define _PATH_WTMP      	"/var/adm/wtmp"

#define	_PATH_DEFPATH	        "/usr/local/bin:/bin:/usr/bin"
#define	_PATH_DEFPATH_ROOT	"/usr/local/sbin:/usr/sbin:/sbin:/usr/local/bin:/bin:/usr/bin"
#define	_PATH_HUSHLOGIN		".hushlogin"
#define	_PATH_LASTLOG		"/var/adm/lastlog"
#define	_PATH_MAILDIR		"/var/spool/mail"
#define	_PATH_MOTDFILE		"/etc/motd"
#define	_PATH_NOLOGIN		"/etc/nologin"

#define _PATH_LOGIN		"/bin/login"
#define _PATH_INITTAB		"/etc/inittab"
#define _PATH_RC		"/etc/rc"
#define _PATH_REBOOT		"/sbin/reboot"
#define _PATH_SINGLE		"/etc/singleboot"
#define _PATH_SECURE		"/etc/securesingle"
#define _PATH_USERTTY   "/etc/usertty"

#define _PATH_MTAB		"/etc/mtab"
#define _PATH_UMOUNT		"/bin/umount"
#define UMOUNT_ARGS		"umount", "-a"
