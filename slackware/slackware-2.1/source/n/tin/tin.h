/*
 *  Project   : tin - a Usenet reader
 *  Module    : tin.h
 *  Author    : I.Lea & R.Skrenta
 *  Created   : 01-04-91
 *  Updated   : 22-09-93
 *  Notes     : #include files, #defines & struct's
 *  Copyright : (c) Copyright 1991-93 by Iain Lea & Rich Skrenta
 *              You may  freely  copy or  redistribute  this software,
 *              so  long as there is no profit made from its use, sale
 *              trade or  reproduction.  You may not change this copy-
 *              right notice, and it must be included in any copy made
 */

/*
 * OS specific doda's
 */
 
#include	"config.h"

#include	<stdio.h>
#include	<signal.h>
#include	<errno.h>

#ifdef M_AMIGA
#	include	<stddef.h>
#	include	<time.h>
#else
#	ifdef apollo
#		include </bsd4.3/usr/include/sys/types.h>
#		include </bsd4.3/usr/include/sys/stat.h>
#		include </bsd4.3/usr/include/time.h>
#	else
#		include <sys/types.h>
#		include	<sys/stat.h>
#		ifdef HAVE_SYS_TIME_H
#			include	<sys/time.h>
#		endif
#		ifdef HAVE_SYS_TIMES_H
#			include <sys/times.h>
#		endif
#		ifdef HAVE_TIME_H
#			include	<time.h>
#		endif
#	endif
#	ifdef HAVE_UNISTD_H
#		include	<unistd.h>
#	endif
#	ifdef HAVE_PWD_H
#		include	<pwd.h>
#	endif
#	ifdef HAVE_SYS_PARAM_H
#		include <sys/param.h>
#	endif
#endif

#include	<ctype.h>

#ifdef HAVE_STDLIB_H
#	include	<stdlib.h>
#endif

#ifdef HAVE_STRINGS_H
#	include	<strings.h>
#else
#	include	<string.h>
#endif

#ifdef HAVE_FCNTL_H
#	include	<fcntl.h>
#endif

#ifdef HAVE_SYS_IOCTL_H
#	include <sys/ioctl.h>
#endif

#ifdef HAVE_PROTOTYPES_H
#	include	<prototypes.h>
#endif

#ifdef HAVE_LOCALE_H
#	include <locale.h>
#endif

#ifdef HAVE_SYS_UTSNAME_H
#	include	<sys/utsname.h>
#endif

/*
 * Needed for catching child processes
 */

#ifdef HAVE_SYS_WAIT_H
#	include	<sys/wait.h>
#endif

/*
 * Needed for timeout in user abort of indexing a group (BSD & SYSV variaties)
 */

#ifdef HAVE_SYS_SELECT_H
#	include	<sys/select.h>
#endif

#ifdef HAVE_STROPTS_H
#	include <stropts.h>
#endif

#ifdef HAVE_POLL_H
#	include <poll.h>
#endif

/*
 * Needed for resizing under an xterm
 */

#ifdef HAVE_TERMIOS_H
#	include <termios.h>
#endif

#if defined(SIGWINCH) && !defined(DONT_HAVE_SIGWINCH)
#	if !defined(TIOCGWINSZ) && !defined(TIOCGSIZE)
#		ifdef HAVE_SYS_STREAM_H
#			include <sys/stream.h>
#		endif
#		ifdef HAVE_TERMIO_H
#			include <termio.h>
#		else
#			ifdef HAVE_SYS_PTEM_H
#				include <sys/ptem.h>
#				include <sys/tty.h>
#			endif
#			ifdef HAVE_SYS_PTY_H
#				if !defined(_h_BSDTYPES) && !defined(DONT_HAVE_SYS_BSDTYPES_H)
#					include <sys/bsdtypes.h>
#				endif
#				include <sys/pty.h>
#			endif
#		endif
#	endif
#endif

#ifdef HAVE_CURSES_H
#	include <curses.h>
#endif

/*
 * Directory handling code
 */

#if defined(BSD) && !defined(__386BSD__) && !defined(M_OS2)
#	ifdef sinix
#		include <dir.h>
#	else
#		if defined(__arm) || defined(__osf__)
#			include <dirent.h>
#			define	DIR_BUF	struct dirent
#		else
#			include <sys/dir.h>
#		endif
#	endif
#	ifndef DIR_BUF
#		define	DIR_BUF		struct direct
#	endif
#	define		D_LENGTH	d_namlen
#endif
#ifdef M_AMIGA
#	include	"amiga.h"
#	define		DIR_BUF		struct dirent
#	define		D_LENGTH	d_reclen
#endif
#ifdef M_OS2
#	include	"os_2.h"
#	define		DIR_BUF		struct dirent
#	define		D_LENGTH	d_reclen
#endif
#ifdef M_XENIX
#	include <sys/ndir.h>
#	define		DIR_BUF		struct direct
#	define		D_LENGTH	d_namlen
#endif
#ifndef DIR_BUF
#	include	<dirent.h>
#	define		DIR_BUF		struct dirent
#	define		D_LENGTH	d_reclen
#endif

