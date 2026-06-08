if test -z "$1"; then
  echo Syntax: install.sh diskdir
  echo where diskdir is the directory under which the ntex01 disk is mounted.
  exit -1
fi
if test -e "/tmp/install.ntex"; then
  echo Directory /tmp/install.ntex already exsits!
  echo Maybe someone else installs NTeX or has installed it?
  exit -1
fi
echo Preparing the installation of NTeX...
instdir=/tmp/install.ntex
mkdir $instdir
gzip -d - <$1/install.tgz >$instdir/install.tar
for i in diskfs disknam INFO README DISKS CHANGES
do
cp $1/$i $instdir/$i
done
cd $instdir
umount $1
tar xf $instdir/install.tar
rm $instdir/install.tar
echo
echo Starting installntex...
echo
$instdir/installntex
echo
echo You may call installntex again from the directory /tmp/install.ntex
echo in order to install more packages. After you have finished the
echo installation you can remove the directory /tmp/install.ntex
echo


