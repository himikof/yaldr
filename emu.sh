#!/bin/sh
qemu -fda build/tools/fdimage -boot a -gdb tcp::1234 $*
