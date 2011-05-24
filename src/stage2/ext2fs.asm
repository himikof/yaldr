; Ext2 filesystem read-only driver
; asmsyntax=nasm

%include "asm/disk.inc"
%include "asm/main.inc"
%include "asm/mem.inc"
%include "asm/output.inc"

BITS 16

struc ext2_fsinfo
    .disk: resd 1
    .inodes_count: resd 1
    .blocks_count: resd 1
    .first_data_block: resd 1
    .log_block_size: resd 1
    .blocks_per_group: resd 1
    .inodes_per_group: resd 1
    .inode_size: resw 1
    .frac: resw 1
    .bgdt: resd 1
endstruc

;;
; Ext2 internal structures

%define ext2i_s.inodes_count 0
%define ext2i_s.blocks_count 4
%define ext2i_s.first_data_block 20
%define ext2i_s.log_block_size 24
%define ext2i_s.blocks_per_group 32
%define ext2i_s.inodes_per_group 40
%define ext2i_s.magic 56
%define ext2i_s.state 58
%define ext2i_s.inode_size 88

struc ext2i_bg
    .block_bitmap: resd 1
    .inode_bitmap: resd 1
    .inode_table: resd 1
    .free_blocks_count: resw 1
    .free_inodes_count: resw 1
    .used_dirs_count: resw 1
    .pad: resw 1
    .reserved: resb 12
;
;;


section .text

global ext2_openfs
ext2_openfs:
    push ebp
    mov ebp,esp
%define disk ebp + 4

    mov ecx,1024
    call malloc
    mov esi,eax

    mov edx,[disk]
    push dword 2
    push dword 1024
    push esi
    push edx
    call read_sectors
    add esp,16

    cmp word [esi + ext2i_s.magic],0xEF53
    jne .error_wrongfs
    cmp word [esi + ext2i_s.state],1
    jne .error_notclean

    mov ecx,ext2_fsinfo_size
    call malloc
    mov edi,eax
    mov [edi + ext2_fsinfo.disk],dx
    mov ecx,[esi + ext2i_s.inodes_count]
    mov [edi + ext2_fsinfo.inodes_count],ecx
    mov ecx,[esi + ext2i_s.blocks_count]
    mov [edi + ext2_fsinfo.blocks_count],ecx
    mov ecx,[esi + ext2i_s.first_data_block]
    mov [edi + ext2_fsinfo.first_data_block],ecx
    mov ecx,[esi + ext2i_s.log_block_size]
    mov [edi + ext2_fsinfo.log_block_size],ecx
    mov ecx,[esi + ext2i_s.blocks_per_group]
    mov [edi + ext2_fsinfo.blocks_per_group],ecx
    mov ecx,[esi + ext2i_s.inodes_per_group]
    mov [edi + ext2_fsinfo.inodes_per_group],ecx
    mov cx,[esi + ext2i_s.inode_size]
    mov [edi + ext2_fsinfo.inode_size],cx

    mov ebx,1
    add ebx,[edi + ext2_fsinfo.log_block_size]
    mov [edi + ext2_fsinfo.frac],bx

    mov ebx,8 * 1024
    mov ecx,[edi + ext2_fsinfo.log_block_size]  ; block group size
    shl ebx,cl
    mov eax,[edi + ext2_fsinfo.blocks_count]
    xor edx,edx
    div ebx
    test edx,edx
    setnz dl
    xor dh,dh
    add eax,edx     ; block groups count
    shl eax,32      ; sizeof(BGDT)
    mov edx,eax
    shr eax,cl
    shr eax,10
    mov ebx,eax
    shl ebx,cl
    shl ebx,10
    test ebx,edx
    setnz dl
    xor dh,dh
    add eax,edx     ; number of blocks used for BGDT 

    push eax
    mov eax,[edi + ext2_fsinfo.first_data_block]
    add eax,1
    push eax
    call ext2_readblocks
    mov [edi + ext2_fsinfo.bgdt],eax

    ret

.error_wrongfs:
    printline 'That is not an ext2 FS', 10
    call loader_panic
    ret

.error_notclean:
    printline 'Will not mount unclean FS', 10
    call loader_panic
    ret


global ext2_openfile
ext2_openfile:
    ret


global ext2_readfile
ext2_readfile:
    ret


ext2_readblocks:
    mov eax,[esp + 4]
    mov cx,[edi + ext2_fsinfo.frac]
    shl eax,cl
    mov [esp + 4],eax
    mov eax,[esp]
    mov cx,[edi + ext2_fsinfo.log_block_size]
    shl eax,cl
    shl eax,1
    mov [esp],eax
    shl eax,9
    mov ecx,eax
    call malloc
    push eax
    push dword [edi + ext2_fsinfo.disk]
    call read_sectors
    mov eax,[esp + 4]
    add esp,8
    ret


; TODO: kill me plz!
malloc:
    mov eax,0x12340000
    add eax,[malloc_l]
    add [malloc_l],ecx
    ret


section .data
; TODO: kill me plz!
malloc_l: dd 0
