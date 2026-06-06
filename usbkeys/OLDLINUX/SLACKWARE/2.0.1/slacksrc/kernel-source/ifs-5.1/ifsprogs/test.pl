#!/usr/bin/perl

# This test verifies correct function of the Inheriting File System (IFS) for
# a collection of strictly serial operations. This test does NEITHER guarantee
# total correctness of the file system code NOR does it give any indication,
# whether there are incorrectly handled race conditions or not.


require("sys/syscall.ph");
require("linux/errno.ph");
require("linux/stat.ph");


if (!$ARGV[0] || !chdir($ARGV[0])) {
    print "usage: test.pl base_directory\n";
    exit(1);
}

$A = "a";
$B = "b";
$AB = "a+b";

$first = 1;


sub pass
{
    local ($status) = @_;

    $status || die "PASS failed ($!)";
}


sub fail
{
    local ($status,$expect) = @_;

    $status && die "FAIL passed ($!)";
    die "FAILed with ".($!+0)." instead of $expect." if $! != $expect;
}


sub create
{
    local ($name,$data) = @_;

    open(FILE,">$name") || return 0;
    if ($data) {
	print FILE $data;
    }
    close FILE;
    return 1;
}


sub touch
{
    return &create(@_[0],"");
}


sub append
{
    local ($name,$data) = @_;

    open(FILE,">>$name") || return 0;
    if ($data) {
	print FILE $data;
    }
    close FILE;
    return 1;
}


sub unlink
{
    local ($name) = @_;

    return !syscall(&SYS_unlink,$name);
}


sub truncate
{
    local ($name,$length) = @_;

    open(FILE,">>$name") || die "$!";
    truncate(FILE,$length);
    close(FILE);
    return 1;
}


sub rename
{
    local ($old,$new) = @_;

    return !syscall(&SYS_rename,$old,$new);
}


sub unwhiteout
{
    local ($dir,$name) = @_;
    local ($status);

    open(DIR,$dir) || die "open directory $dir: $!";
    $status = ioctl(DIR,0x53464900,$name);
    close(DIR);
    return $status;
}


sub tree
{
    local ($dir) = @_;
    local (@dir,@new,$name,$dot,$dotdot);

    opendir(DIR,$dir) || die("opendir $dir: $!");
    @dir = readdir(DIR);
    closedir(DIR);
    @new = ();
    $dor = $dotdot = 0;
    for (@dir) {
	$name = $_;
	if ($name eq ".") {
	    if ($dot) { die "duplicate . in $dir"; }
	    $dot = 1;
	}
	elsif ($name eq "..") {
	    if ($dotdot) { die "duplicate .. in $dir"; }
	    $dotdot = 1;
	}
	else {
	    push(@new,$name);
	    if (&S_ISDIR((lstat($dir."/".$name))[2])) {
	        push(@new,grep($_ = $name."/".$_,&tree($dir."/".$name)));
	    }
	}
    }
    if (!$dot) { die "no . in $dir"; }
    if (!$dotdot) { die "no .. in $dir"; }
    return @new;
}