/*
 * If native OS has'nt defined STDIN_FILENO be a smartass and do it
 */

#if !defined(STDIN_FILENO)
#	define	STDIN_FILENO	0
#endif

/*
 * Setup support for reading from CD-ROM
 */

#ifdef CDROM_ONLY
#	define CDROM_ABLE
#endif
 
#ifdef CDROM_ABLE
#	define XSPOOLDIR
#	define NNTP_ABLE
#	undef NNTP_ONLY
#	undef NNTP_INEWS
#endif

/*
 * Setup support for reading from NNTP
 */
 
#if defined(NNTP_ABLE) || defined(NNTP_ONLY)
#	ifndef NNTP_ABLE
#		define	NNTP_ABLE
#	endif
#	ifndef NNTP_INEWS
#		define	NNTP_INEWS
#	endif
#endif

/*
 *  Time idle after which to check (via STAT) if nntp connection is still ok
 */

#define	NNTP_IDLE_RETRY_SECS	300

/*
 * Index file daemon version of tin. Will create/update index files from cron
 * on NNTP server machine so clients can retreive index file with NNTP XINDEX
 * command from server. Also can be used on machines that just want one copy
 * of all the index files in one place. In this case the normal tin must have
 * access to the index directory (-I dir option) or be setuid news.
 */
 
#ifdef INDEX_DAEMON
#	define	LOCK_FILE "tind.LCK"
#	undef	HAVE_POLL
#	undef	HAVE_SELECT
#	undef	NNTP_ABLE
#	undef	NNTP_ONLY
#	undef	NNTP_INEWS
#endif

/*
 * Specify News spool & control directories
 */
 
#ifndef SPOOLDIR
#	define		SPOOLDIR	"/usr/spool/news"
#endif
#ifndef LIBDIR
#	define		LIBDIR		"/usr/lib/news"
#endif
#ifndef NOVROOTDIR
#	define		NOVROOTDIR	SPOOLDIR
#endif
#ifndef INEWSDIR
#	define		INEWSDIR	LIBDIR
#endif

/*
 * Determine machine configuration for external programs & directories
 */

#ifndef BSD
#	ifndef bcopy
#		define	bcopy(a,b,c)	memcpy(b,a,c)
#		define	bzero(a,b)		memset(a,'\0',b)
#	endif
#endif

