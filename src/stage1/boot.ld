OUTPUT_FORMAT("elf32-i386", "elf32-i386", "elf32-i386")
OUTPUT_ARCH(i386)
ENTRY(stage1_start)

MEMORY
{
    MBR (rwx) : org = 0x7c00, len = 0x0200
}

SECTIONS
{
    .text : {
        *(.text)
        *(.data)
        . = 436 - 8;
        *(.patchable)
        . =  0x200 - 4;
        *(.signature)
    }
}
