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

struc ext2_file_handle
    .fsinfo: resd 1
    .file: resd 1
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

    cmp dword [r1_block_buffer], 0
    jnz .skip_buffers
        push dword [edi + ext2_fsinfo.block_size]
        call malloc
        mov [r1_block_buffer], eax
        call malloc
        mov [r2_block_buffer], eax
        call malloc
        mov [r3_block_buffer], eax
        call malloc
        mov [prefix_buffer], eax
        call malloc
        mov [suffix_buffer], eax
    .skip_buffers:

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
    sub esp,12
%define handle ebp - 4
%define fnamelen ebp - 8
%define inode ebp - 12
    push dword ext2_file_handle_size
    call malloc
    mov [handle], eax
    mov edi,[fshandle]
    mov [eax + ext2_file_handle.fsinfo], edi
    mov esi,[filename]
    mov eax,[len]
    mov [fnamelen],eax
    mov dword [inode],EXT2_ROOT_INO
    xor eax,eax
    .loop1:
        cmp dword [fnamelen],0
        jle .loop1.end
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
    push eax
    mov ecx,eax
    .l:
        push ecx
        printline 'V'
        pop ecx
        dec ecx
        jz .lend
        jmp .l
    .lend:
    pop ebx
    mov eax, [handle]
    mov [eax + ext2_file_handle.file], ebx
    jmp .exit
.notfound:
    xor eax,eax
    printline 'File not found', 10
.exit:
    mov esp,ebp
    pop ebp
    ret

flag_prefix EQU 1
flag_suffix EQU 2

global ext2_readfile
ext2_readfile:
    push ebp
    push edi
    push esi
    mov ebp,esp
%define handle ebp + 12 + 2
%define buffer ebp + 12 + 6
%define offset ebp + 12 + 10
%define len ebp + 12 + 14
    mov ebx,[handle]
    mov edi,[ebx + ext2_file_handle.fsinfo]
    sub esp,ext2i_i_size + 20
%define inode ebp - ext2i_i_size - 20
%define totalblocks ebp - 4
%define prefix_size ebp - 8
%define suffix_size ebp - 12
%define blockscount ebp - 16
    lea esi,[inode]
    mov word [readfile_flags], 0
    mov eax,[ebx + ext2_file_handle.file]
    call ext2_loadinode
    mov ecx,[edi + ext2_fsinfo.log_block_size]
    add cl, 10
    mov eax, 1
    shl eax, cl
    dec eax    ; block size mask
    mov esi,[buffer]
    mov ebx,[offset]
    mov edx, ebx
    and edx, eax ; prefix_size
    mov dword [prefix_size], edx
    test edx, edx
    jz .l1
        or word [readfile_flags], flag_prefix
        pusha
        printline 'P'
        popa
    .l1:
    mov edx, ebx
    add edx, [len]
    add edx, eax
    not eax
    and edx, eax
    sub edx, [offset]
    sub edx, [len]
    mov dword [suffix_size], edx
    test edx, edx
    jz .l2
        or word [readfile_flags], flag_suffix
        pusha
        printline 'S'
        popa
    .l2:
    shr ebx,cl ; first block to read
    mov edx, [len]
    add edx, [prefix_size]
    add edx, [suffix_size]
    shr edx,cl ; total blocks to read
    mov [totalblocks],edx
    mov [blockscount], edx
.direct:
    mov edx,12
    push edx
    cmp ebx,edx
    jae .nodirect
    lea eax,[inode + ext2i_i.block]    ; array start
    push eax
    sub edx,ebx
    push edx                           ; max blocks
    ; ebx == requested start block
    call .r0
    add esp,8
    mov ebx,[esp] ; 12
.nodirect:
    pop edx
    sub ebx,edx
    mov ecx,[edi + ext2_fsinfo.log_block_size]
    add ecx,8 ; log number of pointers in one block
    mov edx,1
    shl edx,cl
    push edx
    cmp ebx,edx
    jae .noindirect
    push ebx
    push dword 1
    mov ebx,[inode + ext2i_i.block + 32*12]
    call .r1
    add esp,8
    mov ebx,[esp] ; number of pointers in indirect block
.noindirect:
    xor eax,eax
    jmp .exit




    ;////
.error:
    mov ecx,[edi + ext2_fsinfo.log_block_size]
    mov edx,[len]
    shr edx,cl
    shr edx,10 ; total blocks to read
    sub edx,[totalblocks] ; we read this many blocks
    shl edx,10
    shl edx,cl
    mov eax,edx
    jmp .exit
