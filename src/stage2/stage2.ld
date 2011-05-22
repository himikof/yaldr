OUTPUT_FORMAT("elf32-i386", "elf32-i386", "elf32-i386")
OUTPUT_ARCH(i386)
ENTRY(stage2_start)

MEMORY
{
    LOWSPACE (rwx) : org = 0x8000, len = 0x4000
}

SECTIONS
{
    .head : {
        *(.text.head)
        . = 0x100;
        *(.data.head)
    }
    .text : {
        *(.text)
    }
    .data : {
        *(.data)
    }
}