#ifdef BSD
#	ifdef DONT_HAVE_MEMCMP
#		define		memcmp(s1, s2, n)	bcmp(s2, s1, n)
#	endif
#	define		strchr(str, ch)		index(str, ch)
#	define		strrchr(str, ch)	rindex(str, ch)
#	define		DEFAULT_SHELL		"/bin/csh"
#	if defined(__386BSD__) || defined(__bsdi__)
#		define	DEFAULT_EDITOR  "/usr/bin/vi"
#		define	DEFAULT_PRINTER "/usr/bin/lpr"
#		define	DEFAULT_MAILER  "/usr/sbin/sendmail"
#		define	DEFAULT_MAILBOX "/var/mail"
#	else
#		define	DEFAULT_EDITOR  "/usr/ucb/vi"
#		define	DEFAULT_PRINTER "/usr/ucb/lpr"
#	endif
#	define		DEFAULT_SUM		"sum"
#	ifdef DGUX
#		define	DEFAULT_MAILBOX	"/usr/mail"
#		define	USE_INVERSE_HACK
#	endif
#	ifdef pyr
#		define	DEFAULT_MAILER	"/usr/.ucbucb/mail"
#	endif
#	ifndef DEFAULT_MAILER
#		define	DEFAULT_MAILER	"/usr/lib/sendmail"
#	endif
#	ifndef DEFAULT_MAILBOX
#		define	DEFAULT_MAILBOX	"/usr/spool/mail"
#	endif
#else
#	if defined(NCR) || defined(atthcx) || defined(PTX) || defined(sinix)
#		define	DEFAULT_MAILER	"/usr/bin/mailx"
#	endif
#	if defined(__hpux) || defined(u3b2)
#		define	DEFAULT_MAILER	"/usr/lib/sendmail"
#	endif
#	ifdef linux
#		define	DEFAULT_MAILBOX	"/usr/spool/mail"
#		define	DEFAULT_MAILER	"/usr/bin/sendmail"
#		define	DEFAULT_PRINTER	"/usr/bin/lpr"
#	endif
#	ifdef M_AMIGA
#		define	DEFAULT_EDITOR		"c:ed"
#		define	DEFAULT_MAILBOX		"uumail:"
#		define	DEFAULT_MAILER		"uucp:c/sendmail <%s -f %s"
#		define	DEFAULT_POSTER		"uucp:c/postnews %s"
#		define	DEFAULT_PRINTER		"c:copy PIPE: NIL:"
#		define	DEFAULT_SHELL		"c:newshell"	/* Not Yet Implemented */
#		define	DEFAULT_UUDECODE	"uudecode %s"
#		define	DEFAULT_UNSHAR		"unshar %s"
#	endif
#	ifdef M_OS2
#		define	DEFAULT_EDITOR		"epm /m"
#		define	DEFAULT_MAILBOX		"/mail"
#		define	DEFAULT_MAILER		"sendmail -af %s -f %s %s"
#		define	DEFAULT_POSTER		"postnews %s"
#		define	DEFAULT_PRINTER		"lpt1"
#		define	DEFAULT_SHELL		"cmd.exe"
#		define	DEFAULT_UUDECODE	"uudecode %s"
#		define	DEFAULT_UNSHAR		"unshar %s"
#	endif
#	ifdef M_XENIX
#		define	DEFAULT_EDITOR	"/bin/vi"
#		define	DEFAULT_MAILER	"/usr/bin/mail"
#		define	DEFAULT_MAILBOX	"/usr/spool/mail"
#	endif
#	ifdef QNX4
#		define	DEFAULT_EDITOR		"/bin/vedit"
#		define	DEFAULT_MAILER		"/usr/bin/sendmail"
#		define	DEFAULT_MAILBOX		"/usr/spool/mail"
#	endif
#	ifdef RS6000
#		define	DEFAULT_MAILER	"/usr/lib/sendmail"
#		define	DEFAULT_PRINTER	"/bin/lp"
#	endif
#	ifdef SCO_UNIX
#		define	HAVE_MMDF_MAILER
#	endif
#	ifdef sinix
#		define	DEFAULT_PRINTER	"/bin/lpr"
#	endif
#	ifdef sysV68
#		define	DEFAULT_MAILER	"/bin/rmail"
#	endif
#	ifdef UNIXPC
#		define	DEFAULT_MAILER	"/bin/rmail"
#	endif
#	ifndef DEFAULT_SHELL
#		define	DEFAULT_SHELL	"/bin/sh"
#	endif
#	ifndef DEFAULT_EDITOR
#		define	DEFAULT_EDITOR	"/usr/bin/vi"
#	endif
#	ifndef DEFAULT_MAILBOX
#		define	DEFAULT_MAILBOX	"/usr/mail"
#	endif
#	ifndef DEFAULT_MAILER
#		define	DEFAULT_MAILER	"/bin/mail"
#	endif
#	ifndef DEFAULT_PRINTER
#		define	DEFAULT_PRINTER	"/usr/bin/lp"
#	endif
#	define		DEFAULT_SUM		"sum -r"
#endif

#ifdef HAVE_LONG_FILENAMES
#	define		LONG_PATH_PART	"part"
#	define		LONG_PATH_PATCH	"patch"
#else
#	define		LONG_PATH_PART	""
#	define		LONG_PATH_PATCH	"p"
#endif

/*
 * Useful for logging user usage
 */
 
#define		LOG_USER_FILE	".tin_log" 

/*
 * Should active file be reread for new news & if so how often
 */
 
#ifdef DONT_REREAD_ACTIVE_FILE
#	define	REREAD_ACTIVE_FILE_SECS	0
#else
#	ifndef REREAD_ACTIVE_FILE_SECS
#		define	REREAD_ACTIVE_FILE_SECS	600	/* seconds */
#	endif
#endif

/*
 * Initial sizes of internal arrays for small (<4MB) & large memory machines
 */
 
#ifdef SMALL_MEMORY_MACHINE
#	define		DEFAULT_ACTIVE_NUM	1800	
#	define		DEFAULT_ARTICLE_NUM	600	
#	define		DEFAULT_KILL_NUM	10	
#	define		DEFAULT_SAVE_NUM	10	
#	define		DEFAULT_SPOOLDIR_NUM	5	
#	define		DEFAULT_ACTIVE_SIZE_NUM	5	
#else
#	define		DEFAULT_ACTIVE_NUM	1800	
#	define		DEFAULT_ARTICLE_NUM	1200	
#	define		DEFAULT_KILL_NUM	30	
#	define		DEFAULT_SAVE_NUM	30	
#	define		DEFAULT_SPOOLDIR_NUM	10	
#	define		DEFAULT_ACTIVE_SIZE_NUM	10	
#endif

#define		RCDIR			".tin"
#define		RCFILE			"tinrc"
#define		INDEX_MAILDIR		".mailidx"
#define		INDEX_NEWSDIR		".index"
#define		ACTIVE_FILE			"active"
#define		ACTIVE_MAIL		"active.mail"
#define		ACTIVE_SAVE		"active.save"
#define		ACTIVE_TIMES		"active.times"
#define		KILLFILE		"kill"
#define		POSTFILE		"posted"
#define		DEFAULT_MAILDIR		"Mail"
#define		DEFAULT_SAVEDIR		"News"
#define		MAILGROUPS_FILE		"mailgroups"
#define		MOTD_FILE		"motd"
#define		OVERVIEW_FILE		".overview"
#define		OVERVIEW_FMT		"overview.fmt"
#define		SUBSCRIPTIONS_FILE	"subscriptions"

