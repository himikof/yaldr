; asmsyntax=nasm

MEMORY_MAP_END equ 0x1ffff
HIGH_MEMORY_START equ 0x100000

;%define MALLOC_PREFIX dl_
%define MALLOC_PREFIX test_

;%define MALLOC_HIGH
%define MALLOC_LOW

%define MALLOC_PANIC