.allread:
    mov eax,[len]
    push eax
    mov edx,[edi + ext2_fsinfo.block_size]
    cmp dword [prefix_size], 0
    jz .l5
        cmp dword [blockscount], 1
        jne .l6
            mov ebx, edx
            sub ebx, dword [prefix_size]
            sub ebx, dword [suffix_size]
            push ebx
            mov ebx, dword [suffix_buffer]
            add ebx, dword [prefix_size]
            push ebx
            push dword [buffer]
            call memcpy
            add sp, 12            
            jmp .l7
        .l6:
            mov ebx, edx
            sub ebx, dword [prefix_size]
            push ebx
            mov ebx, dword [prefix_buffer]
            add ebx, dword [prefix_size]
            push ebx
            push dword [buffer]
            call memcpy
            add sp, 12
            jmp .l7
    .l5:
        cmp dword [suffix_size], 0
        jz .l4
            mov ebx, edx
            sub ebx, dword [suffix_size]
            push ebx
            push dword [suffix_buffer]
            mov ecx, [buffer]
            sub ecx, ebx
            push ecx
            call memcpy
            add sp, 12
        .l4:
    .l7:
.exit:
    pop eax
    mov esp,ebp
    pop esi
    pop edi
    pop ebp
    ret

; edi = fshandle
; esi = &(buffer)
; ebx = requested start block
; stack: max blocks
; stack: array start
; ! overwrites esi
.r0:
    sub sp, 12
%define max_blocks esp + 14
%define array_start esp + 18
%define buffer esp + 0
%define read_off esp + 4
%define read_len esp + 8
    mov [read_len], dword 1
    shl ebx,2
    add ebx, [array_start]
    .loop0:
        pusha
        printline '0'
        popa
        mov eax, [ebx]
        mov [read_off], eax
        mov ecx, esi
        mov eax, [prefix_buffer]
        btr word [readfile_flags], 0 ; flag_prefix
        cmovc ecx, eax
        mov edx, [suffix_buffer]
        cmp dword [totalblocks], 1
        setne al
        mov ah, al
        btr word [readfile_flags], 1 ; flag_suffix
        setnc al
        test ax, ax
        cmovz ecx, edx               ; if CF == 1 and ZF == 1
        mov [buffer], ecx
        call ext2_readblocksraw ; preserves ebx
        cmp eax,-1
        je .error
        add esi,[edi + ext2_fsinfo.block_size]
        dec dword [max_blocks]
        jz .r0.maxreached
        dec dword [totalblocks]
        jz .r0.allread
        add ebx,4
        jmp .loop0
.r0.maxreached:
    add esp,12
    ret
.r0.allread:
    add esp,12 + 2
    jmp .allread


; edi = fshandle
; esi = &(buffer)
; ebx = array start
; stack: max blocks
; stack: first block index
; ! overwrites esi
.r1:
    sub sp, 20
%define max_blocks esp + 22
%define array_start esp + 26
%define buffer esp + 0
%define read_off esp + 4
%define read_len esp + 8
%define pointer esp + 12  ; current pointer
%define child_size esp + 16
%define child_array_start read_off
%define child_max_blocks buffer
    mov [read_len],dword 1       ; param
    mov ecx,[edi + ext2_fsinfo.log_block_size]
    add ecx,8 ; log number of pointers in one block
    mov eax, ebx
    shr eax, cl
    ; eax == first pointer index
    shl eax, 2
    add eax, [array_start]
    mov [pointer], eax
    mov edx,1
    shl edx,cl
    mov [child_size], edx
    dec edx
    ; edx == child mask
    and ebx, edx
    lea eax, [r1_block_buffer]
    mov [buffer], eax            ; param
    mov eax, [pointer]
    mov [read_off], eax          ; param
    pusha
    printline '!'
    popa
    call ext2_readblocksraw
    cmp eax,-1
    je .error
    mov eax, [pointer]
    mov [child_array_start], eax ; param
    mov edx, [child_size]
    sub edx, ebx
    mov [child_max_blocks], edx  ; param
    call .r0
    dec dword [max_blocks]
    jz .r1.maxreached
    .loop1:
        lea eax, [r1_block_buffer]
        mov [buffer], eax        ; param
        mov eax, [pointer]
        mov [read_off], eax      ; param
        pusha
        printline '1'
        popa
        call ext2_readblocksraw ; preserves ebx
        cmp eax,-1
        je .error
        mov eax, [pointer]
        mov [child_array_start], eax ; param
        mov eax, [child_size]
        mov [child_max_blocks], eax  ; param
        dec dword [max_blocks]
        jz .r0.maxreached
        add dword [pointer], 4
        jmp .loop1