#define		_CONF_FROMHOST		"fromhost"
#define		_CONF_ORGANIZATION	"organization"
#define		_CONF_SERVER		"server"

#ifdef TRUE
#	undef TRUE
#endif
#define		TRUE		1

#ifdef FALSE
#	undef FALSE
#endif
#define		FALSE		0

#ifdef M_AMIGA
#	define	LEN			512
#	define	PATH_LEN		128
#endif
#if defined(M_OS2) || defined(M_UNIX)
#	ifndef MAXPATHLEN
#		define MAXPATHLEN 256
#	endif
#	define	PATH_LEN		MAXPATHLEN
#	define	LEN			1024
#endif
#define		NEWSRC_LINE		8192

#ifdef HAVE_MAIL_HANDLER
#	define	HEADER_LEN		8192
#else
#	define	HEADER_LEN		2048
#endif
#define		MODULO_COUNT_NUM	10
#define		TABLE_SIZE		1409
#define		MAX_PAGES		1000
#define		ctrl(c)			((c) & 0x1F)

#ifndef DEFAULT_COMMENT
#	define		DEFAULT_COMMENT	": "	/* used when by follow-ups & replys */
#endif
#ifndef UNREAD_ART_MARK
#	define		UNREAD_ART_MARK	'+'	/* used to show that an art is unread */
#endif
#ifndef RETURN_ART_MARK
#	define		RETURN_ART_MARK	'-'	/* used to show that an art will return */
#endif
#ifndef HOT_ART_MARK
#	define		HOT_ART_MARK	'*'	/* used to show that an art was auto selected */
#endif
#ifndef READ_ART_MARK
#	define		READ_ART_MARK	' '	/* used to show that an art was not read or seen  */
#endif

#ifdef USE_INVERSE_HACK
#	define		SELECT_MISC_COLS	21
#	define		BLANK_GROUP_COLS	2
#	define		BLANK_PAGE_COLS		2
#else
#	define		SELECT_MISC_COLS	21
#	define		BLANK_GROUP_COLS	0
#	define		BLANK_PAGE_COLS		0
#endif

#define		SCREEN_READ_UNREAD		6		/* position for "  +" / "   " */
#define		INDEX_TOP			2

#ifdef NO_REGEX 
#	define STR_MATCH(s1,s2)	(str_str (s1, s2, strlen (s2)) != 0)
#else		
#	define STR_MATCH(s1,pat)	(wildmat (s1, pat))
#endif

#define IGNORE_ART(i)	((arts[i].thread == ART_EXPIRED) || \
			 (arts[i].killed && kill_level > 0))

/*
 *  News/Mail group types 
 */
 
#define		GROUP_TYPE_MAIL			0
#define		GROUP_TYPE_NEWS			1
#define		GROUP_TYPE_SAVE			2

/*
 *  used by get_arrow_key()
 */

#define		KEYMAP_UNKNOWN			0
#define		KEYMAP_UP			1
#define		KEYMAP_DOWN			2
#define		KEYMAP_LEFT			3
#define		KEYMAP_RIGHT			4
#define		KEYMAP_PAGE_UP			5
#define		KEYMAP_PAGE_DOWN		6
#define		KEYMAP_HOME			7
#define		KEYMAP_END			8
#define		KEYMAP_MOUSE			9

/*
 *  used by feed_articles() & show_mini_help()
 */
 
#define		SELECT_LEVEL			1
#define		SPOOLDIR_LEVEL			2
#define		GROUP_LEVEL			3
#define		THREAD_LEVEL			4
#define		PAGE_LEVEL			5

#define		MINI_HELP_LINES			5

#define		FEED_MAIL			1
#define		FEED_PIPE			2
#define		FEED_PRINT			3
#define		FEED_SAVE			4
#define		FEED_XPOST			5

/*
 *  used in art.c & rcfile.c
 */
 
#define		SORT_BY_NOTHING			0		/* sort types on arts[] array */
#define		SORT_BY_SUBJ_DESCEND		1
#define		SORT_BY_SUBJ_ASCEND		2
#define		SORT_BY_FROM_DESCEND		3
#define		SORT_BY_FROM_ASCEND		4
#define		SORT_BY_DATE_DESCEND		5
#define		SORT_BY_DATE_ASCEND		6

#define		SHOW_FROM_NONE			0
#define		SHOW_FROM_ADDR			1
#define		SHOW_FROM_NAME			2
#define		SHOW_FROM_BOTH			3

/*
 *  used in help.c
 */

#define		HELP_INFO			0
#define		POST_INFO			1

/*
 *  used in save.c
 */

