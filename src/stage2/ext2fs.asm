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
    .block_size: resd 1
    .blocks_per_group: resd 1
    .inodes_per_group: resd 1
    .inode_size: resw 1
    .fraclog: resw 1
    .bgdt: resd 1
    .cached_itable_group: resd 1
    .cached_itable: resd 1
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
endstruc

%define ext2i_i.mode 0
%define ext2i_i.size 4
%define ext2i_i.blocks 28
%define ext2i_i.block 40
%define ext2i_i.dir_acl 108
%define ext2i_i_size 128

struc ext2i_de
    .inode: resd 1
    .rec_len: resw 1
    .name_len: resb 1
    .file_type: resb 1
    .name: resb 0   ; 0-255
endstruc

;
;;

%define EXT2_ROOT_INO 2
%define EXT2_S_IFDIR 0x4000
%define EXT2_DELIM '/'


section .text

global ext2_openfs
ext2_openfs:
    push ebp
    mov ebp,esp
%define disk ebp + 6

    push dword 1024
    call malloc
    add esp,4
    mov esi,eax

    mov edx,[disk]
    push dword 2    ; superblock len
    push dword 2    ; superblock offset
    push esi
    push edx
    call read_sectors
    pop edx
    add esp,12

    cmp word [esi + ext2i_s.magic],0xEF53
    jne .error_wrongfs
    cmp word [esi + ext2i_s.state],1
    jne .error_notclean

    push dword ext2_fsinfo_size
    call malloc
    add esp,4
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
    mov eax,1024
    shl eax,cl
    mov [edi + ext2_fsinfo.block_size],eax
    mov ecx,[esi + ext2i_s.blocks_per_group]
    mov [edi + ext2_fsinfo.blocks_per_group],ecx
    mov ecx,[esi + ext2i_s.inodes_per_group]
    mov [edi + ext2_fsinfo.inodes_per_group],ecx
    mov cx,[esi + ext2i_s.inode_size]
    mov [edi + ext2_fsinfo.inode_size],cx
    mov [edi + ext2_fsinfo.cached_itable_group],dword -1
    mov [edi + ext2_fsinfo.cached_itable],dword 0

    mov ebx,1
    add ebx,[edi + ext2_fsinfo.log_block_size]
    mov [edi + ext2_fsinfo.fraclog],bx

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
    shl eax,5       ; sizeof(BGDT)
    mov edx,eax
    shr eax,cl
    shr eax,10
    mov ebx,eax
    shl ebx,cl
    shl ebx,10
    cmp ebx,edx
    setne dl
    xor dh,dh
    add eax,edx     ; number of blocks used for BGDT

    push eax
    mov eax,[edi + ext2_fsinfo.first_data_block]
    add eax,1
    push eax
    call ext2_readblocks
    add esp,8
    mov [edi + ext2_fsinfo.bgdt],eax

    mov eax,edi
    mov esp,ebp
    pop ebp
    ret

.error_wrongfs:
    printline 'That is not an ext2 FS', 10
    call loader_panic
    ret

.error_notclean:
    printline 'Will not mount unclean FS', 10
    call loader_panic
    ret


global ext2_closefs
ext2_closefs:
    mov eax,[esp + 2]
    push eax
    call free
    add esp,4
    ret


global ext2_openfile
ext2_openfile:
    push ebp
    mov ebp,esp
%define fshandle ebp + 6
%define filename ebp + 10
%define len ebp + 14
    add esp,8
%define inode ebp - 4
%define fnamelen ebp - 8
    mov edi,[fshandle]
    mov esi,[filename]
    mov eax,[len]
    mov [fnamelen],eax
    mov dword [inode],EXT2_ROOT_INO
    xor eax,eax
    .loop1:
        cmp dword [fnamelen],0
        jz .loop1.end
        xor ecx,ecx
        .loop2:
            mov al,[esi + ecx]
            cmp al,EXT2_DELIM
            je .loop2.end
            inc ecx
            cmp ecx,[fnamelen]
            je .loop2.end
            jmp .loop2
        .loop2.end:
        mov eax,[inode]
        push ecx
        push esi
        call ext2_findfileindir
        mov ecx,[esp + 4]
        add esp,8
        test eax,eax
        jz .notfound
        mov [inode],eax
        inc ecx
        add esi,ecx
        sub [fnamelen],ecx
        jmp .loop1
    .loop1.end:
    mov eax,[inode]
    mov ecx,eax
    .l:
        printline 'V'
        dec ecx
        jz .lend
        jmp .l
    .lend:
    jmp .exit
.notfound:
    xor eax,eax
    printline 'File not found', 10
.exit:
    mov esp,ebp
    pop ebp
    ret


global ext2_readfile
ext2_readfile:
    push ebp
    mov ebp,esp
    push edi
    push esi
%define fshandle ebp + 2
%define file ebp + 6
%define buffer ebp + 10
%define offset ebp + 14
%define len ebp + 18
    mov edi,[fshandle]
    sub esp,ext2i_i_size
%define inode ebp - ext2i_i_size
    mov esi,esp
    mov eax,[file]
    call ext2_loadinode
    mov esi,[buffer]
    mov eax,[offset]
    mov ecx,[edi + ext2_fsinfo.log_block_size]
    shr eax,cl
    shr eax,10
    mov edx,[len]
    shr edx,cl
    push edx
    cmp eax,12
    jae .startindirect
    cmp edx,12
    cmova edx,12
    sub edx,eax
    call .readdirect
    pop ecx
    sub ecx,edx
    test ecx,ecx
    jz .done

    
