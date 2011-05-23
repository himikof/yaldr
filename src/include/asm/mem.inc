; asmsyntax=nasm

MEMORY_MAP_END equ 0x1ffff

extern malloc
extern free

extern detect_memory
extern init_alloc

extern mem_map_start
