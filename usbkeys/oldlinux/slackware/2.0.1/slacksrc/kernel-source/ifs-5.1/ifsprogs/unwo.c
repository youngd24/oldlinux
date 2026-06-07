/* unwo.c  -  unwhiteout files on a mounted IFS file system */

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/ifs_fs.h>


static void unwhiteout(char *path)
{
    char *here,*dir,*file;
    int fd;

    if (here = strrchr(path,'/')) {
	*here = 0;
	dir = path;
	file = here+1;
    }
    else {
	dir = ".";
	file = path;
    }
    if ((fd = open(dir,O_RDONLY)) < 0) {
	perror(dir);
	return;
    }
    if (ioctl(fd,IFS_UNWHITEOUT,file) < 0) {
	if (here) *here = '/';
	perror(path);
    }
    (void) close(fd);
}


int main(int argc,char **argv)
{
    while (--argc) unwhiteout(*++argv);
    return 0;
}