sub clean
{
    &pass(system("smount -u $AB") == 0);
# &pass(chdir("/"));
# &pass(system("umount /scratch") == 0);
# &pass(system("mount /scratch") == 0);
# &pass(chdir("/scratch"));
    $mounted = 0;
    for (reverse @left) {
	if (m,^(.*)/$,) {
	    &pass(rmdir($1));
	}
	elsif (m/^([^-=(|]+)([-=(|].*)?$/) {
	    &pass(unlink($1));
	}
	else {
	    die("Unknown file \"$_\"");
	}
    }
    @left = ();
    &pass(rmdir($A));
    &pass(rmdir($B));
    &pass(rmdir($AB));
}


sub begin
{
    $tests++;
    print "@_\n";
    if (!$first) {
	&clean();
    }
    $first = 0;
    &pass(mkdir($A,0777));
    &pass(mkdir($B,0777));
    &pass(mkdir($AB,0777));
}


sub init
{
    local ($dir);

    $dir = shift(@_);
    for (@_) {
	if (m,^(.*)/$,) {
	    &pass(mkdir($dir."/".$1,0777));
	}
	elsif (m/^([^-=(]+)(=|->|\(|\|)(.*)$/) {
	    if ($2 eq "=") { &pass(&create($dir."/".$1,$3)); }
	    elsif ($2 eq "->") { &pass(symlink($3,$dir."/".$1)); }
	    elsif ($2 eq "|") { die "not yet supported"; }
	    elsif ($2 eq "(") { die "not yet supported"; }
	    else { die "unknown attribute \"$2\""; }
	}
	else {
	    &pass(&touch($dir."/".$_));
	}
    }
}

# Must be called before performing any operations on the IFS in a test
# sequence. test implicitly calls commit.

sub commit
{
    if (!$mounted) {
	&pass(system("smount -t ifs $A,$B $AB") == 0);
	$mounted = 1;
    }
}


sub test
{
    local ($dir,$mode,$rdev,@dir,@expect,$file);

    $dir = shift(@_);
    &commit();
    if ($dir ne $AB) {
	for (@_) {
	    push(@left,$dir."/".$_);
	}
    }
    @dir = &tree($dir);
    for (@dir) {
	($mode,$rdev) = (lstat($dir."/".$_))[2,6];
	if (&S_ISREG($mode)) { ; }
	elsif (&S_ISDIR($mode)) { $_ .= "/"; }
	elsif (&S_ISLNK($mode)) { $_ .= "->".readlink($dir."/".$_); }
	elsif (&S_ISFIFO($mode)) { $_ .= "|"; }
	elsif (&S_ISCHR($mode) || &S_ISBLK($mode)) {
	    $_ .= sprintf("(%d,%d)",$rdev >> 8,$rdev & 0xff);
	}
	else {
	    die "unknown mode ".sprintf("0%o",$mode);
	}
    }
    @expect = sort(@_);
    @dir = sort(@dir);
    if ($#_ != $#dir) {
	die "directories \"@expect\" and \"@dir\" differ in size";
    }
    for (0..$#_) {
	if ($expect[$_] =~ /^([^=]*)=(.*)$/) {
	    if ($1 ne $dir[$_]) {
		die "directories \"@expect\" and \"@dir\" differ";
	    }
	    open(FILE,$dir."/".$1) || die "can't open $1: $!";
	    $file = join("\n",<FILE>);
	    if ($2 ne $file) {
		die "content of file $dir/$1 is \"$file\" instead of \"$2\"";
	    }
	    close FILE;
	}
	else {
	    if ($expect[$_] ne $dir[$_]) {
		die "directories \"@expect\" and \"@dir\" differ";
	     }
	}
    }
}


# INITIALIZATION

# system("smount -u /scratch; smount -u $AB; rm -rf $A $B $AB");

# READDIR

&begin("readdir, no files");
&test($A);
&test($B);
&test($AB);

&begin("readdir, on upper layer");
&init($A,"file_a");
&test($A,"file_a");
&test($B);
&test($AB,"file_a");

&begin("readdir, on lower layer");
&init($B,"file_b");
&test($A);
&test($B,"file_b");
&test($AB,"file_b");

&begin("readdir, on both layers");
&init($A,"file_a","file_c");
&init($B,"file_b","file_c");
&test($A,"file_a","file_c");
&test($B,"file_b","file_c");
&test($AB,"file_a","file_b","file_c");

&begin("readdir, on lower layer, whiteout");
&init($A,".../",".../file_b");
&init($B,"file_b");
&test($A,".../",".../file_b");
&test($B,"file_b");
&test($AB);

&begin("readdir, no files, whiteout (corrupt)");
&init($A,".../",".../file");
&init($B);
&test($A,".../",".../file");
&test($B);
&test($AB);

&begin("readdir, multiple directories");
&init($A,"0/","2/","2/3");
&init($B,"1/","2/","2/4");
&test($A,"0/","2/","2/3");
&test($B,"1/","2/","2/4");
&test($AB,"0/","1/","2/","2/3","2/4");

&begin("readdir, lower hidden");
&init($A,"dir/","dir/1=one","dir/2=two",".../",".../dir/");
&init($B,"dir/","dir/3=three");
&test($A,"dir/","dir/1=one","dir/2=two",".../",".../dir/");
&test($B,"dir/","dir/3=three");
&test($AB,"dir/","dir/1=one","dir/2=two");

# READ FILE

&begin("read file, doesn't exist");
&commit();
&fail(open(DUMMY,"$AB/file"),&ENOENT);

&begin("read file, doesn't exist, whiteout (corrupt)");
&init($A,".../",".../file");
&test($A,".../",".../file");
&fail(open(DUMMY,"$AB/file"),&ENOENT);

&begin("read file, on upper layer");
&init($A,"file=just_a_file");
&test($A,"file=just_a_file");
&test($AB,"file=just_a_file");

&begin("read file, on lower layer");
&init($B,"file=just_a_file");
&test($B,"file=just_a_file");
&test($AB,"file=just_a_file");

&begin("read file, on both layers");
&init($A,"file=file_on_A");
&init($B,"file=file_on_B");
&test($A,"file=file_on_A");
&test($B,"file=file_on_B");
&test($AB,"file=file_on_A");

&begin("read file, on upper layer, whiteout (corrupt)");
&init($A,"file=just_a_file",".../",".../file");
&test($A,"file=just_a_file",".../",".../file");
&fail(open(DUMMY,"$AB/file"),&ENOENT);

&begin("read file, on lower layer, whiteout");
&init($A,".../",".../file");
&init($B,"file=a_file");
&test($A,".../",".../file");
&test($B,"file=a_file");
&fail(open(DUMMY,"$AB/file"),&ENOENT);

&begin("read file, on both layers, whiteout (corrupt)");
&init($A,"file=file_on_A",".../",".../file");
&init($B,"file=file_on_B");
&test($A,"file=file_on_A",".../",".../file");
&test($B,"file=file_on_B");
&fail(open(DUMMY,"$AB/file"),&ENOENT);

&begin("read file ..., on upper layer (invalid name)");
&init($A,"...");
&commit();
&fail(open(DUMMY,"$AB/..."),&ENOENT);
&test($A,"...");

# CREATE FILE

&begin("create file, file is new");
&commit();
&pass(&create("$A/file","a_file_..."));
&test($A,"file=a_file_...");
&test($AB,"file=a_file_...");

&begin("create file, file is new, whiteout (corrupt)");
&init($A,".../",".../file");
&commit();
&pass(&create("$AB/file","a_file_..."));
&test($A,"file=a_file_...",".../");
&test($AB,"file=a_file_...");

&begin("create file, exists on upper layer");
&init($A,"file=on A");
&commit();
&pass(&create("$AB/file","a_file"));
&test($A,"file=a_file");
&test($AB,"file=a_file");

&begin("create file, exists on lower layer");
&init($B,"file=on_B");
&commit();
&pass(&create("$AB/file","a_file_..."));
&test($A,"file=a_file_...");
&test($B,"file=on_B");
&test($AB,"file=a_file_...");

&begin("create file, exists on upper layer, whiteout (corrupt)");
&init($A,"file=on_A",".../",".../file");
&commit();
&fail(&create("$AB/file","a_file"),&EEXIST);
&test($A,"file=on_A",".../",".../file");
&test($AB);

&begin("create file, exists on lower layer, whiteout");
&init($A,".../",".../file");
&init($B,"file=on_B");
&commit();
&pass(&create("$AB/file","a_file_..."));
&test($A,"file=a_file_...",".../");
&test($B,"file=on_B");
&test($AB,"file=a_file_...");

&begin("create file ..., new file (invalid name)");
&commit();
&fail(&create("$AB/...",""),&EINVAL);
&test($A);

&begin("create file, with entire directory tree");
&init($A,"1/","1/2/","1/2/3/");
&init($B,"1/","1/2/","1/2/3/");
&commit();
&pass(&create("$AB/1/2/3/file",""));
&test($A,"1/","1/2/","1/2/3/","1/2/3/file");
&test($B,"1/","1/2/","1/2/3/");
&test($AB,"1/","1/2/","1/2/3/","1/2/3/file");

&begin("create file, with partial directory tree");
&init($A,"1/");
&init($B,"1/","1/2/","1/2/3/");
&commit();
&pass(&create("$AB/1/2/3/file",""));
&test($A,"1/","1/2/","1/2/3/","1/2/3/file");
&test($B,"1/","1/2/","1/2/3/");
&test($AB,"1/","1/2/","1/2/3/","1/2/3/file");

&begin("create file, with empty directory tree");
&init($A);
&init($B,"1/","1/2/","1/2/3/");
&commit();
&pass(&create("$AB/1/2/3/file",""));
&test($A,"1/","1/2/","1/2/3/","1/2/3/file");
&test($B,"1/","1/2/","1/2/3/");
&test($AB,"1/","1/2/","1/2/3/","1/2/3/file");

# APPEND TO FILE

&begin("append to existing file, upper layer");
&init($A,"file=on_A");
&commit();
&pass(&append("$AB/file","_more"));
&test($A,"file=on_A_more");
&test($B);
&test($AB,"file=on_A_more");

&begin("append to existing file, lower layer");
&init($B,"file=on_B");
&commit();
&pass(&append("$AB/file","_more"));
&test($A,"file=on_B_more");
&test($B,"file=on_B");
&test($AB,"file=on_B_more");

&begin("append to existing file, both layers");
&init($A,"file=on_A");
&init($B,"file=on_B");
&commit();
&pass(&append("$AB/file","_more"));
&test($A,"file=on_A_more");
&test($B,"file=on_B");
&test($AB,"file=on_A_more");

&begin("append to file, with entire directory tree");
&init($A,"1/","1/2/","1/2/3/");
&init($B,"1/","1/2/","1/2/3/","1/2/3/file=B");
&commit();
&pass(&append("$AB/1/2/3/file","_more"));
&test($A,"1/","1/2/","1/2/3/","1/2/3/file=B_more");
&test($B,"1/","1/2/","1/2/3/","1/2/3/file=B");
&test($AB,"1/","1/2/","1/2/3/","1/2/3/file=B_more");

&begin("append to file, with partial directory tree");
&init($A,"1/");
&init($B,"1/","1/2/","1/2/3/","1/2/3/file=B");
&commit();
&pass(&append("$AB/1/2/3/file","_more"));
&test($A,"1/","1/2/","1/2/3/","1/2/3/file=B_more");
&test($B,"1/","1/2/","1/2/3/","1/2/3/file=B");
&test($AB,"1/","1/2/","1/2/3/","1/2/3/file=B_more");

&begin("append to file, with empty directory tree");
&init($A);
&init($B,"1/","1/2/","1/2/3/","1/2/3/file=B");
&commit();
&pass(&append("$AB/1/2/3/file","_more"));
&test($A,"1/","1/2/","1/2/3/","1/2/3/file=B_more");
&test($B,"1/","1/2/","1/2/3/","1/2/3/file=B");
&test($AB,"1/","1/2/","1/2/3/","1/2/3/file=B_more");

# TRUNCATE FILE

&begin("truncating file, upper layer");
&init($A,"file=abcde");
&commit();
&pass(&truncate("$AB/file",2));
&test($A,"file=ab");
&test($B);
&test($AB,"file=ab");

&begin("truncating file, lower layer");
&init($B,"file=abcde");
&commit();
&pass(&truncate("$AB/file",3));
&test($A,"file=abc");
&test($B,"file=abcde");
&test($AB,"file=abc");

# UNLINK

&begin("unlink, file doesn't exist");
&commit();
&fail(&unlink("$AB/file"),&ENOENT);

&begin("unlink, file doesn't exist, whiteout (corrupt)");
&init($A,".../",".../file");
&commit();
&fail(&unlink("$AB/file"),&ENOENT);
&test($A,".../",".../file");
&test($AB);

&begin("unlink, exists on upper layer");
&init($A,"file");
&commit();
&pass(&unlink("$AB/file"));
&test($A);
&test($AB);

&begin("unlink, exists on lower layer");
&init($B,"file");
&commit();
&pass(&unlink("$AB/file"));
&test($A,".../",".../file");
&test($B,"file");
&test($AB);

&begin("unlink, exists on both layers");
&init($A,"file=A");
&init($B,"file=B");
&commit();
&pass(&unlink("$AB/file"));
&test($A,".../",".../file");
&test($B,"file=B");
&test($AB);

&begin("unlink, exists on upper layer, whiteout (corrupt)");
&init($A,"file",".../",".../file");
&commit();
&fail(&unlink("$AB/file"),&ENOENT);
&test($A,"file",".../",".../file");
&test($AB);

&begin("unlink, exists on lower layer, whiteout");
&init($A,".../",".../file");
&init($B,"file");
&commit();
&fail(&unlink("$AB/file"),&ENOENT);
&test($A,".../",".../file");
&test($B,"file");
&test($AB);

&begin("unlink, with entire directory tree");
&init($A,"1/","1/2/","1/2/3/");
&init($B,"1/","1/2/","1/2/3/","1/2/3/file");
&commit();
&pass(&unlink("$AB/1/2/3/file"));
&test($A,"1/","1/2/","1/2/3/","1/2/3/.../","1/2/3/.../file");
&test($B,"1/","1/2/","1/2/3/","1/2/3/file");
&test($AB,"1/","1/2/","1/2/3/");

&begin("unlink, with partial directory tree");
&init($A,"1/");
&init($B,"1/","1/2/","1/2/3/","1/2/3/file");
&commit();
&pass(&unlink("$AB/1/2/3/file"));
&test($A,"1/","1/2/","1/2/3/","1/2/3/.../","1/2/3/.../file");
&test($B,"1/","1/2/","1/2/3/","1/2/3/file");
&test($AB,"1/","1/2/","1/2/3/");

&begin("unlink, with empty directory tree");
&init($A);
&init($B,"1/","1/2/","1/2/3/","1/2/3/file");
&commit();
&pass(&unlink("$AB/1/2/3/file"));
&test($A,"1/","1/2/","1/2/3/","1/2/3/.../","1/2/3/.../file");
&test($B,"1/","1/2/","1/2/3/","1/2/3/file");
&test($AB,"1/","1/2/","1/2/3/");

# MKDIR

&begin("mkdir, directory is new");
&commit();
&pass(mkdir("$AB/dir",0777));
&test($A,"dir/");
&test($B);
&test($AB,"dir/");

&begin("mkdir, directory is new, whiteout (corrupt)");
&init($A,".../",".../dir");
&commit();
&pass(mkdir("$AB/dir",0777));
&test($A,"dir/",".../");
&test($B);
&test($AB,"dir/");

&begin("mkdir, exists on upper layer");
&init($A,"dir/");
&commit();
&fail(mkdir("$AB/dir",0777),&EEXIST);
&test($A,"dir/");
&test($B);
&test($AB,"dir/");

&begin("mkdir, exists on lower layer");
&init($B,"dir/");
&commit();
&fail(mkdir("$AB/dir",0777),&EEXIST);
&test($A);
&test($B,"dir/");
&test($AB,"dir/");

&begin("mkdir, exists on upper layer, whiteout (corrupt)");
&init($A,"dir/",".../",".../dir");
&commit();
&fail(mkdir("$AB/dir",0777),&EEXIST);
&test($A,"dir/",".../",".../dir");
&test($B);
&test($AB);

&begin("mkdir, exists on lower layer, whiteout");
&init($A,".../",".../dir");
&init($B,"dir/");
&commit();
&pass(mkdir("$AB/dir",0777));
&test($A,"dir/",".../",".../dir/");
&test($B,"dir/");
&test($AB,"dir/");

# RMDIR

&begin("rmdir, directory doesn't exist");
&commit();
&fail(rmdir("$A/dir"),&ENOENT);
&test($AB);

&begin("rmdir, directory doesn't exist, whiteout (corrupt)");
&init($A,".../",".../dir");
&commit();
&fail(rmdir("$AB/dir"),&ENOENT);
&test($A,".../",".../dir");
&test($AB);

&begin("rmdir, exists on upper layer, empty");
&init($A,"dir/");
&commit();
&pass(rmdir("$AB/dir"));
&test($A);
&test($AB);

&begin("rmdir, exists on lower layer, empty");
&init($B,"dir/");
&commit();
&pass(rmdir("$AB/dir"));
&test($A,".../",".../dir");
&test($B,"dir/");
&test($AB);

&begin("rmdir, exists on upper layer, empty, whiteout (corrupt)");
&init($A,"dir/",".../",".../dir");
&commit();
&fail(rmdir("$AB/dir"),&ENOENT);
&test($A,"dir/",".../",".../dir");
&test($AB);

&begin("rmdir, exists on lower layer, empty, whiteout");
&init($A,".../",".../dir");
&init($B,"dir/");
&commit();
&fail(rmdir("$AB/dir"),&ENOENT);
&test($A,".../",".../dir");
&test($B,"dir/");
&test($AB);

&begin("rmdir, exists on upper layer, full");
&init($A,"dir/","dir/1","dir/2");
&commit();
&fail(rmdir("$AB/dir"),&ENOTEMPTY);
&test($A,"dir/","dir/1","dir/2");
&test($AB,"dir/","dir/1","dir/2");

&begin("rmdir, exists on both layers, files in lower");
&init($A,"dir/");
&init($B,"dir/","dir/1","dir/2");
&commit();
&fail(rmdir("$AB/dir"),&ENOTEMPTY);
&test($A,"dir/");
&test($B,"dir/","dir/1","dir/2");
&test($AB,"dir/","dir/1","dir/2");

&begin("rmdir, exists on lower layer, full");
&init($B,"dir/","dir/1","dir/2");
&commit();
&fail(rmdir("$AB/dir"),&ENOTEMPTY);
&test($A);
&test($B,"dir/","dir/1","dir/2");
&test($AB,"dir/","dir/1","dir/2");

&begin("rmdir, exists on both layers, files in lower, all files whited out");
&init($A,"dir/","dir/.../","dir/.../1","dir/.../2");
&init($B,"dir/","dir/1","dir/2");
&commit();
&pass(rmdir("$AB/dir"));
&test($A,".../",".../dir");
&test($B,"dir/","dir/1","dir/2");
&test($AB);

&begin("rmdir, exists on both layers, empty, lower hidden");
&init($A,"dir/",".../",".../dir/");
&init($B,"dir/");
&commit();
&pass(rmdir("$AB/dir"));
&test($A,".../",".../dir");
&test($B,"dir/");
&test($AB);

# SYMLINK

&begin("symlink, file is new");
&commit();
&pass(symlink("dummy","$AB/link"));
&test($A,"link->dummy");
&test($AB,"link->dummy");

&begin("symlink, file is new, whiteout (corrupt)");
&init($A,".../",".../link");
&commit();
&pass(symlink("dummy","$AB/link"));
&test($A,"link->dummy",".../");
&test($AB,"link->dummy");

&begin("symlink, exists on upper layer");
&init($A,"file");
&commit();
&fail(symlink("dummy","$AB/file"),&EEXIST);
&test($A,"file");
&test($AB,"file");

&begin("symlink, exists on lower layer");
&init($B,"file");
&commit();
&fail(symlink("dummy","$AB/file"),&EEXIST);
&test($A);
&test($B,"file");
&test($AB,"file");

&begin("symlink, exists on upper layer, whiteout (corrupt)");
&init($A,"link",".../",".../link");
&commit();
&fail(symlink("dummy","$AB/link"),&EEXIST);
&test($A,"link",".../",".../link");
&test($AB);

&begin("symlink, exists on lower layer, whiteout");
&init($A,".../",".../link");
&init($B,"link");
&commit();
&pass(symlink("dummy","$AB/link"));
&test($A,"link->dummy",".../");
&test($B,"link");
&test($AB,"link->dummy");

# LINK

# &begin("link, same FS, file is new");
# &begin("link, same FS, file is new, whiteout");
# &begin("link, same FS, exists on upper layer");
# &begin("link, same FS, exists on lower layer");
# &begin("link, same FS, exists on upper layer, whiteout");
# &begin("link, same FS, exists on lower layer, whiteout");
# &begin("link, different FS");

# MKNOD

# &begin("mknod, file is new");
# &begin("mknod, file is new, whiteout");
# &begin("mknod, exists on upper layer");
# &begin("mknod, exists on lower layer");
# &begin("mknod, exists on upper layer, whiteout");
# &begin("mknod, exists on lower layer, whiteout");

# RENAME

&begin("rename file, non-existing source name");
&init($A);
&commit();
&fail(&rename("$AB/src","$AB/dst"),&ENOENT);
&test($A);
&test($AB);

&begin("rename file, non-existing source name, whiteout (corrupt)");
&init($A,".../",".../src");
&commit();
&fail(&rename("$AB/src","$AB/dst"),&ENOENT);
&test($A,".../",".../src");
&test($AB);

&begin("rename file, src and dst on the same FS, same directory");
&init($A,"src=test");
&commit();
&pass(&rename("$AB/src","$AB/dst"));
&test($A,"dst=test");
&test($AB,"dst=test");

&begin("rename file, same FS, same directory, whiteout");
&init($A,"src",".../",".../src");
&commit();
&fail(&rename("$AB/src","$AB/dst"),&ENOENT);
&test($A,"src",".../",".../src");
&test($AB);

&begin("rename file, same FS, same directory, dst whiteout");
&init($A,"src=test",".../",".../dst");
&init($B,"dst");
&commit();
&pass(&rename("$AB/src","$AB/dst"));
&test($A,"dst=test",".../");
&test($B,"dst");
&test($AB,"dst=test");

&begin("rename file, same FS, different directory");
&init($A,"src=test","dir/");
&commit();
&pass(&rename("$AB/src","$AB/dir/dst"));
&test($A,"dir/","dir/dst=test");
&test($AB,"dir/","dir/dst=test");

&begin("rename file, same FS, different directory, src whiteout");
&init($A,"src",".../",".../src","dir/");
&commit();
&fail(&rename("$AB/src","$AB/dir/dst"),&ENOENT);
&test($A,"src",".../",".../src","dir/");
&test($AB,"dir/");

&begin("rename file, same FS, different directory, dst whiteout");
&init($A,"src=foo","dir/","dir/.../","dir/.../dst");
&init($B,"dir/","dir/dst=bar");
&commit();
&pass(&rename("$AB/src","$AB/dir/dst"));
&test($A,"dir/","dir/.../","dir/dst=foo");
&test($B,"dir/","dir/dst=bar");
&test($AB,"dir/","dir/dst=foo");

&begin("rename file, same FS, diff. directory, dst ex. & whiteout (corrupt)");
&init($A,"src=foo","dir/","dir/.../","dir/.../dst","dir/dst=baz");
&init($B,"dir/","dir/dst=bar");
&commit();
&pass(&rename("$AB/src","$AB/dir/dst"));
&test($A,"dir/","dir/.../","dir/dst=foo");
&test($B,"dir/","dir/dst=bar");
&test($AB,"dir/","dir/dst=foo");

&begin("rename file, same FS, different directory, dst dir. whiteout");
&init($A,"src=foo","dir/",".../",".../dir");
&init($B,"dir/");
&commit();
&fail(&rename("$AB/src","$AB/dir/dst"),&ENOENT);
&test($A,"src=foo","dir/",".../",".../dir");
&test($B,"dir/");
&test($AB,"src=foo");

&begin("rename file, same FS, different directory, incomplete path");
&init($A,"src=foo");
&init($B,"dir/");
&commit();
&pass(&rename("$AB/src","$AB/dir/dst"));
&test($A,"dir/","dir/dst=foo");
&test($B,"dir/");
&test($AB,"dir/","dir/dst=foo");

&begin("rename file, same FS, diff. level, same directory");
&init($A);
&init($B,"src=test");
&commit();
&pass(&rename("$AB/src","$AB/dst"));
&test($A,"dst=test",".../",".../src");
&test($B,"src=test");
&test($AB,"dst=test");

&begin("rename file, same FS, diff. level, different directory");
&init($A);
&init($B,"dir/","dir/src=foo");
&commit();
&pass(&rename("$AB/dir/src","$AB/dst"));
&test($A,"dst=foo","dir/","dir/.../","dir/.../src",".../");
&test($B,"dir/","dir/src=foo");
&test($AB,"dst=foo","dir/");

&begin("rename file, same FS, diff. level, diff. dir., dst exists on upper");
&init($A,"dst=foo");
&init($B,"dir/","dir/src=bar");
&commit();
&pass(&rename("$AB/dir/src","$AB/dst"));
&test($A,"dst=bar","dir/","dir/.../","dir/.../src",".../");
&test($B,"dir/","dir/src=bar");
&test($AB,"dst=bar","dir/");

&begin("rename file, same FS, diff. level, diff. dir., dst exists on lower");
&init($A);
&init($B,"dst=foo","dir/","dir/src=bar");
&commit();
&pass(&rename("$AB/dir/src","$AB/dst"));
&test($A,"dst=bar","dir/","dir/.../","dir/.../src",".../");
&test($B,"dst=foo","dir/","dir/src=bar");
&test($AB,"dst=bar","dir/");

&begin("rename file, same FS, diff. level, different directory, whiteout");
&init($A,".../",".../src");
&init($B,"src=test");
&commit();
&fail(&rename("$AB/src","$AB/dir/dst"),&ENOENT);
&test($A,".../",".../src");
&test($B,"src=test");
&test($AB);

# &begin("rename file, different FS, top-level");
# &begin("rename file, different FS, top-level, whiteout");
# &begin("rename file, different FS, different levels, 'same' dir.");
# &begin("rename file, different FS, different levels, 'diff.' dir.");
# &begin("rename file, different FS, different levels, dd, whiteout");

# UNWHITEOUT

&begin("unwhiteout file, does not exist, no whiteout");
&init($A);
&commit();
&fail(&unwhiteout("$AB","file"),&ENOENT);
&test($A);
&test($AB);

&begin("unwhiteout file, does not exist, whiteout (corrupt)");
&init($A,".../",".../file");
&commit();
&pass(&unwhiteout("$AB","file"));
&test($A,".../");
&test($AB);

&begin("unwhiteout file, exists on upper, no whiteout");
&init($A,"file=foo");
&commit();
&fail(&unwhiteout("$AB","file"),&ENOENT);
&test($A,"file=foo");
&test($AB,"file=foo");

&begin("unwhiteout file, exists on upper, whiteout (corrupt)");
&init($A,"file",".../",".../file");
&commit();
&pass(&unwhiteout("$AB","file"));
&test($A,"file",".../");
&test($AB,"file");

&begin("unwhiteout file, exists on lower, no whiteout");
&init($A);
&init($B,"file=test");
&commit();
&fail(&unwhiteout("$AB","file"),&ENOENT);
&test($A);
&test($B,"file=test");
&test($AB,"file=test");

&begin("unwhiteout file, exists on lower, whiteout");
&init($A,".../",".../file");
&init($B,"file=test");
&commit();
&pass(&unwhiteout("$AB","file"));
&test($A,".../");
&test($B,"file=test");
&test($AB,"file=test");

# Missing test:
#   create path across file systems

&clean();
print "Passed all $tests test sequences.\n";
exit(0);
