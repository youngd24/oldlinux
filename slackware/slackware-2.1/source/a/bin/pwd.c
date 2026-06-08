/* Written by Patrick Volkerding - public domain.
 * (Figure I can't make too much off this one. ;^)
 * ...just don't blame me if it causes you trouble. */

#include <unistd.h>

void main() {
    char dirbuf[1024];
    getcwd(dirbuf, 1024);
    printf("%s\n",dirbuf);
}
