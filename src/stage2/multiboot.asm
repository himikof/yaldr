; Multiboot spec-related routines
; asmsyntax=nasm

%include "asm/main.inc"
%include "asm/output.inc"
%include "asm/mem.inc"
%include "asm/mem_private.inc"
%include "asm/elf32.inc"
%include "asm/ext2fs.inc"
%include "asm/cpumode.inc"

BITS 16

MULTIBOOT_MAGIC equ 0x1BADB002

struc mb_hdr_t
    .magic resd 1              ; MULTIBOOT_MAGIC
    .flags resd 1              ; load options
                                   ; bit 0: align modules (req)
                                   ; bit 1: get meminfo (req)
                                   ; bit 2: get video modes (req)
                                   ; bit 16: override image load address (opt/rec)
    .checksum resd 1           ; 0 - .magic - .flags
    .header_addr resd 1        ; [16] physaddr of the header 
    .load_addr resd 1          ; [16] physaddr of the image start
    .load_end_addr resd 1      ; [16] physaddr of the image end, 0 => load whole image
    .bss_end_addr resd 1       ; [16] physaddr of bss (to fill) end, 0 => no bss
    .entry_addr resd 1         ; [16] physaddr of an entry point
    .mode_type resd 1          ; [2] rec video mode: 1 - graphic, 0 - text
    .width resd 1              ; [2] rec screen width, 0 => no preference
    .heigth resd 1             ; [2] rec screen height, 0 => no preference
    .depth resd 1              ; [2] rec screen bpp, 0 => no preference, or text mode
endstruc

struc mb_info_t
    .flags resd 1
    .mem_upper resd 1          ; [0]
    .mem_lower resd 1          ; [0]
    .boot_device resd 1        ; [1]
    .cmdline resd 1            ; [2]
    .mods_count resd 1         ; [3]
    .mods_addr resd 1          ; [3]
    .syms resd 4               ; [4, 5]
    .mmap_length resd 1        ; [6]
    .mmap_addr resd 1          ; [6]
    .drives_length resd 1      ; [7]
    .drives_addr resd 1        ; [7]
    .config_table resd 1       ; [8]
    .boot_loader_name resd 1   ; [9]
    .apm_table resd 1          ; [10]
    .vbe_control_info resd 1   ; [11]
    .vbe_mode_info resd 1      ; [11]
    .vbe_mode resw 1           ; [11]
    .vbe_iface_seg resd 1      ; [11]
    .vbe_iface_off resd 1      ; [11]
    .vbe_iface_len resd 1      ; [11]
endstruc

struc mb_aout_syms_t
    .tabsize resd 1
    .strsize resd 1
    .addr resd 1
    resd 1
endstruc

struc mb_elf_syms_t
    .num resd 1
    .size resd 1
    .addr resd 1
    .shndx resd 1
endstruc

section .text

MULTIBOOT_SEARCH_END equ 8192

; Load the kernel from the specified file handle
; Argument: file :: opaque_ptr - file handle
; Return value: the kernel entry point, or 0 in case of failure
; Return value: (edx) the mb_info_t structure pointer
global load_kernel
load_kernel:
    push bp
    mov bp, sp
    sub sp, 20
%define file bp + 4
%define file_header ebp - 4
%define read_size ebp - 8
%define header ebp - 12
%define mbinfo ebp - 16
%define entry ebp - 20
    mov dword [entry], 0
    push dword MULTIBOOT_SEARCH_END
    call malloc
    add sp, 4
    mov [file_header], eax
    push dword MULTIBOOT_SEARCH_END
    push dword 0
    push dword [file_header]
    push dword [file]
    call ext2_readfile
    add sp, 16
    mov [read_size], eax
    xor ecx, ecx
    sub eax, mb_hdr_t_size - 1 ; not searching past buffer end
    mov edx, [file_header]
    cmp ecx, eax
    je .hdr_notfound
    .l1:
        cmp dword [edx + ecx], MULTIBOOT_MAGIC
        jne .continue
            mov ebx, MULTIBOOT_MAGIC
            add ebx, dword [edx + ecx + mb_hdr_t.flags]
            add ebx, dword [edx + ecx + mb_hdr_t.checksum]
            test ebx, ebx
            jz .hdr_found
    .continue:
        add ecx, 4
        cmp ecx, eax
        jb .l1
.hdr_notfound:
    printline "No multiboot header found in the image file", 10
    jmp .epilogue