.r1.maxreached:
    add sp, 20
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
global ext2_getfilesectors
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


ext2_getinodesectors:
    mov eax,[esi + ext2i_i.blocks]
    ret


; Preserves ebx
ext2_readblocksraw:
    push ebx
    mov eax,[esp + 14]
    mov cx,[edi + ext2_fsinfo.fraclog]
    shl eax,cl
    push eax
    mov eax,[esp + 14]   ; we have pushed eax
    mov cx,[edi + ext2_fsinfo.log_block_size]
    shl eax,cl
    shl eax,1
    push eax
    mov eax,[esp + 14]
    push eax
    push dword [edi + ext2_fsinfo.disk]
    call read_sectors
    add esp,16
    pop ebx
    ret

ext2_readblocks:
    mov eax,[esp + 6]
    push eax
    mov ebx,[esp + 6]
    push ebx
    mov cx,[edi + ext2_fsinfo.log_block_size]
    shl eax,cl
    shl eax,10
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
    ;cmp [edi + ext2_fsinfo.cached_itable_group],eax
    ;jne .needread
    ;mov eax,[edi + ext2_fsinfo.cached_itable]
    ;jmp .read
.needread:
    ;push eax
    ;push dword [edi + ext2_fsinfo.cached_itable]
    ;call free
    ;add esp,4
    ;pop eax
    ;mov [edi + ext2_fsinfo.cached_itable_group],eax
    shl eax,5   ; *= sizeof(ext2i_bg)
    mov esi,[edi + ext2_fsinfo.bgdt]
    mov esi,[esi + eax + ext2i_bg.inode_table]
    mov eax,edx
    mov ecx,[edi + ext2_fsinfo.log_block_size]
    shr edx,cl
    shr edx,3
    add esi,edx
    shl edx,3
    shl edx,cl
    sub eax,edx
    push eax
    push dword 1
    push esi
    call ext2_readblocks
    add esp,8
    ;mov [edi + ext2_fsinfo.cached_itable],eax
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
    push esi
    push ebp
    mov ebp,esp
    sub esp,8
%define filename ebp + 10
%define len ebp + 14
%define fshandle ebp - 12
%define file ebp - 8
    cmp dword [len],0
    jne .nontriv
    jmp .exit
.nontriv:
    sub esp,ext2i_i_size + 4
%define inode ebp - ext2i_i_size - 4
%define dirend ebp - 4
    push eax
    lea esi,[inode]
    call ext2_loadinode
    test word [esi + ext2i_i.mode],EXT2_S_IFDIR
    jz .notfound
    call ext2_getinodesectors
    pop esi
    shl eax,9
    push eax
    push eax
    call malloc
    add esp,4
    pop edx
    mov ecx,edx
    add edx,eax ; end of directory
    mov [dirend],edx
    push ecx
    push dword 0
    push eax
    mov [file], esi
    mov esi,eax
    mov [fshandle], edi
    lea eax, [fshandle]
    push eax
    call ext2_readfile
    add esp,16
    push dword [len]
    push dword [filename]
    .loop:
        cmp esi,[dirend]
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
        call ext2_strcmp
        add esp,8
        test eax,eax
        jz .gotit
        .loop.next:
        xor ecx,ecx
        mov cx,[esi + ext2i_de.rec_len]
        add esi,ecx
        jmp .loop
.notfound:
    xor eax,eax
    jmp .exit
.gotit:
    mov eax,[esi + ext2i_de.inode]
.exit:
    mov esp,ebp
    pop ebp
    pop esi
    ret


ext2_strcmp:
%define s1 esp + 2
%define s1len esp + 6
%define s2 esp + 10
%define s2len esp + 14
    xor eax,eax
    mov ecx,[s1len]
    mov edx,[s2len]
    cmp ecx,edx
    jne .no
    test ecx,ecx
    jz .done
    mov ebx,[s1]
    mov edx,[s2]
    .loop:
        mov ah,[ebx]
        cmp ah,[edx]
        jne .no
        inc ebx
        inc edx
        dec ecx
        jz .done
        jmp .loop
.no:
    mov eax,1
.done:
    xor ah,ah
    ret


section .data
    r1_block_buffer: dd 0
    r2_block_buffer: dd 0
    r3_block_buffer: dd 0
    prefix_buffer: dd 0
    suffix_buffer: dd 0
    readfile_flags: dw 0
    
