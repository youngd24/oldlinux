/* smount.c  -  very simplistic mount command */

/*
 * Usage: smount [ -t type ] [ -o option,option,... ] device directory
 * 	  smount -t ifs [ -o option,option,... ] directory,... directory
 *        smount -u device
 *        smount -u directory
 */


#include <stdio.h>
#include <string.h>

#include <linux/unistd.h>
#include <linux/config.h>
#include <linux/fs.h>
#ifdef CONFIG_IFS_FS
#include <linux/ifs_fs.h>
#endif
#include <linux/mm.h>


#ifndef MS_MGC_VAL
#define MS_MGC_VAL 0xC0ED0000
#endif


static struct mount_opt {
    char *name;
    int value;
} mount_opt[] = {
    { "ro",     MS_RDONLY },
    { "rw",     0 },
    { "nosuid", MS_NOSUID },
    { "nodev",  MS_NODEV },
    { "noexec", MS_NOEXEC },
#ifdef MS_REMOUNT
    { "remount",MS_REMOUNT },
#endif
    { NULL,     0 }
};


_syscall5(int,mount,char *,dev,char *,dir,char *,type,unsigned long,flags,
  void *,data)
_syscall1(int,umount,char *,name)


static void usage(char *name)
{
    fprintf(stderr,"usage: %s [-t type] [-o option,option,...] device dir\n",
      name);
#ifdef CONFIG_IFS_FS
    fprintf(stderr,"%7s%s -t ifs [-o option,option,...] dir,dir,... dir\n","",
      name);
#endif
    fprintf(stderr,"%7s%s -u device\n","",name);
    fprintf(stderr,"%7s%s -u dir\n","",name);
    exit(1);
}


int main(int argc,char **argv)
{
    char *type,*options,*name,*this;
    char opt[PAGE_SIZE];
    int do_umount,flags;
    struct mount_opt *walk;

    type = options = NULL;
    do_umount = 0;
    if (!--argc) usage(*argv);
    name = *argv++;
    while (argc && argv[0][0] == '-') {
	if (argv[0][2]) usage(name);
	switch (argv[0][1]) {
	    case 'o':
		if (argc < 2) usage(name);
		options = *++argv;
		argc--;
		break;
	    case 't':
		if (argc < 2) usage(name);
		type = *++argv;
		argc--;
		break;
	    case 'u':
		do_umount = 1;
		break;
	    default:
		usage(name);
	}
	argv++;
	argc--;
    }
    if (do_umount) {
	if (type || options || argc != 1) usage(name);
	if (umount(argv[0]) < 0) {
	    perror("smount");
	    return 1;
	}
	return 0;
    }
    if (argc != 2) usage(name);
    flags = 0;
    *opt = 0;
    for (this = strtok(options,","); this; this = strtok(NULL,",")) {
	for (walk = mount_opt; walk->name; walk++)
	    if (!strcmp(walk->name,this)) break;
	if (walk->name) flags |= walk->value;
	else strcat(strcat(opt,this),",");
    }
    if (this = strrchr(opt,',')) *this = 0;
#ifdef CONFIG_IFS_FS
    if (!strcmp(type,"ifs")) {
	struct ifs_mpar *mpar;
	int flags;
	char *next;

	flags = 0;
	if (*opt)
	    if (!strcmp(opt,"cache")) flags = IFS_FF_CACHE;
	    else {
		fprintf(stderr,"Unrecognized by IFS: %s\n",opt);
		return 1;
	    }
	mpar = (struct ifs_mpar *) opt;
	mpar->magic = IFS_MOUNT_MAGIC;
	mpar->flags = flags;
	mpar->layers = 0;
	for (this = argv[0]; this; this = next) {
	    if (next = strchr(this,',')) *next++ = 0;
	    mpar->names[mpar->layers++] = this;
	}
    }
#endif
    if (mount(argv[0],argv[1],type,MS_MGC_VAL | flags,opt) < 0) {
	perror("smount");
	return 1;
    }
    return 0;
}