#define		CHECK_ANY_NEWS			0
#define		START_ANY_NEWS			1
#define		MAIL_ANY_NEWS			2
#define		SAVE_ANY_NEWS			3

/*
 *  used in help.c
 */

#define		HEADER_TO			0
#define		HEADER_SUBJECT			1
#define		HEADER_NEWSGROUPS		2

/*
 *  used in page.c & post.c
 */

#define		POSTED_NONE			0
#define		POSTED_REDRAW			1
#define		POSTED_OK			2

/*
 * index_point variable values used throughout many modules
 */
 
#define		GRP_UNINDEXED		-1		/* Stop reading group */
#define		GRP_QUIT			-2		/* Set by 'Q' */
#define		GRP_GOTONEXT		-3		/* Goto another group */
#define		GRP_CONTINUE		-4		/* set in show_page() */
#define		GRP_NOREDRAW		-5		/* Unclear meaning ? */

/*
 *  Assertion verifier
 */

#if !defined(M_OS2)
#	ifdef HAVE_ANSI_ASSERT
#		define	assert(p)	if(! (p)) asfail(__FILE__, __LINE__, #p); else
#	else
#		define	assert(p)	if(! (p)) asfail(__FILE__, __LINE__, "p"); else
#	endif
#endif

#define	ESC	27

#ifdef HAVE_CR_AS_CHAR
#	define		CR		'\r'
#else
#	define		CR		10
#endif

/*
 * return codes for change_rcfile ()
 */

#define		NO_KILLING		0
#define		KILLING			1

/*
 *  art.thread
 */

#define		ART_NORMAL		-1
#define		ART_EXPIRED		-2

/*
 *  art.unread
 */

#define		ART_READ		0
#define		ART_UNREAD		1
#define		ART_WILL_RETURN		2

#define		ART_UNAVAILABLE		-1

/*
 * used by group_t & my_group[]
 */
 
#define		UNSUBSCRIBED	0x01	/* haven't put in my_group[] yet */
#define		SUBSCRIBED	0x02	/* subscribed to */

/*
 * kill_type used in struct kill_t
 */
 
#define KILL_SUBJ	1
#define KILL_FROM	2
#define KILL_BOTH	3

/*
 * used in feed.c & save.c
 */
 
#define POST_PROC_NONE			0
#define POST_PROC_SHAR			1
#define POST_PROC_UUDECODE		2
#define POST_PROC_UUD_LST_ZOO		3
#define POST_PROC_UUD_EXT_ZOO		4
#define POST_PROC_UUD_LST_ZIP		5
#define POST_PROC_UUD_EXT_ZIP		6

/*
 * used in checking article header before posting
 */

#define NGLIMIT	20	/* Max. num. of crossposted groups before warning */
#define MAX_COL	78	/* Max. line length before issuing a warning */

/* 
 * The following macros are used to simplify and speed up the 
 * manipulation of the bitmaps in memory which record which articles 
 * are read or unread in each news group.
 *
 * Data representation:
 *
 * Each bitmap is handled as an array of bytes; the least-significant
 * bit of the 0th byte is the 0th bit; the most significant bit of 
 * the 0th byte is the 7th bit.  Thus, the most-significant bit of the 
 * 128th byte is the 1023rd bit, and in general the mth bit of the nth 
 * byte is considered to be bit (n*8)+m of the map as a whole.  Conversely,
 * the position of bit q in the map is the bit (q & 7) of byte (q >> 3). 
 * A bitmap of b bits will be allocated as ((b+7) >> 3) bytes.  
 * 
 * The routines could be changed to operate on a word-oriented bitmap by 
 * changing the constants used from 8 to 16, 3 to 4, 7 to 15, etc. and 
 * changing the allocate/deallocate routines.
 * 
 * In the newsrc context, a 0 bit represents an article which is read 
 * or expired; a 1 represents an unread article.  The 0th bit corresponds
 * to the minimum article number for this group, and (max-min+7)/8 bytes
 * are allocated to the bitmap.
 * 
 * Constants:
 * 
 * NMAXBIT = number of bits per byte or word;
 * NBITPOS = number of bits in NMAXBIT;
 * NBITSON = byte/word used to set all bits in byte/word to 1;
 * NBITNEG1 = binary negation of 1, used in constructing masks.
 * 
 * Macro naming and use:
 * 
 * The NOFFSET and NBITIDX macro construct the byte and bit indexes in
 * the map, given a bit number.
 * 
 * The NSETxxx macros set a bit or bits to binary 1;
 * the NRESETxxx macros set the same bit or bits to binary 0;
 * the NTEST macro tests a single bit.
 * These are used frequently to access the group bitmap.
 * 
 * NSETBLK and NRESETBLK operate on whole numbers of bytes, and are
 * mainly useful for initializing complete bitmaps to one state or
 * another.  Both use the memset function, which is assumed to be 
 * optimized for the target architecture.  NSETBLK is currently used to 
 * initialize the group bitmap to 1s (unread).
 * 
 * NSETRNG and NRESETRNG operate on ranges of bits, from a low bit number
 * to a high bit number (inclusive), and are especially useful for 
 * efficiently setting a contiguous range of bits to one state or another.  
 * NRESETRNG is currently used on the group bitmap to mark the ranges the 
 * newsrc file says are read or expired.
 * 
 * Their algorithm is this. If the high number is less than the low, then
 * do nothing (error); if both fall within the same byte, construct a
 * single mask expressing the range and AND or OR it into the byte; else:
 * construct a mask for the byte containing the low bit, AND or OR it in; 
 * use memset to fill in the intervening bytes efficiently; then construct 
 * a mask for the byte containing the high bit, and AND or OR this mask
 * in.  Masks are constructed by left-shift of 0xff (to set high-order bits 
 * to 1), negating a left-shift of 0xfe (to set low-order bits to 1), and 
 * the various negations and combinations of the same.  This procedure is 
 * complex, but 1 to 2 orders of magnitude faster than a shift inside a 
 * loop for each bit inside a loop for each individual byte.
 * 
 */
 