.hdr_found:
    ; ecx == hdr offset
    lea ecx, [edx + ecx]
    mov [header], ecx
    push dword mb_info_t_size
    call malloc
    add sp, 4
    mov [mbinfo], eax
    mov dword [eax + mb_info_t.flags], 0
    ; bit 0 is "supported" because we do not support modules
    ; bit 1 is always supported
    mov ecx, [header]
    bt dword [ecx + mb_hdr_t.flags], 2
    jz .l3
        printline "Getting video modes is unsupported, cannot load kernel", 10
        jmp .epilogue        
    .l3:
    bt dword [ecx + mb_hdr_t.flags], 16
    jz .l4
        ; loading manually
        push esi
        mov esi, [header]
        mov ebx, esi
        sub ebx, [file_header]
        sub ebx, [esi + mb_hdr_t.header_addr]
        mov ecx, [esi + mb_hdr_t.load_addr]
        add ebx, ecx
        mov edx, [esi + mb_hdr_t.load_end_addr]
        test edx, edx
        jnz .fixed_size
            push dword [file]
            call ext2_getfilesize
            add sp, 4
            sub eax, ebx
            mov edx, eax
        .fixed_size:
        mov eax, [esi + mb_hdr_t.bss_end_addr]
        test eax, eax
        cmovz eax, edx
        push eax               ; memsz
        push edx               ; filesz
        push ecx               ; addr
        push ebx               ; offset
        push dword [file]      ; file
        call load_chunk
        add sp, 20
        test eax, eax
        jnz .epilogue
        mov eax, [esi + mb_hdr_t.entry_addr]
        mov [entry], eax
        pop esi
        jmp .loaded
    .l4:
    ; loading ELF
    push dword [read_size]
    push dword [file_header]
    push dword [file]
    call load_elf32
    add sp, 12
    mov [entry], eax
.loaded:
    push esi
    mov esi, [mbinfo]
    ; [0] -- memory size
    mov dword [esi + mb_info_t.mem_lower], 640 * 1024
    mov eax, [first_mem_hole]
    sub eax, 0x100000
    mov dword [esi + mb_info_t.mem_upper], eax
    or dword [esi + mb_info_t.flags], 1 << 0
    ; [1] -- boot device
    xor eax, eax
    not eax
    mov al, [boot_disk_id]
    mov [esi + mb_info_t.boot_device], eax
    or dword [esi + mb_info_t.flags], 1 << 1
    ; [2] -- cmdline -- ignore
    ; [3] -- modules -- ignore
    ; [4] -- a.out symbols -- forbid
    ; [5] -- ELF symbols -- ignore
    ; [6] -- memory map
    mov eax, [mem_map_start]
    mov [esi + mb_info_t.mmap_addr], eax
    mov ebx, MEMORY_MAP_END
    sub ebx, eax
    mov [esi + mb_info_t.mmap_length], ebx
    or dword [esi + mb_info_t.flags], 1 << 6
    ; [7] -- BIOS drives -- ignore
    ; [8] -- BIOS config -- ignore
    ; [9] -- Boot loader name
    lea eax, [loader_name]
    mov [esi + mb_info_t.boot_loader_name], eax
    or dword [esi + mb_info_t.flags], 1 << 9
    ; [10] -- APM table -- ignore
    ; [11] -- Graphics -- ignore
    ; mbinfo is ready now
    lea edx, [mbinfo]
    pop esi
.epilogue:
    mov eax, [entry]
    mov sp, bp
    pop bp
    ret

; Loads some data from disk, maybe zeroing some data after it.
; Argument: file :: opaque_ptr - file handle
; Argument: offset :: uint32_t - file offset
; Argument: addr :: ptr - memory address to load to
; Argument: filesz :: uint32_t - size to load
; Argument: memsz :: uint32_t - full chunk size (to zero the rest)
; Return value: 0 in case of a success
global load_chunk
load_chunk:
    push bp
    mov bp, sp
%define file ebp + 4
%define offset ebp + 8
%define addr ebp + 12
%define filesz ebp + 16
%define memsz ebp + 20
    cmp dword [addr], HIGH_MEMORY_START
    jae .l2
        printline "Cannot load kernel into low memory", 10
        mov eax, -1
        jmp .epilogue        
    .l2:
    push dword [filesz]
    push dword [offset]
    push dword [addr]
    push dword [file]
    call ext2_readfile
    add sp, 16
    cmp eax, dword [filesz]
    je .l1
        printline "Chunk read failure", 10
        mov eax, -1
        jmp .epilogue
    .l1:
    mov ecx, [memsz]
    sub ecx, eax
    push ecx
    push dword 0
    add eax, [addr]
    push eax
    call memset
    add sp, 12
    xor eax, eax
.epilogue:
    mov sp, bp
    pop bp
    ret

; Boots the loaded kernel
; Argument: mbinfo :: ptr - pointer to mb_info_t structure
; Argument: entry :: ptr - kernel entry point
; Does not return
global boot_kernel
boot_kernel:
    mov edi, [esp + 2]
    mov esi, [esp + 6]
    push dword mb_trampoline
    call switch_to_protected
    ; Never returns

BITS 32

; Boot trampoline
; edi: mb_info_t
; esi: entry point
mb_trampoline:
    mov eax, MULTIBOOT_MAGIC
    mov ebx, edi
    jmp esi

BITS 16

section .data
    loader_name db "Yaldr 0", 0
