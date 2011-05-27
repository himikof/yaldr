; ELF32 loader
; asmsyntax=nasm

%include "asm/ext2fs.inc"
%include "asm/main.inc"
%include "asm/mem.inc"
%include "asm/output.inc"
%include "asm/multiboot.inc"

BITS 16

EI_NIDENT equ 16
ELFCLASS32 equ 1
ELFDATA2LSB equ 1
EV_CURRENT equ 1
ELFOSABI_NONE equ 1
ELFABIVERSION_NONE equ 1

EM_386 equ 3
ET_EXEC equ 2

struc elf_ident_t
    ei_magic resb 4            ; 0x7f "ELF"
    ei_class resb 1            ; 32bit == 1
    ei_data_order resb 1       ; LSB == 1
    ei_version resb 1          ; 1
    ei_osabi resb 1            ; NONE == 0
    ei_abiversion resb 1       ; NONE == 0
    ei_pad0 resb 7
endstruc

struc elf_header_t
    e_ident resb elf_ident_t_size
    e_type resw 1
    e_machine resw 1
    e_version resd 1
    e_entry resd 1             ; virtual address
    e_pheader_offset resd 1    ; program header offset
    e_sheader_offset resd 1    ; section header offset
    e_flags resd 1
    e_elfheader_size resw 1
    e_pheader_entry_size resw 1
    e_pheader_entries resw 1
    e_sheader_entry_size resw 1
    e_sheader_entries resw 1
    e_snames_index resw 1
endstruc

PT_NULL equ 0
PT_LOAD equ 1
PT_PHDR equ 6

struc elf_pheader_t
    p_type resd 1              ; segment type
    p_offset resd 1            ; segment offset in file
    p_vaddr resd 1             ; virtual address to load
    p_paddr resd 1             ; physical address to load
    p_filesize resd 1          ; size of the file image
    p_memsize resd 1           ; size of the memory 
    p_flags resd 1             ; 
    p_align resd 1             ; address alignment
endstruc

section .text

; Load the specified ELF32 ET_EXEC file into memory
; Argument: file :: opaque_ptr - file handle
; Argument: header :: ptr - already-loaded header
; Argument: header_size :: uint32_t - header size
; Return value: the file entry point, or 0 in case of failure
global load_elf32
load_elf32:
    push bp
    mov bp, sp
    sub sp, 8
    push esi
%define file bp + 4
%define header bp + 8
%define header_size bp + 12
%define entry bp - 4
%define phdrs bp - 8
    mov dword [entry], 0
    cmp dword [header_size], elf_header_t_size
    jae .l1
        printline "Image file is too small", 10
        jmp .epilogue
    .l1:
    push dword ei_osabi  ; compare up to ei_osabi field
    push dword elf32_ident
    push dword [header]
    call memcmp
    add sp, 12
    jne .l2
        printline "ELF signature is not recognized", 10
        jmp .epilogue
    .l2:
    mov esi, [header]
    cmp word [esi + e_type], ET_EXEC
    jne .l3
    cmp word [esi + e_machine], EM_386
    jne .l3
    cmp dword [esi + e_version], EV_CURRENT
    jne .l3
    cmp dword [esi + e_pheader_offset], 0
    je .l3
    cmp word [esi + e_pheader_entries], 0
    je .l3
    cmp word [esi + e_pheader_entry_size], elf_pheader_t_size
    jb .l3
    jmp .l4
    .l3:
        printline "ELF file does not have right parameters", 10
        jmp .epilogue
    .l4:
    movzx eax, word [esi + e_pheader_entries]
    mul word [esi + e_pheader_entry_size]
    push eax
    push eax
    call malloc
    add sp, 4
    mov dword [phdrs], eax
    push dword [esp]
    push dword [esi + e_pheader_offset]
    push dword [phdrs]
    push dword [file]
    pusha
    printline "Reading program header table...", 10
    popa
    call ext2_readfile
    add sp, 16
    cmp eax, dword [esp]
    je .l5
        printline "Program header table read failure", 10
        jmp .epilogue
    .l5:
    add sp, 4
    push edi
    movzx edi, word [esi + e_pheader_entries]
    mov ebx, [phdrs]
    test edi, edi
    jz .l6
        .l7:
            cmp dword [ebx + p_type], PT_LOAD
            jne .continue
            push ebx
            sub sp, 16
            mov edx, dword [ebx + p_align]
            pusha
            printline "C"
            popa
            cmp edx, 1
            ja .do_align
                mov eax, dword [ebx + p_offset]
                mov [esp + 0], eax     ; offset
                mov eax, dword [ebx + p_vaddr]
                mov [esp + 4], eax     ; addr
                mov eax, dword [ebx + p_filesize]
                mov [esp + 8], eax    ; filesz
                mov eax, dword [ebx + p_memsize]
                mov [esp + 12], eax    ; memsz
            .do_align:
                dec edx
                mov eax, dword [ebx + p_offset]
                not edx
                and eax, edx
                mov [esp + 0], eax     ; offset
                mov eax, dword [ebx + p_vaddr]
                and eax, edx
                mov [esp + 4], eax     ; addr
                not edx
                mov ecx, dword [ebx + p_offset]
                and ecx, edx
                mov eax, dword [ebx + p_filesize]
                add eax, ecx
                mov [esp + 8], eax    ; filesz
                mov eax, dword [ebx + p_memsize]
                add eax, ecx
                mov [esp + 12], eax    ; memsz
            .do_read:
            push dword [file]
            call load_chunk
            add sp, 20
            pop ebx
            test eax, eax
            jnz .epilogue
        .continue:
            pusha
            ;printline ">"
            popa
            add ebx, [esi + e_pheader_entry_size]
            dec edi
            jnz .l7
    .l6:
    mov eax, [esi + e_entry]
    pop edi
    mov [entry], eax
.epilogue:
    mov eax, [entry]
    pop esi
    mov sp, bp
    pop bp
    ret

section .data

elf32_ident:
istruc elf_ident_t
    at ei_magic, db 0x7F, 'E', 'L', 'F'
    at ei_class, db ELFCLASS32
    at ei_data_order, db ELFDATA2LSB
    at ei_version, db EV_CURRENT
    at ei_osabi, db ELFOSABI_NONE
    at ei_abiversion, db ELFABIVERSION_NONE
    at ei_pad0, times 7 db 0
iend