#define NMAXBIT		7
#define NBITPOS		3
#define NBITSON		0xff
#define NBITNEG1	0xfe
#define NOFFSET(b)	((b) >> NBITPOS)
#define NBITIDX(b)	((b) & NMAXBIT)

#define	NSET(n,b)	(n[(b) >> NBITPOS] |= 1 << ((b) & NMAXBIT))
#define	NRESET(n,b)	(n[(b) >> NBITPOS] &= ~(1 << ((b) & NMAXBIT)))
#define	NTEST(n,b)	(n[(b) >> NBITPOS] & (1 << ((b) & NMAXBIT)))

#define NSETBLK(n,i)	(memset(n,NBITSON,(size_t)(NOFFSET(i)+1)))
#define NRESETBLK(n,i)	(memset(n,0,(size_t)(NOFFSET(i)+1)))

/* 
 * Following macros (could be made functions) fill in a range of a bit map 
 */
 
#define NSETRNG(n,l,h)	 (\
	( h < l ) ? \
		0 : \
	( NOFFSET(h) == NOFFSET(l) ) ? \
		n[ NOFFSET(l) ] |= ( NBITSON << NBITIDX(l) ) & \
			~ ( NBITNEG1 << NBITIDX(h) ) : \
	( /* else */ \
		n[ NOFFSET(l) ] |= ( NBITSON << NBITIDX(l) ), \
		( (NOFFSET(h)-NOFFSET(l)-1)>0 ) ? \
			(int)memset( &n[NOFFSET(l)+1],NBITSON,(size_t)(NOFFSET(h)-NOFFSET(l)-1) ) : \
			0, \
		n[ NOFFSET(h) ] |= ~ ( NBITNEG1 << NBITIDX(h) ) \
	)	)

#define NRESETRNG(n,l,h) (\
	( h < l ) ? \
		0 : \
	( NOFFSET(h) == NOFFSET(l) ) ? \
		n[ NOFFSET(l) ] &= ( NBITNEG1 << NBITIDX(h) ) | \
			~ ( NBITSON << NBITIDX(l) ) : \
	( /* else */ \
		n[ NOFFSET(l) ] &= ~ ( NBITSON << NBITIDX(l) ), \
		( (NOFFSET(h)-NOFFSET(l)-1)>0 ) ? \
			(int)memset( &n[NOFFSET(l)+1],0,(size_t)(NOFFSET(h)-NOFFSET(l)-1) ) : \
			0, \
		n[ NOFFSET(h) ] &= ( NBITNEG1 << NBITIDX(h) ) \
	)	)

/*
 *  struct t_article - article header
 *
 *  article.artnum:
 *	article number in spool directory for group
 *
 *  article.thread:
 *	-1 initial default
 *	-2 means article has expired (wasn't found in file search
 *	of spool directory for the group)
 *	>=0 points to another arts[] (struct article_t)
 *
 *  article.inthread:
 *	FALSE for the first article in a thread, TRUE for all
 *	following articles in thread
 *
 *  article.unread:
 *	boolean, has this article been read or not
 *
 *  article.killed:
 *	boolean, has this article been killed
 *
 *  article.hot:
 *	boolean, has this article been auto-selected
 *
 *  article.tagged:
 *	count, has this article been tagged for saving (>0) or not (=0)
 *
 *  article.date
 *	date: line used for sorting articles by date order
 *
 *  article.archive:
 *	archive name used in *source* groups
 *
 *  article.part:
 *	part no. of archive
 *
 *  article.patch:
 *	patch no. of archive
 *
 */

