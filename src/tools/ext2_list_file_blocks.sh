#!/bin/bash


DEVICE="$1"
FILENAME="$2"


# Yeah, debugfs is that stupid
unset PAGER


BLOCK_SIZE=`debugfs "$DEVICE" -R 'stats' 2> /dev/null | grep "Block size:" | cut -d : -f 2 | sed 's/\s*//'`
if [ -z "$BLOCK_SIZE" ]; then
    exit -1
fi
FRAC=$(($BLOCK_SIZE / 512))

BLOCKS_COUNT=`debugfs $DEVICE -R "stat \"$FILENAME\"" 2> /dev/null | grep "TOTAL:" | cut -d : -f 2 | sed 's/\s*//'`
for i in `seq 0 $(($BLOCKS_COUNT-1))`; do
    BLOCK_N=`debugfs $DEVICE -R "bmap \"$FILENAME\" $i" 2> /dev/null | sed 's/\s*//'`
    if [ "$BLOCK_N" -eq 0 ]; then
        break
    fi

    START=$(($BLOCK_N * $FRAC))
    for k in `seq 0 $(($FRAC-1))`; do
        echo -n $(($START + $k)) ''
    done
done

echo
