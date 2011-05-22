#!/bin/sh

if [[ $EUID -ne 0 ]]; then
    echo "Should be root to run mkimage.sh" >&2
    exit 1
fi

fdimage=$1
dd if=/dev/zero of=$fdimage count=2880 2>/dev/null
lodev=`losetup -f --show $fdimage`
mke2fs -t ext2 $lodev > /dev/null || exit 1
mpoint=`mktemp -d`
mount $lodev $mpoint || exit 1
outfile=$2
s2patch=$3
list_blocks=$4
shift 4
cp -r -t $mpoint $* || exit 1
sync
stage2=`basename $1`
blocks=`$list_blocks $lodev $stage2`
set -- $blocks
fblock=$1
shift
lastblocks=$@
#echo blocks: $blocks
#echo lastblocks: ${lastblocks}
echo -n $fblock > $outfile
$s2patch $mpoint/$stage2 $lastblocks || exit 1
umount $mpoint
rmdir $mpoint
losetup -d $lodev
