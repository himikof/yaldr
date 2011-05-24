#!/bin/sh
qemu -fda build/tools/fdimage -boot ca -gdb tcp::1234 $*
