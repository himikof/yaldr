#!/bin/sh
qemu -hda build/tools/fdimage -boot ca -gdb tcp::1234 $*