struct t_article
{
	long artnum;
	char *subject;		/* Subject: line from mail header */
	char *from;			/* From: line from mail header (address) */
	char *name;			/* From: line from mail header (full name) */
	long date;			/* Date: line from header in seconds */
	char *xref;			/* Xref: cross posted article reference line */
	int lines;			/* Lines: number of lines in article */
	char *archive;		/* Archive-name: line from mail header */
	char *part;			/* part  no. of archive */
	char *patch;		/* patch no. of archive */
	int tagged;			/* 0 = not tagged, >0 = tagged */
	int thread;
	unsigned int inthread:1;/* 0 = thread head, 1 = thread follower */
	unsigned int unread:2;	/* 0 = read, 1 = unread, 2 = will return */
	unsigned int killed:1;	/* 0 = not killed, 1 = killed */
	unsigned int hot:1;		/* 0 = not hot, 1 = hot */
	unsigned int zombie:1;	/* 1 = was alive (unread) before 'X' command */
	unsigned int o_unread:2;/* original value of unread - used in xref */
};

/*
 *  struct attribute_t - configurable attributes on a per group basis
 */

struct t_attribute
{
	char *maildir;				/* mail dir if other than ~/Mail */
	char *savedir;				/* save dir if other than ~/News */
	char *sigfile;				/* sig file if other than ~/.Sig */
	char *organization;			/* organization name */
	char *followup_to;			/* where posts should be redirected */
	char *printer;				/* printer command & parameters */
	unsigned int read_during_session:1;	/* marked TRUE if group entered during session */
	unsigned int auto_save:1;		/* 0=none, 1=save */
	unsigned int batch_save:1;		/* 0=none, 1=save -S/mail -M  */
	unsigned int delete_tmp_files:1;	/* 0=leave, 1=delete */
	unsigned int show_only_unread:1;	/* 0=all, 1=only unread */
	unsigned int thread_arts:1;		/* 0=unthread, 1=thread */
	unsigned int show_author:4;		/* 0=none, 1=name, 2=addr, 3=both */
	unsigned int sort_art_type:4;		/* 0=none, 1=subj descend, 2=subj ascend, 
						   3=from descend, 4=from ascend,
						   5=date descend, 6=date ascend */
	unsigned int post_proc_type:4;		/* 0=none, 1=shar, 2=uudecode, 
				  		   3=uud & list zoo, 4=uud & ext zoo*/
};

/*
 *  struct t_group - newsgroup info from active file
 */

struct t_group 
{
	char *name;			/* newsgroup / mailbox name */
	char *description;		/* text from LIBDIR/newsgroups file */
	char *spooldir;			/* groups spool directory */
	char moderated;			/* state of group moderation */
	long max;			/* max. article number */
	long min;			/* min. article number */
	int type;			/* grouptype - newsgroup / mailbox */
	int next;			/* next active entry in hash chain */
	int my_group;			/* subscribed/unsubscribed to group */
	int unread;			/* unread articles in group */
	long newsrcmax;			/* newsrc max (lastmax) */
	long newsrcmin;			/* newsrc min (lastmin) */
	long newsrcsize;		/* newsrc size (max-min+1) */
	int newsrcupdate;		/* newsrc update */
	char *newsrc;			/* newsrc read/unread (max-min+1+7)/8*/
	struct t_attribute attribute;	/* group specific attributes */ 
#ifdef INDEX_DAEMON
	long last_updated_time;		/* last time group dir was changed */
#endif
};

/*
 *  used in hashstr.c
 */
 
struct t_hashnode 
{
	char *s;				/* the string we're saving */
	struct t_hashnode *next;			/* chain for spillover */
};

/*
 *  used in filter.c (new name for kill.c)
 *
 *  Create 2 filter arrays - global & local. Local will be part of group_t
 *  structure and will have priority over global filter. Should help to
 *  speed kill/selecting within a group. The long value number that is in
 *  ~/.tin/kill will be replaced by group name so that it is more human
 *  readable and that if hash routine is changed it will still work.
 *
 *  Add time period to filter_t struct to allow timed kills & auto-selection
 *  Default kill & select time 30 days. Store as a long and compare when 
 *  loading against present time. If time secs is passed set flag to save
 *  filter file and don't load expired entry. Renamed to filter because of
 *  future directions in adding other retrieval methods to present kill &
 *  hot selection.
 *
 *  Also seperate kill/select screen to allow ^K=kill ^A=auto-select
 */
 
struct t_kill 
{
	unsigned int kill_type:8;
	unsigned int kill_how:8;	/* kill/auto select */
	long kill_group;
	char *kill_subj;
	char *kill_from;
};

struct t_save 
{
	char *subject;
	char *dir;
	char *file;
	char *archive;
	char *part;
	char *patch;
	int index;	
	int saved;	
	int is_mailbox;	
};

struct t_screen
{
	char *col;
};

struct t_posted 
{
	char date[10];
	char group[80];
	char action;
	char subj[120];
};