.done:
    pop esi
    pop edi
    mov esp,ebp
    pop ebp
    ret


; esi = buffer, edi = fshandle,
; eax = start block pinter,
; edx = blocks count
.readdirect:
    push edx
    shl eax,2
    mov ecx,[inode + ext2i_i.block]
    add ecx,eax
    .loop1:
        test edx,edx
        jz .loop1.end
        push dword 1
        mov eax,[ecx]
        push ecx
        push esi
        call ext2_readblocksraw
        add esp,12
        add esi,[edi + ext2_fsinfo.block_size]
        dec edx
        jmp .loop1
    .loop1.end:
    pop edx
    ret


; Returns file size
global ext2_getfilesize
ext2_getfilesize:
    mov eax,[esp + 2]
    push esi
    push esp
    sub esp,ext2i_i_size
    mov esi,esp
    call ext2_loadinode
    mov edx,[eax + ext2i_i.dir_acl]
    mov eax,[eax + ext2i_i.size]
    pop esp
    pop esi
    ret


; Returns file size in disk sectors (512 bytes)
ext2_getfilesectors:
    mov eax,[esp + 2]
    push esi
    sub esp,ext2i_i_size
    mov esi,esp
    call ext2_loadinode
    mov eax,[esi + ext2i_i.blocks]
    add esp,ext2i_i_size
    pop esi
    ret


ext2_readblocksraw:
    mov eax,[esp + 10]
    mov cx,[edi + ext2_fsinfo.fraclog]
    shl eax,cl
    push eax
    shl eax,9
    mov ebx,eax
    mov eax,[esp + 10]   ; we have pushed eax
    push eax
    mov eax,[esp + 10]
    push eax
    push dword [edi + ext2_fsinfo.disk]
    call read_sectors
    add esp,16
    mov eax,[esp + 2]
    ret

ext2_readblocks:
    mov eax,[esp + 6]
    push eax
    mov ebx,[esp + 6]
    push ebx
    mov cx,[edi + ext2_fsinfo.log_block_size]
    shl eax,cl
    shl eax,1
    push eax
    call malloc
    add esp,4
    push eax
    call ext2_readblocksraw
    mov eax,[esp]
    add esp,12
    ret


; Inode number in eax, buffer in esi
ext2_loadinode:
    push esi
    xor edx,edx
    dec eax
    div dword [edi + ext2_fsinfo.inodes_per_group]
    ; eax = group number, edx = entry offset
    cmp [edi + ext2_fsinfo.cached_itable_group],eax
    jne .needread
    mov eax,[edi + ext2_fsinfo.cached_itable]
    jmp .read
    .needread:
    push edx
    push eax
    push dword [edi + ext2_fsinfo.cached_itable]
    call free
    add esp,4
    pop eax
    mov [edi + ext2_fsinfo.cached_itable_group],eax
    shl eax,5   ; *= sizeof(ext2i_bg)
    mov esi,[edi + ext2_fsinfo.bgdt]
    mov esi,[esi + eax + ext2i_bg.inode_table]
    push dword 1
    push esi
    call ext2_readblocks
    add esp,8
    mov [edi + ext2_fsinfo.cached_itable],eax
    pop edx
    .read:
    pop esi
    shl edx,7   ; *=sizeof(ext2i_i)
    add edx,eax
    push dword ext2i_i_size
    push edx
    push esi
    call memcpy
    add esp,12
    ret


; Dir inode in eax
ext2_findfileindir:
    push ebp
    mov ebp,esp
    push esi
%define filename ebp + 6
%define len ebp + 10
    cmp dword [len],0
    jne .nontriv
    jmp .exit
.nontriv:
    sub esp,ext2i_i_size
%define inode ebp - ext2i_i_size
    push eax
    lea esi,[inode]
    call ext2_loadinode
    test word [esi + ext2i_i.mode],EXT2_S_IFDIR
    jz .notfound
    call ext2_getfilesectors
    add esp,4
    shl eax,7
    mov edx,eax
    push eax
    call malloc
    add esp,4
    push eax
    push esi
    mov esi,eax
    add edx,esi
    call ext2_readfile
    add esp,8
    push dword [len]
    push dword [filename]
    .loop:
        cmp esi,edx
        je .notfound
        xor ecx,ecx
        cmp dword [esi + ext2i_de.inode],0
        jz .loop.next
        mov cl,[esi + ext2i_de.name_len]
        ;test cl,cl
        ;jz .notfound
        push ecx
        lea ecx,[esi + ext2i_de.name]
        push ecx
        call strcmp
        add esp,8
        test eax,eax
        jz .gotit
        .loop.next:
        add esi,[esi + ext2i_de.rec_len]
        jmp .loop
.notfound:
    xor eax,eax
    jmp .exit
.gotit:
    mov eax,[esi + ext2i_de.inode]
.exit:
    pop esi
    mov esp,ebp
    pop ebp
    ret


strcmp:
%define s1 esp + 6
%define s1len esp + 10
%define s2 esp + 14
%define s2len esp + 18
    mov ecx,[s1len]
    mov edx,[s2len]
    cmp ecx,edx
    jne .no
    mov eax,[s1]
    mov edx,[s2]
    xor eax,eax
    .loop:
        test ecx,ecx
        jz .done
        mov bh,[eax]
        cmp bh,[edx]
        jne .no
        inc eax
        inc edx
        dec ecx
        jmp .loop
.no:
    setc al
    shl al,1
    mov ebx,1
    sub ebx,eax
    mov eax,ebx
.done:
    ret


section .data