struct t_art_stat 
{
	int total;	/* total article count */
	int unread;	/* number of unread articles (does not include seen) arts */
	int seen;	/* number of seen articles (ART_WILL_RETURN) */
	int hot_total;	/* total hot count */
	int hot_unread; /* hot and unread */
	int hot_seen;	/* hot and seen */
	char art_mark;	/* mark to use for this thread - not used for groups */
};

/*
 * Used by spooldir command
 */
 
struct t_spooldir
{
	int state;
	char *name;
	char *comment;
};

/*
 * Used for detecting changes in active file size on different news servers
 */
 
struct t_active_size
{
	char *server;
	char *attribute;
};

/* 
 * Time functions. 
 */

typedef struct _TIMEINFO 
{
    time_t	time;
    long	usec;
    long	tzone;
} TIMEINFO;

/*
 * Used for detecting new groups when reading news locally.  It's easy to be 
 * confused by arrays of pointers to pointers, so typedef's are used for the 
 * first level pointers to keep it clearer.
 */

struct t_notify
{
	char name[PATH_LEN];
	int visited;
};

typedef struct t_group *group_p;
typedef struct t_notify *notify_p;

/*
 * Determine signal return type
 */
 
#ifdef HAVE_SIGTYPE_VOID
typedef void t_sigtype;
#endif

#ifdef HAVE_SIGTYPE_INT
typedef int t_sigtype;
#endif

/*
 * Determine qsort compare type
 */
 
#ifdef HAVE_COMPTYPE_VOID
typedef const void t_comptype;
#endif

#ifdef HAVE_COMPTYPE_CHAR
typedef char t_comptype;
#endif

#ifdef M_OS2
#	define	SIGTYPE	int
#	define	_CDECL	_cdecl
#	define	_FAR_	_far16
#	define	SEPDIR	'\\'
#else
#	define	SIGTYPE
#	define	_CDECL
#	define	_FAR_
#	define	SEPDIR	'/'
#endif

#define	EDITOR_FORMAT_OFF	"%E %F"
#define	METAMAIL_CMD	"metamail -e -p -m \"tin\""

#ifdef M_AMIGA
#	define	NEWSGROUPS_FILE		"newsdescrip"
#	define	BUG_REPORT_ADDRESS	"mark@garden.equinox.gen.nz"
#	define	REDIRECT_OUTPUT		"> NIL:"
#	define	ENV_VAR_GROUPS		"TIN_GROUPS"
#	define	ENV_VAR_MAILER		"TIN_MAIL"
#	define	ENV_VAR_POSTER		"TIN_POST"
#	define	ENV_VAR_SHELL		"SHELL"
#	define	EDITOR_FORMAT_ON	"%E %F"
#	define	TMPDIR "T:"
#	ifdef	HAVE_KEY_PREFIX
#		define	KEY_PREFIX	0x9b
#	endif
extern void joinpath (char *result, char *dir, char *file);
#endif
#ifdef M_OS2
#	define	NEWSGROUPS_FILE		"newsgroups"
#	define	BUG_REPORT_ADDRESS	"andreas@scilink.org"
#	define	REDIRECT_OUTPUT		"> NUL"
#	define	ENV_VAR_GROUPS		"TIN_GROUPS"
#	define	ENV_VAR_MAILER		"TIN_MAIL"
#	define	ENV_VAR_POSTER		"TIN_POST"
#	define	ENV_VAR_SHELL		"COMSPEC"
#	define	EDITOR_FORMAT_ON	"%E %F"
extern void joinpath (char *result, char *dir, char *file);
#endif
#ifdef M_UNIX
#	define	NEWSGROUPS_FILE		"newsgroups"
#	define	BUG_REPORT_ADDRESS	"iain.lea@erlm.siemens.de"
#	define	REDIRECT_OUTPUT		"> /dev/null 2>&1"
#	define	ENV_VAR_MAILER		"MAILER"
#	define	ENV_VAR_SHELL		"SHELL"
#	define	EDITOR_FORMAT_ON	"%E +%N %F"
#	define	TMPDIR "/tmp/"
#	ifdef	HAVE_KEY_PREFIX
#		define	KEY_PREFIX	0xff
#	endif
#	define joinpath(result,dir,file)	sprintf (result,"%s/%s", dir, (file) ? file : "")
#endif

#if !defined(S_ISDIR)
#	if defined(M_AMIGA)
#		define st_mode st_attr
#		define S_ISDIR(m)   (((m) & ST_DIRECT) == ST_DIRECT)
#	endif
#	if defined(M_OS2)
#		define S_ISDIR(m)   ((m) & S_IF_DIR)
#	endif
#	if defined(M_UNIX)
#		define S_ISDIR(m)   (((m) & S_IFMT) == S_IFDIR)
#	endif
#endif

#if !defined(S_ISREG)
#	define S_ISREG(m)   (((m) & S_IFMT) == S_IFREG)
#endif

/*
 *  function prototypes & extern definitions	
 */ 

#include	"patchlev.h"
#include	"extern.h"
#include	"nntplib.h"
#include	"proto.h"
